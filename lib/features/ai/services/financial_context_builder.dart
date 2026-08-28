import 'package:paysense/features/ai/models/financial_context.dart';
import 'package:paysense/features/ai/services/ai_question_router.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/providers/analytics_provider.dart' show buildAnalyticsSummary;
import 'package:paysense/shared/repositories/account_aggregator_connection_repository.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_models.dart';
import 'package:paysense/shared/models/financial_safety_alert.dart';
import 'package:paysense/shared/utils/financial_safety_engine.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/bill_repository.dart';
import 'package:paysense/shared/repositories/budget_repository.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';
import 'package:paysense/shared/repositories/loan_repository.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';
import 'package:paysense/shared/repositories/user_profile_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/utils/cash_flow_calculator.dart';
import 'package:paysense/shared/utils/financial_action_engine.dart';
import 'package:paysense/shared/utils/financial_health_calculator.dart';
import 'package:paysense/shared/utils/financial_health_trends_calculator.dart';
import 'package:paysense/shared/utils/compare_periods_calculator.dart';
import 'package:paysense/shared/utils/financial_insight_engine.dart';
import 'package:paysense/shared/utils/financial_momentum_calculator.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';
import 'package:paysense/shared/utils/financial_timeline_calculator.dart';
import 'package:paysense/shared/utils/reports_calculator.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';
import 'package:paysense/shared/utils/subscription_calculator.dart';

class FinancialContextBuilder {
  FinancialContextBuilder._();

  static final FinancialContextBuilder instance = FinancialContextBuilder._();

