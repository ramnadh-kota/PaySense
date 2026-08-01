import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'widgets/quick_action_button.dart';
import 'widgets/summary_card.dart';
import 'widgets/transaction_item.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEE, d MMM yyyy').format(now);
    final transactionsAsync = ref.watch(transactionsProvider);
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
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
              formattedDate: formattedDate,
              currencyFormatter: currencyFormatter,
              totals: totals,
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
    required String formattedDate,
    required NumberFormat currencyFormatter,
    required _DashboardTotals totals,
  }) {
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
                      'Good Evening, Ramnadh 👋',
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              QuickActionButton(
                icon: Icons.wallet_rounded,
                label: 'Add Expense',
              ),
              QuickActionButton(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Add Income',
              ),
              QuickActionButton(
                icon: Icons.swap_horiz_rounded,
                label: 'Transfer',
              ),
              QuickActionButton(icon: Icons.bar_chart_rounded, label: 'Budget'),
            ],
          ),
          const SizedBox(height: 24),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'You spent 18% less than last week. Great job!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent Transactions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: const [
                TransactionItem(
                  title: 'Starbucks',
                  subtitle: 'Coffee & breakfast',
                  amount: '-₹480',
                  icon: Icons.coffee_rounded,
                ),
                TransactionItem(
                  title: 'Swiggy',
                  subtitle: 'Food delivery',
                  amount: '-₹320',
                  icon: Icons.delivery_dining_rounded,
                ),
                TransactionItem(
                  title: 'Amazon',
                  subtitle: 'Online purchase',
                  amount: '-₹1,299',
                  icon: Icons.shopping_bag_rounded,
                ),
                TransactionItem(
                  title: 'Salary',
                  subtitle: 'Monthly credit',
                  amount: '+₹58,000',
                  icon: Icons.account_balance_rounded,
                ),
                TransactionItem(
                  title: 'Uber',
                  subtitle: 'Ride home',
                  amount: '-₹180',
                  icon: Icons.directions_car_rounded,
                ),
              ],
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
