import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/financial_safety_alert.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/models/pain_of_paying_result.dart';
import 'package:paysense/shared/providers/account_aggregator_connections_provider.dart';
import 'package:paysense/shared/providers/analytics_provider.dart' show AnalyticsSummary, analyticsSummaryProvider;
import 'package:paysense/shared/providers/financial_safety_provider.dart';
import 'package:paysense/shared/providers/safe_to_spend_provider.dart';
import 'package:paysense/shared/services/analytics_service.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_models.dart';
import 'package:paysense/shared/utils/pain_of_paying_engine.dart';
import 'package:paysense/shared/providers/bill_provider.dart';
import 'package:paysense/shared/providers/budget_provider.dart';
import 'package:paysense/shared/providers/financial_action_provider.dart';
import 'package:paysense/shared/utils/financial_action_engine.dart';
import 'package:paysense/shared/providers/financial_health_provider.dart';
import 'package:paysense/shared/providers/financial_health_trends_provider.dart';
import 'package:paysense/shared/utils/financial_health_trends_calculator.dart' show OverallTrajectory;
import 'package:paysense/shared/providers/financial_insight_provider.dart';
import 'package:paysense/shared/utils/financial_insight_engine.dart';
import 'package:paysense/shared/providers/financial_planning_provider.dart';
import 'package:paysense/shared/providers/goal_provider.dart';
import 'package:paysense/shared/providers/loan_provider.dart';
import 'package:paysense/shared/providers/notification_provider.dart';
import 'package:paysense/shared/providers/settings_provider.dart';
import 'package:paysense/shared/providers/recurring_transaction_provider.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/dashboard_helpers.dart';
import 'package:paysense/shared/utils/financial_health_calculator.dart'
    show FinancialHealthResult, FinancialInsightType;