  /// Builds the full financial snapshot sent to the AI backend.
  ///
  /// [relevantCategories] — from [classifyQuestion] — trims which of the
  /// *new* aggregated sections (Financial Planning/Safe-to-Spend/Cash Flow/
  /// Subscriptions/Reports) are populated, so a question like "can I afford
  /// this?" doesn't also carry a full Reports summary it doesn't need. Null
  /// (the default) includes everything — the safe fallback used whenever a
  /// caller doesn't have/want category-based trimming (e.g. a quick-question
  /// chip that isn't run through the router). The long-established
  /// "always present" fields (income/expense/budget/goals/loans/bills/
  /// recurring/financial health/wallet balance) are untouched by this
  /// param — they're cheap, already-aggregated, and broadly relevant to
  /// almost any question, matching PHASE 4's "if uncertain, use the
  /// broader context safely" guidance.
  Future<FinancialContext> build({Set<FinancialQuestionCategory>? relevantCategories}) async {
    final profile = await UserProfileRepository.instance.getProfile();
    final wallets = await WalletRepository.instance.getAll();
    final transactions = await TransactionRepository.instance.getAll();
    final budgets = await BudgetRepository.instance.getAll();
    final goals = await GoalRepository.instance.getAll();
    final recurringTransactions = await RecurringTransactionRepository
        .instance
        .getAll();
    final bills = await BillRepository.instance.getAll();
    final loans = await LoanRepository.instance.getAll();

    final totalWalletBalance = wallets.fold<double>(
      0.0,
      (sum, w) => sum + w.currentBalance,
    );

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final monthlyTransactions = transactions.where(
      (t) =>
          !t.createdAt.isBefore(startOfMonth) &&
          t.createdAt.year == now.year &&
          t.createdAt.month == now.month,
    );

    final monthlyIncomeTotal = monthlyTransactions
        .where((t) => t.transactionType.toLowerCase() == 'income')
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    final monthlyExpenseTotal = monthlyTransactions
        .where((t) => t.transactionType.toLowerCase() == 'expense')
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    final recent = transactions.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final recentTransactionsSummary = recent
        .take(5)
        .map(
          (t) =>
              '${t.title}: ${t.amount.toStringAsFixed(2)} on ${t.createdAt.toIso8601String().split('T').first}',
        )
        .join('; ');

    final totalBudget = budgets.fold<double>(
      0.0,
      (sum, b) => sum + b.allocatedAmount,
    );
    final totalBudgetSpent = budgets.fold<double>(
      0.0,
      (sum, b) => sum + b.spentAmount,
    );
    final totalBudgetRemaining = budgets.fold<double>(
      0.0,
      (sum, b) => sum + b.remainingAmount,
    );
    final budgetUsagePercentage = totalBudget > 0
        ? (totalBudgetSpent / totalBudget * 100)
        : 0.0;
    final highestSpendingBudgetCategory = budgets.isEmpty
        ? ''
        : budgets
              .reduce((a, b) => a.spentAmount >= b.spentAmount ? a : b)
              .categoryName;

    final totalGoals = goals.length;
    final completedGoals = goals.where((g) => g.isCompleted).length;
    final totalTargetSavings = goals.fold<double>(
      0.0,
      (sum, g) => sum + g.targetAmount,
    );
    final totalCurrentSavings = goals.fold<double>(
      0.0,
      (sum, g) => sum + g.currentAmount,
    );
    final goalCompletionPercentage = totalTargetSavings > 0
        ? (totalCurrentSavings / totalTargetSavings * 100)
        : 0.0;
    final incompleteGoals = goals.where((g) => !g.isCompleted).toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    final nearestGoal = incompleteGoals.isEmpty
        ? ''
        : incompleteGoals.first.title;

    final activeRecurring =
        recurringTransactions
            .where((r) => r.isActive && !r.isExpired)
            .toList()
          ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    double monthlyRecurringIncome = 0;
    double monthlyRecurringExpense = 0;
    for (final recurring in activeRecurring) {
      final monthlyAmount = _monthlyEquivalent(
        recurring.amount,
        recurring.frequency,
      );
      if (recurring.transactionType.toLowerCase() == 'income') {
        monthlyRecurringIncome += monthlyAmount;
      } else {
        monthlyRecurringExpense += monthlyAmount;
      }
    }

    final nextUpcoming = activeRecurring.isEmpty
        ? null
        : activeRecurring.first;
    final nextUpcomingPayment = nextUpcoming?.title ?? '';
    final nextUpcomingPaymentDate = nextUpcoming == null
        ? ''
        : '${nextUpcoming.nextDueDate.day}/${nextUpcoming.nextDueDate.month}/${nextUpcoming.nextDueDate.year}';

    final unpaidBillsList = bills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final overdueBillsCount = unpaidBillsList
        .where((b) => b.isOverdue(now))
        .length;
    final totalUnpaidBillsAmount = unpaidBillsList.fold<double>(
      0.0,
      (sum, b) => sum + b.amount,
    );
    final nextBill = unpaidBillsList.isEmpty ? null : unpaidBillsList.first;
    final nextBillTitle = nextBill?.title ?? '';
    final nextBillDueDate = nextBill == null
        ? ''
        : '${nextBill.dueDate.day}/${nextBill.dueDate.month}/${nextBill.dueDate.year}';

    final activeLoans = loans.where((l) => l.isActive).toList()
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    final totalLoanAmount = loans.fold<double>(
      0.0,
      (sum, l) => sum + l.principalAmount,
    );
    final outstandingLoanAmount = activeLoans.fold<double>(
      0.0,
      (sum, l) => sum + l.outstandingAmount,
    );
    final monthlyLoanEmi = activeLoans.fold<double>(
      0.0,
      (sum, l) => sum + l.emiAmount,
    );
    final totalInterestRemaining = activeLoans.fold<double>(
      0.0,
      (sum, l) => sum + l.estimatedInterestRemaining,
    );
    final nextLoan = activeLoans.isEmpty ? null : activeLoans.first;
    final nextLoanPayment = nextLoan == null
        ? ''
        : '${nextLoan.loanName} - ₹${nextLoan.emiAmount.toStringAsFixed(0)} due ${nextLoan.nextDueDate.day}/${nextLoan.nextDueDate.month}/${nextLoan.nextDueDate.year}';

    final financialHealth = FinancialHealthCalculator.calculate(
      transactions: transactions,
      budgets: budgets,
      goals: goals,
      loans: loans,
      bills: bills,
      wallets: wallets,
      profileMonthlyIncome: profile?.monthlyIncome ?? 0.0,
      now: now,
    );
    final topFinancialInsight = financialHealth.insights.isEmpty
        ? ''
        : financialHealth.insights.first.message;

    // ---- PHASE 1: reuse existing calculators for the new context sections
    // — never re-derive a figure a calculator already owns. ----

    // `null` (no router pass at all) and `{general}` (the router's own "not
    // confident" fallback — see classifyQuestion) both mean "include
    // everything", matching PHASE 4's "if intent detection is uncertain,
    // use the broader financial context safely" instruction.
    final includeEverything = relevantCategories == null ||
        relevantCategories.contains(FinancialQuestionCategory.general);
    bool wants(FinancialQuestionCategory category) =>
        includeEverything || relevantCategories.contains(category);

    // FINANCIAL ACTION ENGINE 1.0 — `financialActionsContext` summarizes
    // the SAME FinancialPlanningResult already computed for
    // `planningContext` below (never a second, divergent calculation), so
    // the two blocks share one `wants(...)` gate and one calculate() call.
    final wantsPlanning = wants(FinancialQuestionCategory.financialPlanning) ||
        wants(FinancialQuestionCategory.emergencyFund) ||
        wants(FinancialQuestionCategory.goals) ||
        wants(FinancialQuestionCategory.debt) ||
        wants(FinancialQuestionCategory.savings);
    final wantsFinancialActions =
        wantsPlanning || wants(FinancialQuestionCategory.budget) || wants(FinancialQuestionCategory.subscriptions);

    Map<String, dynamic> planningContext = const {};
    Map<String, dynamic> financialActionsContext = const {};
    if (wantsPlanning || wantsFinancialActions) {
      final settings = AppSettingsRepository.instance;
      final planning = FinancialPlanningCalculator.calculate(
        transactions: transactions,
        wallets: wallets,
        goals: goals,
        loans: loans,
        bills: bills,
        recurringTransactions: recurringTransactions,
        analytics: buildAnalyticsSummary(transactions, now),
        emergencyFundEligibleWalletIds: settings.emergencyFundEligibleWalletIds(),
        emergencyFundTargetMonths: settings.emergencyFundTargetMonths(),
        now: now,
      );
      if (wantsPlanning) planningContext = _planningContextMap(planning);
      if (wantsFinancialActions) {
        final subscriptions = SubscriptionCalculator.eligibleSubscriptions(
          recurringTransactions: recurringTransactions,
          now: now,
        );
        final actionPlan = FinancialActionEngine.generate(
          FinancialActionEngineInput(
            planning: planning,
            budgets: budgets,
            subscriptions: subscriptions,
            now: now,
          ),
        );
        financialActionsContext = _financialActionsContextMap(actionPlan);
      }
    }

    Map<String, dynamic> safeToSpendContext = const {};
    Map<String, dynamic> affordabilityContext = const {};
    if (wants(FinancialQuestionCategory.safeToSpend) ||
        wants(FinancialQuestionCategory.cashFlow) ||
        wants(FinancialQuestionCategory.spending)) {
      final safeToSpend = SafeToSpendCalculator.calculate(
        wallets: wallets,
        bills: bills,
        loans: loans,
        recurringTransactions: recurringTransactions,
        now: now,
      );
      safeToSpendContext = _safeToSpendContextMap(safeToSpend);
      // A general, no-specific-amount affordability anchor — reuses the
      // SAME SafeToSpendResult above rather than a second calculation. A
      // specific purchase amount produces its own richer
      // `affordabilityScenario` (see AffordabilityOrchestrator), which
      // this is deliberately NOT a duplicate of.
      affordabilityContext = {
        'currentSafeToSpend': safeToSpend.safeToSpend,
        'availableMoney': safeToSpend.availableMoney,
        'hasSufficientData': safeToSpend.hasSufficientData,
      };
    }

    Map<String, dynamic> cashFlowContext = const {};
    if (wants(FinancialQuestionCategory.cashFlow) ||
        wants(FinancialQuestionCategory.safeToSpend) ||
        wants(FinancialQuestionCategory.bills)) {
      final cashFlow = CashFlowCalculator.summarizeUpcomingWindow(
        bills: bills,
        loans: loans,
        recurringTransactions: recurringTransactions,
        now: now,
      );
      cashFlowContext = {
        'upcomingIncomeNext30Days': cashFlow.upcomingIncome,
        'upcomingExpenseNext30Days': cashFlow.upcomingExpense,
        'hasActivity': cashFlow.hasActivity,
      };
    }

    Map<String, dynamic> subscriptionsContext = const {};
    if (wants(FinancialQuestionCategory.subscriptions) ||
        wants(FinancialQuestionCategory.spending) ||
        wants(FinancialQuestionCategory.budget)) {
      final subscriptions = SubscriptionCalculator.eligibleSubscriptions(
        recurringTransactions: recurringTransactions,
        now: now,
      );
      final totals = SubscriptionCalculator.summarize(subscriptions);
      subscriptionsContext = {
        'totalMonthlyCost': totals.totalMonthlyCost,
        'totalAnnualCost': totals.totalAnnualCost,
        'activeCount': totals.activeCount,
        'mostExpensiveName': totals.mostExpensive?.name ?? '',
        'mostExpensiveMonthlyCost': totals.mostExpensive?.monthlyEquivalent ?? 0.0,
      };
    }

    Map<String, dynamic> reportsContext = const {};
    if (wants(FinancialQuestionCategory.reports) ||
        wants(FinancialQuestionCategory.spending) ||
        wants(FinancialQuestionCategory.budget)) {
      final reports = ReportsCalculator.calculate(
        transactions: transactions,
        wallets: wallets,
        period: ReportPeriod.thisMonth,
        now: now,
      );
      reportsContext = _reportsContextMap(reports);
    }

    // FINANCIAL HEALTH TRENDS 3.0
    Map<String, dynamic> financialHealthTrendsContext = const {};
    if (wants(FinancialQuestionCategory.financialHealth) ||
        wants(FinancialQuestionCategory.financialPlanning) ||
        wants(FinancialQuestionCategory.savings) ||
        wants(FinancialQuestionCategory.debt) ||
        wants(FinancialQuestionCategory.goals) ||
        wants(FinancialQuestionCategory.budget)) {
      final trendsSettings = AppSettingsRepository.instance;
      final trends = FinancialHealthTrendsCalculator.calculate(
        transactions: transactions,
        budgets: budgets,
        goals: goals,
        loans: loans,
        bills: bills,
        wallets: wallets,
        profileMonthlyIncome: profile?.monthlyIncome ?? 0.0,
        period: TrendPeriod.threeMonths,
        emergencyFundEligibleWalletIds: trendsSettings.emergencyFundEligibleWalletIds(),
        emergencyFundTargetMonths: trendsSettings.emergencyFundTargetMonths(),
        now: now,
      );
      financialHealthTrendsContext = _financialHealthTrendsContextMap(trends);
    }

    // PROACTIVE FINANCIAL INSIGHTS 1.0 (PHASE 6) — combines the SAME
    // FinancialActionEngine/FinancialHealthTrendsCalculator/
    // SafeToSpendCalculator calls used above into the unified up-to-3
    // insight list the Dashboard shows. Recomputed via a fresh call here
    // (not shared across the gate blocks above, which are independently
    // trimmed by `wants(...)`) — exactly the same pattern `subscriptionsContext`
    // already uses when its own gate differs from `wantsFinancialActions`'s.
    Map<String, dynamic> financialInsightsContext = const {};
    final wantsInsights = wantsFinancialActions ||
        wants(FinancialQuestionCategory.financialHealth) ||
        wants(FinancialQuestionCategory.spending) ||
        wants(FinancialQuestionCategory.cashFlow) ||
        wants(FinancialQuestionCategory.subscriptions);
    if (wantsInsights) {
      final insightSettings = AppSettingsRepository.instance;
      final insightPlanning = FinancialPlanningCalculator.calculate(
        transactions: transactions,
        wallets: wallets,
        goals: goals,
        loans: loans,
        bills: bills,
        recurringTransactions: recurringTransactions,
        analytics: buildAnalyticsSummary(transactions, now),
        emergencyFundEligibleWalletIds: insightSettings.emergencyFundEligibleWalletIds(),
        emergencyFundTargetMonths: insightSettings.emergencyFundTargetMonths(),
        now: now,
      );
      final insightActionPlan = FinancialActionEngine.generate(
        FinancialActionEngineInput(
          planning: insightPlanning,
          budgets: budgets,
          subscriptions: SubscriptionCalculator.eligibleSubscriptions(
            recurringTransactions: recurringTransactions,
            now: now,
          ),
          now: now,
        ),
      );
      final insightTrends = FinancialHealthTrendsCalculator.calculate(
        transactions: transactions,
        budgets: budgets,
        goals: goals,
        loans: loans,
        bills: bills,
        wallets: wallets,
        profileMonthlyIncome: profile?.monthlyIncome ?? 0.0,
        period: TrendPeriod.threeMonths,
        emergencyFundEligibleWalletIds: insightSettings.emergencyFundEligibleWalletIds(),
        emergencyFundTargetMonths: insightSettings.emergencyFundTargetMonths(),
        now: now,
      );
      final insightSafeToSpend = SafeToSpendCalculator.calculate(
        wallets: wallets,
        bills: bills,
        loans: loans,
        recurringTransactions: recurringTransactions,
        now: now,
      );
      final insightResult = FinancialInsightEngine.generate(
        actionPlan: insightActionPlan,
        trends: insightTrends,
        safeToSpend: insightSafeToSpend,
        recurringTransactions: recurringTransactions,
        now: now,
      );
      financialInsightsContext = _financialInsightsContextMap(insightResult);
    }

    // FINANCIAL INTELLIGENCE TIMELINE 1.0 (PHASE 7) — combines the SAME
    // FinancialHealthTrendsCalculator/FinancialPlanningCalculator/
    // SubscriptionCalculator calls used above into a chronological event
    // log + momentum snapshot. Recomputed via a fresh call here (same
    // independent-per-gate pattern as `financialInsightsContext`).
    Map<String, dynamic> timelineContext = const {};
    final wantsTimeline = wantsFinancialActions ||
        wants(FinancialQuestionCategory.financialHealth) ||
        wants(FinancialQuestionCategory.spending) ||
        wants(FinancialQuestionCategory.reports);
    if (wantsTimeline) {
      final timelineSettings = AppSettingsRepository.instance;
      final timelinePlanning = FinancialPlanningCalculator.calculate(
        transactions: transactions,
        wallets: wallets,
        goals: goals,
        loans: loans,
        bills: bills,
        recurringTransactions: recurringTransactions,
        analytics: buildAnalyticsSummary(transactions, now),
        emergencyFundEligibleWalletIds: timelineSettings.emergencyFundEligibleWalletIds(),
        emergencyFundTargetMonths: timelineSettings.emergencyFundTargetMonths(),
        now: now,
      );
      final timelineTrends = FinancialHealthTrendsCalculator.calculate(
        transactions: transactions,
        budgets: budgets,
        goals: goals,
        loans: loans,
        bills: bills,
        wallets: wallets,
        profileMonthlyIncome: profile?.monthlyIncome ?? 0.0,
        period: TrendPeriod.threeMonths,
        emergencyFundEligibleWalletIds: timelineSettings.emergencyFundEligibleWalletIds(),
        emergencyFundTargetMonths: timelineSettings.emergencyFundTargetMonths(),
        now: now,
      );
      final timeline = FinancialTimelineCalculator.calculate(
        trends: timelineTrends,
        planning: timelinePlanning,
        budgets: budgets,
        goals: goals,
        loans: loans,
        transactions: transactions,
        recurringTransactions: recurringTransactions,
        subscriptions: SubscriptionCalculator.eligibleSubscriptions(
          recurringTransactions: recurringTransactions,
          now: now,
        ),
        period: TimelinePeriod.threeMonths,
        now: now,
      );
      final momentum = FinancialMomentumCalculator.calculate(timelineTrends);
      timelineContext = _timelineContextMap(timeline, momentum);
    }

    // COMPARE PERIODS 1.0 (PHASE 7) — reuses the SAME ComparePeriodsCalculator
    // the Compare Periods screen itself uses, defaulted to "this month vs
    // last month" (the natural default for "did I spend more this month?"/
    // "what changed compared with last month?"). The AI explains this
    // already-computed comparison; it never recalculates one of its own.
    Map<String, dynamic> comparePeriodsContext = const {};
    final wantsComparePeriods = wants(FinancialQuestionCategory.reports) ||
        wants(FinancialQuestionCategory.spending) ||
        wants(FinancialQuestionCategory.budget) ||
        wants(FinancialQuestionCategory.financialHealth) ||
        wants(FinancialQuestionCategory.savings);
    if (wantsComparePeriods) {
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final currentMonthEnd = DateTime(now.year, now.month + 1, 1);
      final previousMonthStart = DateTime(now.year, now.month - 1, 1);
      final comparison = ComparePeriodsCalculator.calculate(
        transactions: transactions,
        wallets: wallets,
        budgets: budgets,
        currentPeriod: ComparePeriod(
          label: 'This month',
          start: currentMonthStart,
          end: currentMonthEnd,
        ),
        comparisonPeriod: ComparePeriod(
          label: 'Last month',
          start: previousMonthStart,
          end: currentMonthStart,
        ),
      );
      comparePeriodsContext = _comparePeriodsContextMap(comparison);
    }

    // ACCOUNT AGGREGATOR — PART G. Aggregated, privacy-safe connection
    // metadata only — never a raw AA transaction/account number/
    // credential (see FinancialContext.accountAggregatorContext's own
    // doc comment).
    //
    // Deliberately only reads this when the connections box is ALREADY
    // open (i.e. some AA-related screen has been visited this session) —
    // never triggers opening it fresh from here. Opening a Hive box for
    // the first time is a real disk I/O operation, unlike every other
    // repository read above (which all hit boxes `build()`'s caller has
    // already opened at app bootstrap and are therefore effectively
    // instant); doing that unconditionally on every context build once
    // measurably shifted this method's timing enough to break an
    // unrelated in-flight-request-deduplication test that synchronizes
    // on a `Future.delayed(Duration.zero)` microtask boundary. A fresh
    // app session with no AA connection yet correctly has nothing to
    // report anyway; once any AA screen opens the box, it stays open for
    // the rest of the session and this reflects real data from then on.
    final accountAggregatorContext = Hive.isBoxOpen(AccountAggregatorConnectionRepository.boxName)
        ? _accountAggregatorContextMap(await AccountAggregatorConnectionRepository.instance.getAll())
        : _accountAggregatorContextMap(const []);

    // FINANCIAL SAFETY ENGINE — PART K. Reuses the SAME
    // wallets/transactions/bills/loans/recurringTransactions already
    // fetched above (no extra repository/box access) — safe with
    // respect to the timing lesson learned from accountAggregatorContext
    // above, since nothing new is opened here.
    final safetyAlerts = FinancialSafetyEngine.generate(
      transactions: transactions,
      wallets: wallets,
      bills: bills,
      loans: loans,
      recurringTransactions: recurringTransactions,
      now: now,
    );
    final financialSafetyContext = _financialSafetyContextMap(safetyAlerts);

    return FinancialContext(
      fullName: profile?.fullName ?? '',
      monthlyIncome: profile?.monthlyIncome ?? 0.0,
      monthlyEmi: profile?.monthlyEmi ?? 0.0,
      savingsGoal: profile?.savingsGoal ?? 0.0,
      totalWalletBalance: totalWalletBalance,
      monthlyIncomeTotal: monthlyIncomeTotal,
      monthlyExpenseTotal: monthlyExpenseTotal,
      totalBudget: totalBudget,
      totalBudgetSpent: totalBudgetSpent,
      totalBudgetRemaining: totalBudgetRemaining,
      budgetUsagePercentage: budgetUsagePercentage,
      highestSpendingBudgetCategory: highestSpendingBudgetCategory,
      recentTransactionsSummary: recentTransactionsSummary,
      totalGoals: totalGoals,
      completedGoals: completedGoals,
      totalTargetSavings: totalTargetSavings,
      totalCurrentSavings: totalCurrentSavings,
      nearestGoal: nearestGoal,
      goalCompletionPercentage: goalCompletionPercentage,
      totalRecurringTransactions: recurringTransactions.length,
      activeRecurringTransactions: activeRecurring.length,
      monthlyRecurringIncome: monthlyRecurringIncome,
      monthlyRecurringExpense: monthlyRecurringExpense,
      nextUpcomingPayment: nextUpcomingPayment,
      nextUpcomingPaymentDate: nextUpcomingPaymentDate,
      totalBills: bills.length,
      unpaidBills: unpaidBillsList.length,
      overdueBills: overdueBillsCount,
      totalUnpaidBillsAmount: totalUnpaidBillsAmount,
      nextBillTitle: nextBillTitle,
      nextBillDueDate: nextBillDueDate,
      totalLoanAmount: totalLoanAmount,
      outstandingLoanAmount: outstandingLoanAmount,
      monthlyLoanEmi: monthlyLoanEmi,
      totalInterestRemaining: totalInterestRemaining,
      activeLoanCount: activeLoans.length,
      nextLoanPayment: nextLoanPayment,
      financialHealthScore: financialHealth.overallScore,
      financialHealthStatus: financialHealthStatusLabel(financialHealth.status),
      savingsHealthScore: financialHealth.components.savings,
      budgetHealthScore: financialHealth.components.budget,
      goalHealthScore: financialHealth.components.goals,
      debtHealthScore: financialHealth.components.debt,
      paymentHealthScore: financialHealth.components.payments,
      topFinancialInsight: topFinancialInsight,
      planningContext: planningContext,
      safeToSpendContext: safeToSpendContext,
      cashFlowContext: cashFlowContext,
      subscriptionsContext: subscriptionsContext,
      reportsContext: reportsContext,
      financialActionsContext: financialActionsContext,
      financialHealthTrendsContext: financialHealthTrendsContext,
      affordabilityContext: affordabilityContext,
      financialInsightsContext: financialInsightsContext,
      timelineContext: timelineContext,
      comparePeriodsContext: comparePeriodsContext,
      accountAggregatorContext: accountAggregatorContext,
      financialSafetyContext: financialSafetyContext,
    );
  }

