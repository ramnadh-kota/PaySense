import '../models/bill.dart';
import '../models/budget.dart';
import '../models/financial_report.dart';
import '../models/financial_safety_alert.dart';
import '../models/goal.dart';
import '../models/loan.dart';
import '../models/pain_of_paying_result.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import 'budget_calculator.dart';
import 'financial_health_calculator.dart';
import 'financial_planning_calculator.dart';
import 'financial_safety_engine.dart';
import 'pain_of_paying_engine.dart';
import 'recurring_money_aggregator.dart';
import 'safe_to_spend_calculator.dart';
import '../providers/analytics_provider.dart' show buildAnalyticsSummary;

/// FINANCIAL REPORT ENGINE. A deterministic ADAPTER over already-existing
/// calculators — see [FinancialReport]'s doc for exactly which one backs
/// each field. This engine performs exactly TWO genuinely new
/// computations (nothing else does these): the report's own date-range
/// resolution (weekly = last 7 days, monthly = the calendar month), and
/// simple sums (income/expense/category totals, top transactions) over
/// transactions within that range — both trivial aggregations, not a
/// second version of any existing calculator's formula.
///
/// DATA INTEGRITY RULE: no field is ever fabricated. Every value not
/// backed by real stored data is left null/empty (see each field's doc
/// on [FinancialReport]) rather than estimated.
class FinancialReportEngine {
  FinancialReportEngine._();

  /// How many of the largest transactions the report keeps.
  static const int largestTransactionsLimit = 5;

  /// A large/notable transaction is worth calling out in
  /// [FinancialReport.notableSpendingBehaviors] once its Pain-of-Paying
  /// level reaches at least this — LOW-level results are routine and
  /// would just be noise in a report.
  static const PainOfPayingLevel notableBehaviorMinimumLevel = PainOfPayingLevel.moderate;

  static FinancialReport generate({
    required FinancialReportPeriod period,
    required List<Transaction> transactions,
    required List<Wallet> wallets,
    required List<Budget> budgets,
    required List<Goal> goals,
    required List<Loan> loans,
    required List<Bill> bills,
    required List<RecurringTransaction> recurringTransactions,
    required DateTime now,
    double profileMonthlyIncome = 0,
  }) {
    final (periodStart, periodEnd) = _resolveWindow(period, now);

    final windowTransactions = transactions.where(
      (t) => !t.createdAt.isBefore(periodStart) && t.createdAt.isBefore(periodEnd),
    ).toList();

    final totalIncome = windowTransactions
        .where((t) => t.transactionType.toLowerCase() == 'income')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final expenseTransactions = windowTransactions.where((t) => t.transactionType.toLowerCase() == 'expense').toList();
    final totalExpenses = expenseTransactions.fold<double>(0, (sum, t) => sum + t.amount);
    final netCashFlow = totalIncome - totalExpenses;
    final savingsRatePercent = totalIncome > 0 ? (netCashFlow / totalIncome * 100) : null;

    final spendingByCategory = _categorySpend(expenseTransactions, totalExpenses);

    final largestTransactions = expenseTransactions.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final topTransactions = largestTransactions.take(largestTransactionsLimit).toList();

    // ---- Reused calculators — nothing below re-derives a formula that already exists. ----

    final recurringSummary = RecurringMoneyAggregator.summarize(
      recurringTransactions: recurringTransactions,
      bills: bills,
      loans: loans,
      now: now,
    );

    final upcomingBills = bills
        .where((b) => !b.isPaid && !b.dueDate.isAfter(periodEnd))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final upcomingPayments = recurringTransactions
        .where((r) => r.isActive && !r.nextDueDate.isAfter(periodEnd))
        .toList()
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    final goalProjections = FinancialPlanningCalculator.calculateGoalProjections(goals: goals, now: now);

    final safetySignals = FinancialSafetyEngine.generate(
      transactions: transactions,
      wallets: wallets,
      bills: bills,
      loans: loans,
      recurringTransactions: recurringTransactions,
      now: now,
    );

    // Budgets are monthly-only records (Budget.month/year) — a weekly
    // report has no real weekly budget figure to show, so this section
    // is deliberately left null rather than showing a misleading
    // fraction of a monthly allocation.
    BudgetMonthlySummary? budgetSummary;
    BudgetOverspendSummary? budgetOverspend;
    if (period == FinancialReportPeriod.monthly) {
      final monthBudgets = budgets.where((b) => b.year == now.year && b.month == _monthName(now.month)).toList();
      if (monthBudgets.isNotEmpty) {
        budgetSummary = BudgetCalculator.summarize(monthBudgets);
        budgetOverspend = BudgetCalculator.overspendSummary(monthBudgets);
      }
    }

    final analytics = buildAnalyticsSummary(transactions, now);
    final planning = FinancialPlanningCalculator.calculate(
      transactions: transactions,
      wallets: wallets,
      goals: goals,
      loans: loans,
      bills: bills,
      recurringTransactions: recurringTransactions,
      analytics: analytics,
      now: now,
    );

    final healthResult = period == FinancialReportPeriod.monthly
        ? FinancialHealthCalculator.calculate(
            transactions: transactions,
            budgets: budgets,
            goals: goals,
            loans: loans,
            bills: bills,
            wallets: wallets,
            profileMonthlyIncome: profileMonthlyIncome,
            now: now,
          )
        : null;

    final safeToSpend = wallets.isNotEmpty
        ? SafeToSpendCalculator.calculate(wallets: wallets, bills: bills, loans: loans, recurringTransactions: recurringTransactions, now: now)
        : null;

    final notableSpendingBehaviors = <PainOfPayingResult>[];
    for (final t in topTransactions) {
      final result = PainOfPayingEngine.evaluate(
        amount: t.amount,
        categoryId: t.categoryId,
        transactions: transactions,
        budgets: budgets,
        goals: goals,
        now: t.createdAt,
        monthlyEmiBurden: planning.debt.monthlyEmiBurden,
        safeToSpend: safeToSpend,
        excludeTransactionId: t.id,
      );
      if (result.level.index >= notableBehaviorMinimumLevel.index) {
        notableSpendingBehaviors.add(result);
      }
    }

    final hasAnyActivity = windowTransactions.isNotEmpty ||
        upcomingBills.isNotEmpty ||
        upcomingPayments.isNotEmpty ||
        safetySignals.isNotEmpty;

    return FinancialReport(
      period: period,
      periodStart: periodStart,
      periodEnd: periodEnd,
      generatedAt: now,
      hasAnyActivity: hasAnyActivity,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netCashFlow: netCashFlow,
      savingsRatePercent: savingsRatePercent,
      spendingByCategory: spendingByCategory,
      largestTransactions: topTransactions,
      recurringSummary: recurringSummary,
      upcomingBills: upcomingBills,
      upcomingPayments: upcomingPayments,
      goalProjections: goalProjections,
      safetySignals: safetySignals,
      budgetSummary: budgetSummary,
      budgetOverspend: budgetOverspend,
      debt: planning.debt,
      healthResult: healthResult,
      safeToSpend: safeToSpend,
      notableSpendingBehaviors: notableSpendingBehaviors,
      recommendations: _buildRecommendations(
        netCashFlow: netCashFlow,
        savingsRatePercent: savingsRatePercent,
        budgetOverspend: budgetOverspend,
        debt: planning.debt,
        safetySignals: safetySignals,
        safeToSpend: safeToSpend,
      ),
    );
  }