import 'package:paysense/shared/widgets/app_card.dart';
import '../../core/routes/app_routes.dart';
import '../transactions/presentation/add_expense_screen.dart';
import '../transactions/presentation/add_income_screen.dart';
import '../wallet/presentation/add_edit_wallet_screen.dart';
import 'widgets/daily_check_in_card.dart';
import 'widgets/your_money_explained_card.dart';
import 'widgets/spending_pattern_card.dart';
import 'widgets/cash_flow_card.dart';
import 'widgets/financial_health_card.dart';
import 'widgets/fun_funds_card.dart';
import 'widgets/quick_action_button.dart';
import 'widgets/safe_to_spend_card.dart';
import 'widgets/subscriptions_card.dart';
import 'widgets/summary_card.dart';
import 'widgets/transaction_item.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEE, d MMM yyyy').format(now);
    final transactionsAsync = ref.watch(transactionsProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final budgetTotals = ref.watch(budgetTotalsProvider);
    final goalsAsync = ref.watch(goalsProvider);
    final upcomingPayments = ref.watch(upcomingPaymentsProvider);
    final upcomingBills = ref.watch(upcomingBillsProvider);
    final loanSummary = ref.watch(loanSummaryProvider);
    ref.listen<FinancialHealthResult>(financialHealthProvider, (
      previous,
      next,
    ) {
      _maybeRecordFinancialHealthNotification(ref, next);
    });
    ref.listen<FinancialInsightResult>(financialInsightsProvider, (
      previous,
      next,
    ) {
      _maybeRecordInsightNotification(ref, next);
    });
    final profileAsync = ref.watch(userProfileProvider);
    final greeting = greetingFor(now, profileAsync.value?.fullName ?? '');
    final currencyCode = profileAsync.value?.currency.isNotEmpty == true
        ? profileAsync.value!.currency
        : 'INR';
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: CurrencyFormatter.symbolFor(currencyCode),
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: transactionsAsync.when(
          data: (transactions) {
            final totals = _totalsFromAnalytics(ref.watch(analyticsSummaryProvider));
            // BUG FIX: Total Assets/Total Liabilities/Net Worth previously
            // showed hardcoded strings that never reflected real data. This
            // reuses FinancialOverview — the SAME already-computed net-worth
            // source of truth FinancialPlanningCalculator produces (Assets =
            // sum of non-archived wallet balances, Liabilities = sum of
            // active loans' outstanding balances) — rather than a second,
            // duplicate calculation. financialPlanningProvider already
            // watches walletsProvider/loansProvider, so this rebuilds
            // automatically on any wallet/loan mutation, no extra
            // invalidation wiring needed.
            final planning = ref.watch(financialPlanningProvider);
            final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
            return _buildDashboardContent(
              context: context,
              greeting: greeting,
              formattedDate: formattedDate,
              currencyFormatter: currencyFormatter,
              currencyCode: currencyCode,
              totals: totals,
              transactions: transactions,
              wallets: wallets,
              hasBudgets: (budgetsAsync.value ?? const []).isNotEmpty,
              budgetTotals: budgetTotals,
              goals: goalsAsync.value ?? const [],
              upcomingPayments: upcomingPayments,
              upcomingBills: upcomingBills,
              loanSummary: loanSummary,
              planningReadinessScore: planning.readinessScore,
              netWorth: planning.overview.netWorth,
              totalAssets: planning.overview.totalAssets,
              totalLiabilities: planning.overview.totalDebt,
              now: now,
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load transactions right now.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboardContent({
    required BuildContext context,
    required String greeting,
    required String formattedDate,
    required NumberFormat currencyFormatter,
    required String currencyCode,
    required _DashboardTotals totals,
    required bool hasBudgets,
    required BudgetTotals budgetTotals,
    required List<Goal> goals,
    required List<RecurringTransaction> upcomingPayments,
    required List<Bill> upcomingBills,
    required LoanSummary loanSummary,
    required int planningReadinessScore,
    required double netWorth,
    required double totalAssets,
    required double totalLiabilities,
    required DateTime now,
    List<Transaction> transactions = const <Transaction>[],
    List<Wallet> wallets = const <Wallet>[],
  }) {
    final recentTransactions = transactions.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latestTransactions = recentTransactions.take(5).toList();
    final todaysMoney = computeTodaysMoney(transactions, now);
    final relevantGoal = selectRelevantGoal(goals);
    final upcomingAttention = selectUpcomingAttention(
      upcomingBills: upcomingBills,
      upcomingPayments: upcomingPayments,
      loanSummary: loanSummary,
      now: now,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formattedDate,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Search PaySense',
                icon: Icon(Icons.search_rounded, color: AppColors.textPrimary),
                onPressed: () {
                  AnalyticsService.instance.log(AnalyticsEvent.featureSearchOpened);
                  Navigator.of(context).pushNamed(AppRoutes.featureSearch);
                },
              ),
              const _NotificationBell(),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          // CONSUMER MONETIZATION FOUNDATION (PHASE 12) — "Let's build
          // your financial picture" checklist. A pure ADDITION: renders
          // nothing once all 4 real building blocks exist, so an
          // established account never sees this at all.
          if (!(wallets.isNotEmpty &&
              transactions.any((t) => t.transactionType.toLowerCase() == 'income') &&
              transactions.any((t) => t.transactionType.toLowerCase() == 'expense') &&
              goals.isNotEmpty)) ...[
            const SizedBox(height: 16),
            _GettingStartedChecklist(
              hasWallet: wallets.isNotEmpty,
              hasIncome: transactions.any((t) => t.transactionType.toLowerCase() == 'income'),
              hasExpense: transactions.any((t) => t.transactionType.toLowerCase() == 'expense'),
              hasGoal: goals.isNotEmpty,
            ),
          ],
          const SizedBox(height: 24),
          AppCard(
            padding: const EdgeInsets.all(24),
            color: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Net Worth',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                Text(
                  currencyFormatter.format(netWorth),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _InfoPill(
                        title: 'Total Assets',
                        value: currencyFormatter.format(totalAssets),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoPill(
                        title: 'Total Liabilities',
                        value: currencyFormatter.format(totalLiabilities),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: QuickActionButton(
                  icon: Icons.add_circle_outline,
                  label: 'Add Income',
                  color: AppColors.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddIncomeScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.remove_circle_outline,
                  label: 'Add Expense',
                  color: AppColors.accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.bar_chart_rounded,
                  label: 'Budget',
                  color: AppColors.secondary,
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.budget),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "This Month's Summary",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SummaryCard(
                title: 'Income',
                value: currencyFormatter.format(totals.totalIncome),
                icon: Icons.arrow_downward_rounded,
                iconColor: AppColors.success,
              ),
              const SizedBox(width: 12),
              SummaryCard(
                title: 'Expenses',
                value: currencyFormatter.format(totals.totalExpense),
                icon: Icons.arrow_upward_rounded,
                iconColor: AppColors.danger,
              ),
              const SizedBox(width: 12),
              SummaryCard(
                title: 'Savings',
                value: currencyFormatter.format(totals.balance),
                icon: Icons.savings_rounded,
                iconColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const DailyCheckInCard(),
          const SizedBox(height: 12),
          const YourMoneyExplainedCard(),
          const SizedBox(height: 12),
          const SpendingPatternCard(),
          const SizedBox(height: 12),
          SafeToSpendCard(currencyFormatter: currencyFormatter),
          const SizedBox(height: 12),
          FunFundsCard(currencyFormatter: currencyFormatter),
          const SizedBox(height: 12),
          CashFlowCard(currencyFormatter: currencyFormatter),
          const SizedBox(height: 12),
          SubscriptionsCard(currencyFormatter: currencyFormatter),
          const SizedBox(height: 24),
          Text(
            "Today's Money",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: !todaysMoney.hasActivity
                ? Text(
                    'No activity today',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _TodayStat(
                              label: 'Spent',
                              value: currencyFormatter.format(todaysMoney.spent),
                              color: AppColors.danger,
                            ),
                          ),
                          Expanded(
                            child: _TodayStat(
                              label: 'Income',
                              value: currencyFormatter.format(todaysMoney.income),
                              color: AppColors.success,
                            ),
                          ),
                          Expanded(
                            child: _TodayStat(
                              label: 'Net',
                              value:
                                  '${todaysMoney.net >= 0 ? '+' : ''}${currencyFormatter.format(todaysMoney.net)}',
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      _SpendingAwarenessLine(transactions: transactions, goals: goals, now: now),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          const FinancialHealthCard(),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.monthlyReview),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lightTeal,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Review',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'See how you managed your money this month →',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.reports),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lightTeal,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.insert_chart_outlined_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reports',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Where your money went, and how it compares →',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.financialPlanning),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lightTeal,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.insights_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Financial Planning',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        "You're $planningReadinessScore% "
                        'financially prepared — View plan →',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Budget',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.budget),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasBudgets)
            AppCard(
              padding: const EdgeInsets.all(20),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.budget),
              child: Text(
                'Set a monthly budget to track your spending.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.all(20),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.budget),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${currencyFormatter.format(budgetTotals.totalSpent)} / ${currencyFormatter.format(budgetTotals.totalBudget)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                      Text(
                        '${budgetTotals.percentageUsed.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (budgetTotals.percentageUsed / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        budgetTotals.percentageUsed > 100
                            ? AppColors.danger
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    budgetTotals.remainingBudget < 0
                        ? '${currencyFormatter.format(-budgetTotals.remainingBudget)} over budget'
                        : 'Remaining: ${currencyFormatter.format(budgetTotals.remainingBudget)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: budgetTotals.remainingBudget < 0
                          ? AppColors.danger
                          : AppColors.textSecondary,
                      fontWeight: budgetTotals.remainingBudget < 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Upcoming Attention',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _UpcomingAttentionCard(
            item: upcomingAttention,
            currencyFormatter: currencyFormatter,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Goals',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.goals),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (relevantGoal == null)
            AppCard(
              padding: const EdgeInsets.all(20),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.goals),
              child: Text(
                'Create your first savings goal.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.all(20),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.goals),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎯 ${relevantGoal.title}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${currencyFormatter.format(relevantGoal.currentAmount)} / ${currencyFormatter.format(relevantGoal.targetAmount)}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (relevantGoal.progressPercentage / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${relevantGoal.progressPercentage.clamp(0, 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Upcoming Payments',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.recurring),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (upcomingPayments.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(20),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.recurring),
              child: Text(
                'No payments due in the next 7 days.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.recurring),
              child: Column(
                children: upcomingPayments.take(3).map((payment) {
                  final isIncome =
                      payment.transactionType.toLowerCase() == 'income';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isIncome
                                    ? AppColors.success
                                    : AppColors.danger)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isIncome
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: isIncome
                                ? AppColors.success
                                : AppColors.danger,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payment.title,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              Text(
                                'Due ${_formatDate(payment.nextDueDate)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isIncome ? '+' : '-'}${currencyFormatter.format(payment.amount)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isIncome
                                    ? AppColors.success
                                    : AppColors.danger,
                              ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Upcoming Bills',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.bills),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (upcomingBills.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(20),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.bills),
              child: Text(
                'No bills due or overdue right now.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.bills),
              child: Column(
                children: upcomingBills.take(3).map((bill) {
                  final isOverdue = bill.isOverdue(DateTime.now());
                  final statusColor = isOverdue
                      ? AppColors.danger
                      : AppColors.warning;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isOverdue
                                ? Icons.warning_amber_rounded
                                : Icons.receipt_long_rounded,
                            color: statusColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bill.title,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              Text(
                                isOverdue
                                    ? 'Overdue since ${_formatDate(bill.dueDate)}'
                                    : 'Due ${_formatDate(bill.dueDate)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: statusColor),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${bill.amount.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Loans',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.loans),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (loanSummary.activeLoans == 0)
            AppCard(
              padding: const EdgeInsets.all(20),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.loans),
              child: Text(
                'No active loans. Add one to track EMIs automatically.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.all(20),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.loans),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Outstanding: ${currencyFormatter.format(loanSummary.outstandingBalance)}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Monthly EMI: ${currencyFormatter.format(loanSummary.totalEmiPerMonth)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${loanSummary.activeLoans} active',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (loanSummary.nextEmiDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Next EMI: ${loanSummary.nextEmiLoanName} · ${currencyFormatter.format(loanSummary.nextEmiAmount)} · ${_formatDate(loanSummary.nextEmiDate!)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Your Financial Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const _FinancialActionsSection(),
          const SizedBox(height: 10),
          const _FinancialSafetyEntryLine(),
          const SizedBox(height: 10),
          const _BankConnectEntryLine(),
          const SizedBox(height: 10),
          const _FinancialTrendEntryLine(),
          const _ProactiveInsightsSection(),
          const SizedBox(height: 10),
          const _FinancialTimelineEntryLine(),
          const SizedBox(height: 10),
          const _FinancialCompareEntryLine(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Recent Transactions',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.transactions),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: latestTransactions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No transactions yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : Column(
                    children: latestTransactions.map((transaction) {
                      return TransactionItem(
                        title: transaction.title,
                        subtitle: transaction.note.isEmpty
                            ? 'No note added'
                            : transaction.note,
                        amount: _formatAmount(
                          transaction.amount,
                          transaction.transactionType,
                          currencyCode,
                        ),
                        icon: _iconForTransactionType(
                          transaction.transactionType,
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTotals {
  const _DashboardTotals({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  final double totalIncome;
  final double totalExpense;
  final double balance;
}

/// AUDIT FIX — this used to sum ALL transactions ever recorded (no date
/// filter) under an unlabeled "Financial Summary" heading, while every
/// sibling widget on this same screen (Safe-to-Spend, Cash Flow) and every
/// other feature that shows income/expense (Reports, Financial Health,
/// Compare Periods) is current-month-scoped — for any account with
/// prior-month history the two would silently disagree on what read as the
/// same metric. Fixed by reusing [AnalyticsSummary] — the SAME
/// current-month calculation [FinancialHealthCalculator] and the Loan
/// Analytics card already consume — instead of a second, independently
/// re-derived income/expense formula. See
/// cross_feature_financial_consistency_test.dart for the regression proof
/// this now agrees with Reports' "This month" figures.
_DashboardTotals _totalsFromAnalytics(AnalyticsSummary analytics) {
  return _DashboardTotals(
    totalIncome: analytics.currentMonthIncome,
    totalExpense: analytics.currentMonthExpense,
    balance: analytics.currentMonthIncome - analytics.currentMonthExpense,
  );
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

/// Records the top Financial Health insight as an in-app notification, but
/// only when it's a warning (overdue bills, high EMI burden, etc.) — the
/// "meaningful new insight" case worth surfacing as a notification, not
/// every routine positive/tip message. Deduped by message content, so this
/// firing again with the same insight (e.g. on every Dashboard rebuild) is
/// always a no-op.
void _maybeRecordFinancialHealthNotification(
  WidgetRef ref,
  FinancialHealthResult health,
) {
  if (!health.hasSufficientData || health.insights.isEmpty) {
    return;
  }
  final topInsight = health.insights.first;
  if (topInsight.type != FinancialInsightType.warning) {
    return;
  }
  ref.read(notificationsProvider.notifier).addIfNotExists(
    AppNotification(
      id: 'financialHealth:${topInsight.message.hashCode}',
      title: 'Financial Health',
      message: topInsight.message,
      type: NotificationType.financialHealth.name,
      createdAt: DateTime.now(),
      relatedRoute: AppRoutes.financialHealth,
    ),
  );
}

/// PROACTIVE FINANCIAL INSIGHTS 1.0 (PHASE 7) — mirrors
/// [_maybeRecordFinancialHealthNotification] exactly. Only critical/high
/// priority insights are meaningful enough to notify about; [insight.id]
/// (already `type:entity:period`) is reused directly as the notification id,
/// so [NotificationsNotifier.addIfNotExists] naturally prevents duplicate
/// notifications for the same insight across rebuilds/app launches within
/// the same period. Gated on the user's own notification preference.
void _maybeRecordInsightNotification(
  WidgetRef ref,
  FinancialInsightResult result,
) {
  final insightNotificationsEnabled =
      ref.read(settingsProvider).value?.insightNotifications ?? true;
  if (!insightNotificationsEnabled) {
    return;
  }
  for (final insight in result.insights) {
    if (insight.priority != InsightPriority.critical &&
        insight.priority != InsightPriority.high) {
      continue;
    }
    ref.read(notificationsProvider.notifier).addIfNotExists(
      AppNotification(
        id: insight.id,
        title: insight.title,
        message: insight.explanation,
        type: NotificationType.insight.name,
        createdAt: DateTime.now(),
        relatedRoute: insight.actionRoute,
      ),
    );
  }
}

String _formatAmount(double amount, String transactionType, String currencyCode) {
  final sign = transactionType.toLowerCase() == 'income' ? '+' : '-';
  return '$sign${CurrencyFormatter.symbolFor(currencyCode)}${amount.toStringAsFixed(0)}';
}

IconData _iconForTransactionType(String transactionType) {
  final normalizedType = transactionType.toLowerCase();
  if (normalizedType == 'income') {
    return Icons.account_balance_rounded;
  }
  return Icons.shopping_bag_rounded;
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: AppColors.primary,
            ),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.notifications),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// FINANCIAL ACTION ENGINE 1.0 (PHASE 8/11) — upgrades the dashboard's
/// former single-insight card into up to 3 prioritized, actionable cards.
/// This REPLACES `_SmartInsightCard` in the exact same dashboard slot
/// rather than adding a new section alongside it — the two communicated
/// overlapping information ("what's going on with my money"), and
/// `FinancialActionPlan` is a strict superset (richer, prioritized,
/// data-backed) of what the old single insight showed.
class _FinancialActionsSection extends ConsumerWidget {
  const _FinancialActionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(financialActionPlanProvider);

    if (plan.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Keep tracking your spending to unlock personalized actions.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final action in plan.actions) ...[
          _FinancialActionCard(action: action),
          if (action != plan.actions.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// FINANCIAL HEALTH TRENDS 3.0 — PHASE 16's "ONE compact entry point",
/// integrated directly under the existing "Your Financial Actions"
/// section rather than adding a separate card, per the milestone's own
/// "reuse this area instead of adding unnecessary cards" instruction.
/// PAIN-OF-PAYING ENGINE — the Dashboard's compact "Spending Awareness"
/// line, embedded inside the existing "Today's Money" card rather than a
/// new section (per the milestone's own "don't overload the dashboard"
/// instruction). Evaluates only TODAY's expense transactions — a small,
/// bounded set — so this stays cheap. Renders nothing when there's
/// nothing worth flagging, exactly like the rest of this dashboard's
/// entry lines.
class _SpendingAwarenessLine extends ConsumerWidget {
  const _SpendingAwarenessLine({required this.transactions, required this.goals, required this.now});

  final List<Transaction> transactions;
  final List<Goal> goals;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaysExpenses = transactions.where(
      (t) =>
          t.transactionType.toLowerCase() == 'expense' &&
          t.createdAt.year == now.year &&
          t.createdAt.month == now.month &&
          t.createdAt.day == now.day,
    ).toList();
    if (todaysExpenses.isEmpty) return const SizedBox.shrink();

    final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
    final safeToSpend = ref.watch(safeToSpendProvider);

    var needsAttention = 0;
    for (final t in todaysExpenses) {
      final result = PainOfPayingEngine.evaluate(
        amount: t.amount,
        categoryId: t.categoryId,
        transactions: transactions,
        budgets: budgets,
        goals: goals,
        now: now,
        safeToSpend: safeToSpend,
        excludeTransactionId: t.id,
      );
      if (result.level != PainOfPayingLevel.low) needsAttention++;
    }
    if (needsAttention == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.transactions),
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, size: 15, color: AppColors.warning),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$needsAttention purchase${needsAttention == 1 ? '' : 's'} today need${needsAttention == 1 ? 's' : ''} attention',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// FINANCIAL SAFETY ENGINE — PART J. Highest-priority compact entry
/// point ("Money -> Risk -> Upcoming -> Insight"). When there are no
/// active alerts this shows a calm positive confirmation rather than
/// nothing at all — the dashboard's job is to answer "how financially
/// safe am I right now", and silence doesn't answer that.
class _FinancialSafetyEntryLine extends ConsumerWidget {
  const _FinancialSafetyEntryLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safetyAsync = ref.watch(financialSafetyAlertsProvider);
    if (safetyAsync.isLoading) return const SizedBox.shrink();
    final alerts = safetyAsync.value ?? const [];

    final bool hasAlerts = alerts.isNotEmpty;
    final topAlert = hasAlerts ? alerts.first : null;
    final color = hasAlerts
        ? switch (topAlert!.severity) {
            FinancialSafetyAlertSeverity.high => AppColors.danger,
            FinancialSafetyAlertSeverity.attention => AppColors.warning,
            FinancialSafetyAlertSeverity.info => AppColors.primary,
          }
        : AppColors.success;

    final subtitle = hasAlerts
        ? topAlert!.title.replaceFirst('PaySense insight: ', '')
        : 'You\'re financially stable right now — no immediate concerns';
    final chipTint = color.withValues(alpha: 0.12);

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.financialAlerts),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: chipTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasAlerts ? Icons.shield_outlined : Icons.shield_rounded,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Safety',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'View safety →',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BankConnectEntryLine extends ConsumerWidget {
  const _BankConnectEntryLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(accountAggregatorConnectionsProvider).value ?? const [];
    final active = connections.where((c) => c.status != ConnectionStatus.revoked).toList();

    String subtitle;
    IconData icon;
    Color color;
    String route = AppRoutes.connectedAccounts;

    if (active.isEmpty) {
      subtitle = 'Sync your bank accounts for automated tracking';
      icon = Icons.account_balance_outlined;
      color = AppColors.primary;
      route = AppRoutes.bankConnect;
    } else if (active.any((c) => c.status == ConnectionStatus.failed)) {
      subtitle = 'Bank sync needs attention';
      icon = Icons.error_outline_rounded;
      color = AppColors.danger;
    } else {
      final mostRecentSync = active
          .map((c) => c.lastSyncedAt)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (latest, d) => latest == null || d.isAfter(latest) ? d : latest);
      if (mostRecentSync == null) {
        subtitle = 'Finish connecting your accounts';
        icon = Icons.account_balance_outlined;
        color = AppColors.warning;
      } else {
        final minutesAgo = DateTime.now().difference(mostRecentSync).inMinutes;
        subtitle = minutesAgo < 60
            ? 'Last synced $minutesAgo min ago'
            : 'Last synced ${DateFormat('d MMM').format(mostRecentSync)}';
        icon = Icons.account_balance_rounded;
        color = AppColors.success;
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).pushNamed(route),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bank Connect',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Connect →',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialTrendEntryLine extends ConsumerWidget {
  const _FinancialTrendEntryLine();

  (String, IconData, Color) _copyFor(OverallTrajectory trajectory) {
    switch (trajectory) {
      case OverallTrajectory.stronglyImproving:
      case OverallTrajectory.improving:
        return ('Your financial health is improving', Icons.trending_up_rounded, AppColors.success);
      case OverallTrajectory.declining:
        return ('Your financial health needs attention', Icons.trending_down_rounded, AppColors.danger);
      case OverallTrajectory.mixed:
        return ('Your finances show mixed signals', Icons.swap_vert_rounded, AppColors.warning);
      case OverallTrajectory.stable:
        return ('Your financial health is steady', Icons.trending_flat_rounded, AppColors.textSecondary);
      case OverallTrajectory.insufficientData:
        return ('See how your financial health changes over time', Icons.auto_graph_rounded, AppColors.primary);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trajectory = ref.watch(financialHealthTrendsProvider).trajectory;
    final (subtitle, icon, color) = _copyFor(trajectory);

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.financialHealthTrends),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Journey',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Explore journey →',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// PROACTIVE FINANCIAL INSIGHTS 1.0 (PHASE 4) — up to 3 insights, reusing
/// the [_FinancialActionCard] icon-chip-in-[AppCard] visual language.
/// Renders nothing at all (no heading, no spacing) when there are no
/// insights, so an empty result never adds clutter to the Dashboard.
class _ProactiveInsightsSection extends ConsumerWidget {
  const _ProactiveInsightsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(financialInsightsProvider);

    if (result.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights for You',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final insight in result.insights) ...[
            _InsightCard(insight: insight),
            if (insight != result.insights.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final FinancialInsight insight;

  (IconData, Color, Color) _visualsFor() {
    switch (insight.priority) {
      case InsightPriority.critical:
      case InsightPriority.high:
        return (Icons.warning_amber_rounded, AppColors.danger, AppColors.softCoral);
      case InsightPriority.medium:
        return (Icons.info_outline_rounded, AppColors.warning, AppColors.lightTeal);
      case InsightPriority.low:
        return (Icons.lightbulb_outline_rounded, AppColors.textSecondary, AppColors.surfaceVariant);
      case InsightPriority.positive:
        return (Icons.emoji_events_rounded, AppColors.success, AppColors.lightTeal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor, chipTint) = _visualsFor();
    final route = insight.actionRoute;

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: route == null
          ? null
          : () => Navigator.of(context).pushNamed(route),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: chipTint, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.explanation,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${insight.recommendedAction} →',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialTimelineEntryLine extends ConsumerWidget {
  const _FinancialTimelineEntryLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.financialTimeline),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Timeline',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Review key financial milestones & historical events',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'View events →',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialCompareEntryLine extends StatelessWidget {
  const _FinancialCompareEntryLine();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.financialCompare),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.compare_arrows_rounded, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compare Periods',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Analyze income & spending trends between custom periods',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Compare →',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// CONSUMER MONETIZATION FOUNDATION (PHASE 12) — "Let's build your
/// financial picture." All 4 checks come from real, already-watched data
/// (wallets/transactions/goals) — never fabricated, never blocking; the
/// user can leave any item incomplete indefinitely.
class _GettingStartedChecklist extends StatelessWidget {
  const _GettingStartedChecklist({
    required this.hasWallet,
    required this.hasIncome,
    required this.hasExpense,
    required this.hasGoal,
  });

  final bool hasWallet;
  final bool hasIncome;
  final bool hasExpense;
  final bool hasGoal;

  int get _doneCount => [hasWallet, hasIncome, hasExpense, hasGoal].where((b) => b).length;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Let's build your financial picture",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$_doneCount/4',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$_doneCount of 4 done — your Financial Snapshot is getting smarter.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _doneCount / 4,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),
          _ChecklistRow(
            label: 'Wallet',
            done: hasWallet,
            onTap: hasWallet
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddEditWalletScreen())),
          ),
          _ChecklistRow(
            label: 'Income',
            done: hasIncome,
            onTap: hasIncome
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddIncomeScreen())),
          ),
          _ChecklistRow(
            label: 'Expense',
            done: hasExpense,
            onTap: hasExpense
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
          ),
          _ChecklistRow(
            label: 'Goal',
            done: hasGoal,
            onTap: hasGoal ? null : () => Navigator.of(context).pushNamed(AppRoutes.goals),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.done, required this.onTap});

  final String label;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 20,
              color: done ? AppColors.success : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: done ? AppColors.textSecondary : AppColors.textPrimary,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (!done) Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _FinancialActionCard extends StatelessWidget {
  const _FinancialActionCard({required this.action});

  final FinancialAction action;

  // Icon + a small translucent chip tint behind it only — never the whole
  // card's background. Matches the established pattern from
  // _WhatIfResultCard/_TaxOutcomeCard/_FinancialPlanningCard: lightTeal/
  // softCoral are translucent overlays meant for a small chip, not an
  // opaque full-card background (which loses contrast badly in dark mode
  // — see financial_action_affordability_dark_mode_test.dart).
  (IconData, Color, Color) _visualsFor(BuildContext context) {
    switch (action.priority) {
      case ActionPriority.critical:
      case ActionPriority.high:
        return (Icons.warning_amber_rounded, AppColors.danger, AppColors.softCoral);
      case ActionPriority.medium:
        return (Icons.info_outline_rounded, AppColors.warning, AppColors.lightTeal);
      case ActionPriority.positive:
        return (Icons.emoji_events_rounded, AppColors.success, AppColors.lightTeal);
    }
  }

  String _routeFor(FinancialAction action) {
    switch (action.category) {
      case ActionCategory.overspending:
      case ActionCategory.budget:
        return AppRoutes.budget;
      case ActionCategory.debt:
        return AppRoutes.loans;
      case ActionCategory.subscriptions:
        return AppRoutes.subscriptions;
      case ActionCategory.emergencyFund:
      case ActionCategory.goals:
      case ActionCategory.savings:
      case ActionCategory.cashFlow:
      case ActionCategory.tax:
      case ActionCategory.positiveProgress:
        return AppRoutes.financialPlanning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor, chipTint) = _visualsFor(context);

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).pushNamed(_routeFor(action)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: chipTint, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.explanation,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${action.recommendedAction} →',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingAttentionCard extends StatelessWidget {
  const _UpcomingAttentionCard({
    required this.item,
    required this.currencyFormatter,
  });

  final UpcomingAttentionItem? item;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    final current = item;
    if (current == null) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.celebration_rounded, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "You're all caught up 🎉",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isOverdue = current.type == UpcomingAttentionType.overdueBill;
    final color = isOverdue ? AppColors.danger : AppColors.primary;
    final IconData icon;
    final String statusText;
    final String targetRoute;
    switch (current.type) {
      case UpcomingAttentionType.overdueBill:
        icon = Icons.warning_amber_rounded;
        statusText = 'Overdue';
        targetRoute = AppRoutes.bills;
      case UpcomingAttentionType.dueSoonBill:
        icon = Icons.receipt_long_rounded;
        statusText = 'Due ${_formatDate(current.dueDate)}';
        targetRoute = AppRoutes.bills;
      case UpcomingAttentionType.recurringPayment:
        icon = Icons.autorenew_rounded;
        statusText = 'Due ${_formatDate(current.dueDate)}';
        targetRoute = AppRoutes.recurring;
      case UpcomingAttentionType.loanEmi:
        icon = Icons.account_balance_rounded;
        statusText = 'EMI due ${_formatDate(current.dueDate)}';
        targetRoute = AppRoutes.loans;
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      onTap: () => Navigator.of(context).pushNamed(targetRoute),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  statusText,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
          Text(
            currencyFormatter.format(current.amount),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayStat extends StatelessWidget {
  const _TodayStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String title;
  final String value;

  const _InfoPill({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