  /// ACCOUNT AGGREGATOR — PART G. Answers "did my bank sync succeed",
  /// "what accounts are connected", "when was my last sync" — nothing
  /// else. No account numbers, no transaction content, no credentials.
  Map<String, dynamic> _accountAggregatorContextMap(List<AccountAggregatorConnection> connections) {
    final active = connections.where((c) => c.status != ConnectionStatus.revoked).toList();
    if (active.isEmpty) {
      return {'isConnected': false, 'connectedAccountCount': 0};
    }

    final lastSyncedAt = active
        .map((c) => c.lastSyncedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, d) => latest == null || d.isAfter(latest) ? d : latest);

    return {
      'isConnected': true,
      'connectionCount': active.length,
      'connectedAccountCount': active.fold<int>(0, (sum, c) => sum + c.accounts.length),
      'accountDisplayNames': active.expand((c) => c.accounts.map((a) => a.displayName)).toList(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'anySyncFailed': active.any((c) => c.status == ConnectionStatus.failed),
      'anyPartiallyConnected': active.any((c) => c.status == ConnectionStatus.partiallyConnected),
      'isMockData': active.any((c) => c.isMock),
    };
  }

  /// FINANCIAL SAFETY ENGINE — PART K. Title/explanation/severity only —
  /// never the raw transaction/wallet/bill/loan data the engine used to
  /// compute each alert.
  Map<String, dynamic> _financialSafetyContextMap(List<FinancialSafetyAlert> alerts) {
    if (alerts.isEmpty) {
      return {'hasActiveAlerts': false, 'alertCount': 0};
    }
    return {
      'hasActiveAlerts': true,
      'alertCount': alerts.length,
      'alerts': alerts
          .map((a) => {
                'type': a.type.name,
                'severity': a.severity.name,
                'title': a.title,
                'explanation': a.explanation,
              })
          .toList(),
    };
  }

