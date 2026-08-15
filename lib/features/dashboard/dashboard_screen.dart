import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/providers/bill_provider.dart';
import 'package:paysense/shared/providers/budget_provider.dart';
import 'package:paysense/shared/providers/financial_health_provider.dart';
import 'package:paysense/shared/providers/goal_provider.dart';
import 'package:paysense/shared/providers/loan_provider.dart';
import 'package:paysense/shared/providers/notification_provider.dart';
import 'package:paysense/shared/providers/recurring_transaction_provider.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/dashboard_helpers.dart';
import 'package:paysense/shared/utils/financial_health_calculator.dart'
    show FinancialHealthResult, FinancialInsight, FinancialInsightType;
import 'package:paysense/shared/widgets/app_card.dart';
import '../../core/routes/app_routes.dart';
import '../transactions/presentation/add_expense_screen.dart';
import '../transactions/presentation/add_income_screen.dart';
import 'widgets/cash_flow_card.dart';
import 'widgets/financial_health_card.dart';
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
    final financialHealth = ref.watch(financialHealthProvider);
    ref.listen<FinancialHealthResult>(financialHealthProvider, (
      previous,
      next,
    ) {
      _maybeRecordFinancialHealthNotification(ref, next);
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
            final totals = _calculateTotals(transactions);
            return _buildDashboardContent(
              context: context,
              greeting: greeting,
              formattedDate: formattedDate,
              currencyFormatter: currencyFormatter,
              currencyCode: currencyCode,
              totals: totals,
              transactions: transactions,
              hasBudgets: (budgetsAsync.value ?? const []).isNotEmpty,
              budgetTotals: budgetTotals,
              goals: goalsAsync.value ?? const [],
              upcomingPayments: upcomingPayments,
              upcomingBills: upcomingBills,
              loanSummary: loanSummary,
              financialHealthInsight: financialHealth.hasSufficientData &&
                      financialHealth.insights.isNotEmpty
                  ? financialHealth.insights.first
                  : null,
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
    required FinancialInsight? financialHealthInsight,
    required DateTime now,
    List<Transaction> transactions = const <Transaction>[],
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
              const _NotificationBell(),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppCard(
            padding: const EdgeInsets.all(24),
            color: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total Net Worth',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+12.4%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  currencyFormatter.format(totals.balance),
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
                        value: '₹1,68,000',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoPill(
                        title: 'Total Liabilities',
                        value: '₹43,440',
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
            'Financial Summary',
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
          SafeToSpendCard(currencyFormatter: currencyFormatter),
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
                : Row(
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
                    'Remaining: ${currencyFormatter.format(budgetTotals.remainingBudget)}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
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
                      valueColor: const AlwaysStoppedAnimation<Color>(
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
            'Smart Insight',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _SmartInsightCard(insight: financialHealthInsight),
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
          const SizedBox(height: 24),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: QuickActionButton(
                  icon: Icons.remove_circle_outline,
                  label: 'Add expense',
                  color: AppColors.accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.add_circle_outline,
                  label: 'Add income',
                  color: AppColors.accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddIncomeScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.flag_outlined,
                  label: 'Add goal',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.goals),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.bar_chart_rounded,
                  label: 'Add budget',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.budget),
                ),
              ),
            ],
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

_DashboardTotals _calculateTotals(List<Transaction> transactions) {
  double totalIncome = 0;
  double totalExpense = 0;

  for (final transaction in transactions) {
    final normalizedType = transaction.transactionType.toLowerCase();
    if (normalizedType == 'income') {
      totalIncome += transaction.amount;
    } else if (normalizedType == 'expense') {
      totalExpense += transaction.amount;
    }
  }

  return _DashboardTotals(
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    balance: totalIncome - totalExpense,
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
            icon: const Icon(
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

class _SmartInsightCard extends StatelessWidget {
  const _SmartInsightCard({required this.insight});

  final FinancialInsight? insight;

  @override
  Widget build(BuildContext context) {
    final current = insight;
    if (current == null) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Keep tracking your spending to unlock personalized insights.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final color = switch (current.type) {
      FinancialInsightType.positive => AppColors.success,
      FinancialInsightType.tip => AppColors.primary,
      FinancialInsightType.warning => AppColors.accent,
    };
    final icon = switch (current.type) {
      FinancialInsightType.positive => Icons.emoji_events_rounded,
      FinancialInsightType.tip => Icons.lightbulb_outline_rounded,
      FinancialInsightType.warning => Icons.warning_amber_rounded,
    };
    final background = switch (current.type) {
      FinancialInsightType.warning => AppColors.softCoral,
      _ => AppColors.lightTeal,
    };

    return AppCard(
      padding: const EdgeInsets.all(20),
      color: background,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              current.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
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