  static (DateTime, DateTime) _resolveWindow(FinancialReportPeriod period, DateTime now) {
    switch (period) {
      case FinancialReportPeriod.weekly:
        return (now.subtract(const Duration(days: 7)), now);
      case FinancialReportPeriod.monthly:
        return (DateTime(now.year, now.month, 1), now);
    }
  }

  static List<ReportCategorySpend> _categorySpend(List<Transaction> expenses, double totalExpenses) {
    final totals = <String, double>{};
    for (final t in expenses) {
      totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amount;
    }
    final entries = totals.entries.map(
      (e) => ReportCategorySpend(
        categoryId: e.key,
        amount: e.value,
        percentOfExpenses: totalExpenses > 0 ? (e.value / totalExpenses * 100) : 0,
      ),
    ).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return entries;
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static String _monthName(int month) => _monthNames[month - 1];

  /// Neutral, non-shaming, real-data-backed suggestions — the same
  /// language style already established by `FinancialSafetyEngine`'s
  /// `recommendedAction` and `PainOfPayingEngine`'s `suggestedAction`.
  /// Capped at 3 so a report never turns into a wall of tips.
  static List<String> _buildRecommendations({
    required double netCashFlow,
    required double? savingsRatePercent,
    required BudgetOverspendSummary? budgetOverspend,
    required DebtOverview debt,
    required List<FinancialSafetyAlert> safetySignals,
    required SafeToSpendResult? safeToSpend,
  }) {
    final recommendations = <String>[];

    if (safeToSpend != null && safeToSpend.shortfall > 0) {
      recommendations.add(
        'Your upcoming bills and EMIs exceed your available balance by ₹${safeToSpend.shortfall.toStringAsFixed(0)} — '
        'consider delaying non-essential spending until your next income.',
      );
    }
    if (budgetOverspend != null && budgetOverspend.hasOverspend) {
      recommendations.add(
        'You\'re ₹${budgetOverspend.totalOverspend.toStringAsFixed(0)} over budget across '
        '${budgetOverspend.categoryCount} categor${budgetOverspend.categoryCount == 1 ? 'y' : 'ies'} this month.',
      );
    }
    if (netCashFlow < 0) {
      recommendations.add('Spending exceeded income in this period — worth reviewing before it becomes a pattern.');
    } else if (savingsRatePercent != null && savingsRatePercent > 0) {
      recommendations.add('You saved ${savingsRatePercent.toStringAsFixed(0)}% of your income this period.');
    }
    if (debt.hasDebt && debt.emiToIncomePercent != null && debt.emiToIncomePercent! >= 40) {
      recommendations.add(
        'Your EMI commitments are ${debt.emiToIncomePercent!.toStringAsFixed(0)}% of your income — '
        'consider whether taking on further debt is advisable right now.',
      );
    }
    final highSeverity = safetySignals.where((a) => a.severity == FinancialSafetyAlertSeverity.high);
    if (highSeverity.isNotEmpty) {
      recommendations.add(highSeverity.first.recommendedAction);
    }

    return recommendations.take(3).toList();
  }
}