  /// Only the top action(s) FinancialActionEngine surfaced — priority,
  /// category, title, explanation, recommendation, and the supporting
  /// figure, never a raw wallet/transaction row.
  Map<String, dynamic> _financialActionsContextMap(FinancialActionPlan plan) {
    return {
      'actions': plan.actions
          .map(
            (a) => {
              'priority': a.priority.name,
              'category': a.category.name,
              'title': a.title,
              'explanation': a.explanation,
              'recommendedAction': a.recommendedAction,
              if (a.supportingAmount != null) 'supportingAmount': a.supportingAmount,
              if (a.supportingPercentage != null) 'supportingPercentage': a.supportingPercentage,
            },
          )
          .toList(),
    };
  }

  /// Only type/priority/title/explanation/recommendation/entity name and
  /// supporting figures — never a raw wallet/transaction/SMS row. The AI
  /// may explain these deterministic insights but must never recompute or
  /// contradict the figures here (see SYSTEM_INSTRUCTION in ai_backend).
  Map<String, dynamic> _financialInsightsContextMap(FinancialInsightResult result) {
    return {
      'insights': result.insights
          .map(
            (i) => {
              'type': i.type.name,
              'priority': i.priority.name,
              'title': i.title,
              'explanation': i.explanation,
              'recommendedAction': i.recommendedAction,
              if (i.amount != null) 'amount': i.amount,
              if (i.percentage != null) 'percentage': i.percentage,
              if (i.relatedEntityName != null) 'relatedEntityName': i.relatedEntityName,
            },
          )
          .toList(),
    };
  }

  /// Only event type/tone/date/title/explanation/figures and the momentum
  /// status/signals — never a raw transaction row, SMS body, or account
  /// identifier. Capped to the 10 most recent events so a long history
  /// never balloons the AI payload; the deterministic ordering (newest
  /// first) is preserved from [FinancialTimelineResult.events].
  Map<String, dynamic> _timelineContextMap(FinancialTimelineResult timeline, FinancialMomentum momentum) {
    return {
      'hasSufficientData': timeline.hasSufficientData,
      'momentum': {
        'status': momentum.status.name,
        'signals': momentum.signals
            .map((s) => {'label': s.label, 'direction': s.direction.name, 'detail': s.detail})
            .toList(),
      },
      'events': timeline.events
          .take(10)
          .map(
            (e) => {
              'type': e.type.name,
              'tone': e.tone.name,
              'date': e.date.toIso8601String(),
              'title': e.title,
              'explanation': e.explanation,
              if (e.amount != null) 'amount': e.amount,
              if (e.percentage != null) 'percentage': e.percentage,
              if (e.relatedEntityName != null) 'relatedEntityName': e.relatedEntityName,
            },
          )
          .toList(),
    };
  }

  /// Only aggregated period labels/totals/percentages/directions/category
  /// names — never a raw transaction row, SMS body, or account identifier.
  /// The AI may explain this deterministic comparison but must never
  /// recompute or contradict its figures (see SYSTEM_INSTRUCTION in
  /// ai_backend).
  Map<String, dynamic> _comparePeriodsContextMap(ComparePeriodsResult result) {
    Map<String, dynamic> metricMap(ComparePeriodMetric metric) => {
          'current': metric.currentValue,
          'comparison': metric.comparisonValue,
          if (metric.percentageDifference != null) 'percentageDifference': metric.percentageDifference,
          'direction': metric.direction.name,
        };

    return {
      'currentPeriodLabel': result.currentPeriod.label,
      'comparisonPeriodLabel': result.comparisonPeriod.label,
      'hasSufficientData': result.hasSufficientData,
      'income': metricMap(result.income),
      'expense': metricMap(result.expense),
      'savings': metricMap(result.savings),
      'savingsRate': {
        if (result.savingsRate.currentRate != null) 'current': result.savingsRate.currentRate,
        if (result.savingsRate.comparisonRate != null) 'comparison': result.savingsRate.comparisonRate,
        if (result.savingsRate.pointsDifference != null) 'pointsDifference': result.savingsRate.pointsDifference,
        'direction': result.savingsRate.direction.name,
      },
      'categoryChanges': result.categoryChanges
          .map(
            (c) => {
              'categoryId': c.categoryId,
              'current': c.change.current,
              'comparison': c.change.previous,
              'direction': c.direction.name,
            },
          )
          .toList(),
      'verdict': result.verdict,
    };
  }

  /// Only aggregated scores/percentages/totals/period labels/insight
  /// text — never a raw transaction row or category ID beyond the plain
  /// name already surfaced elsewhere in this context.
  Map<String, dynamic> _financialHealthTrendsContextMap(FinancialHealthTrendResult trends) {
    return {
      'period': trends.period.label,
      'trajectory': trends.trajectory.name,
      'scoreTrend': {
        'current': trends.scoreTrend.currentScore,
        'previous': trends.scoreTrend.previousScore,
        'change': trends.scoreTrend.change,
        'direction': trends.scoreTrend.direction.name,
      },
      'savingsTrend': {
        'current': trends.savingsTrend.currentSavingsRate,
        'previous': trends.savingsTrend.previousSavingsRate,
        'average': trends.savingsTrend.averageSavingsRate,
        'direction': trends.savingsTrend.direction.name,
      },
      'incomeTrend': {
        'current': trends.incomeTrend.currentIncome,
        'previous': trends.incomeTrend.previousIncome,
        'pattern': trends.incomeTrend.pattern.name,
        'direction': trends.incomeTrend.direction.name,
      },
      'expenseTrend': {
        'current': trends.expenseTrend.currentExpense,
        'previous': trends.expenseTrend.previousExpense,
        'direction': trends.expenseTrend.direction.name,
      },
      'budgetTrend': {
        'monthsWithinBudget': trends.budgetTrend.monthsWithinBudget,
        'monthsNearLimit': trends.budgetTrend.monthsNearLimit,
        'monthsOverBudget': trends.budgetTrend.monthsOverBudget,
        'direction': trends.budgetTrend.direction.name,
      },
      'debtTrend': {
        'currentOutstanding': trends.debtTrend.currentOutstanding,
        'totalPaidDown': trends.debtTrend.totalPaidDown,
        'direction': trends.debtTrend.direction.name,
      },
      'emergencyFundTrend': {
        'isConfigured': trends.emergencyFundTrend.isConfigured,
        'progressPercent': trends.emergencyFundTrend.progressPercent,
      },
      'goalTrend': {
        'total': trends.goalTrend.totalGoals,
        'onTrack': trends.goalTrend.goalsOnTrack,
        'atRisk': trends.goalTrend.goalsAtRisk,
        'completed': trends.goalTrend.goalsCompleted,
      },
      'keyInsights': trends.keyInsights.map((i) => i.explanation).toList(),
    };
  }

  /// Only aggregated figures — no wallet ids, no transaction rows.
  Map<String, dynamic> _planningContextMap(FinancialPlanningResult planning) {
    return {
      'readinessScore': planning.readinessScore,
      'readinessStatus': planningReadinessStatusLabel(planning.status),
      'netWorth': planning.overview.netWorth,
      'monthlySavings': planning.overview.monthlySavings,
      'savingsRatePercent': planning.overview.savingsRatePercent,
      'emergencyFundTarget': planning.emergencyFund.target,
      'emergencyFundCurrent': planning.emergencyFund.current,
      'emergencyFundRemaining': planning.emergencyFund.remaining,
      'emergencyFundTargetMonths': planning.emergencyFund.targetMonths,
      'emergencyFundEstimatedMonths': planning.emergencyFund.estimatedMonths,
      'emergencyFundIsConfigured': planning.emergencyFund.isSourceConfigured,
      'monthlyFixedCommitments': planning.commitments.total,
      'commitmentsPercentageOfIncome': planning.commitments.percentageOfIncome,
      'totalDebt': planning.debt.totalOutstanding,
      'monthlyEmiBurden': planning.debt.monthlyEmiBurden,
      'emiToIncomePercent': planning.debt.emiToIncomePercent,
      'goalsOnTrackOrCompleted': planning.goalProjections
          .where((g) =>
              g.status == GoalProjectionStatus.onTrack || g.status == GoalProjectionStatus.completed)
          .length,
      'goalsAtRisk':
          planning.goalProjections.where((g) => g.status == GoalProjectionStatus.atRisk).length,
      'topRecommendation': planning.recommendations.isEmpty ? '' : planning.recommendations.first,
      'hasSufficientData': planning.hasSufficientData,
    };
  }

  Map<String, dynamic> _safeToSpendContextMap(SafeToSpendResult safeToSpend) {
    return {
      'availableMoney': safeToSpend.availableMoney,
      'upcomingCommitments': safeToSpend.upcomingCommitments,
      'safeToSpend': safeToSpend.safeToSpend,
      'dailySafeToSpend': safeToSpend.dailySafeToSpend,
      'shortfall': safeToSpend.shortfall,
      'windowDays': safeToSpend.windowDays,
      'hasSufficientData': safeToSpend.hasSufficientData,
    };
  }

  /// Top 3 categories (name/amount/percentage) and the calculator's own
  /// plain-language insight strings — never the underlying transaction
  /// list.
  Map<String, dynamic> _reportsContextMap(ReportsResult reports) {
    final topCategories = reports.categoryBreakdown
        .take(3)
        .map(
          (c) => {
            'category': c.categoryId,
            'amount': c.amount,
            'percentage': c.percentage,
          },
        )
        .toList();

    return {
      'periodLabel': reports.period.label,
      'totalIncome': reports.totalIncome,
      'totalExpense': reports.totalExpense,
      'savingsRatePercent': reports.savingsRate,
      'topCategories': topCategories,
      'incomeChangePercent': reports.comparison.incomeChange.percentage,
      'expenseChangePercent': reports.comparison.expenseChange.percentage,
      'insights': reports.insights,
    };
  }

  double _monthlyEquivalent(double amount, String frequency) {
    switch (frequency) {
      case 'Daily':
        return amount * 30;
      case 'Weekly':
        return amount * (30 / 7);
      case 'Yearly':
        return amount / 12;
      case 'Monthly':
      default:
        return amount;
    }
  }
}
