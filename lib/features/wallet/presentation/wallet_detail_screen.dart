import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/utils/wallet_account_resolver.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'add_edit_wallet_screen.dart';

/// Shows one wallet's current balance, its income/expense activity, and its
/// recent transactions — [Wallet.currentBalance] is used as-is (never
/// re-derived independently), and income/expense totals only ever sum
/// `'income'`/`'expense'` transactions, never `'transfer'` ones, so this
/// screen can't misrepresent a transfer as earned/spent money.
class WalletDetailScreen extends ConsumerWidget {
  const WalletDetailScreen({super.key, required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(wallet.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AddEditWalletScreen(wallet: wallet)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: transactionsAsync.when(
          data: (allTransactions) {
            final related =
                allTransactions.where((t) => _belongsToWallet(t, wallet, wallets)).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            double income = 0;
            double expense = 0;
            for (final t in related) {
              final type = t.transactionType.toLowerCase();
              if (type == 'income') {
                income += t.amount;
              } else if (type == 'expense') {
                expense += t.amount;
              }
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(24),
                  color: AppColors.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Balance',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '₹${wallet.currentBalance.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${wallet.type} · ${wallet.bankName.isEmpty ? wallet.name : wallet.bankName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(label: 'Income', value: income, color: AppColors.success),
                      ),
                      Expanded(
                        child: _Stat(label: 'Expenses', value: expense, color: AppColors.danger),
                      ),
                      Expanded(
                        child: _Stat(
                          label: 'Net movement',
                          value: income - expense,
                          color: AppColors.primary,
                          signed: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Recent transactions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                if (related.isEmpty)
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No transactions recorded against this account yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: related.take(20).map((t) => _TransactionRow(transaction: t)).toList(),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load transactions right now.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Every transaction created through the current wallet-selection UI
  /// (Add Expense/Income, Bill/Loan/Recurring payments, Transfers) already
  /// stores a real [Wallet.id] in `accountId`, so this resolves to an exact
  /// match. Older records that still hold a legacy display label are
  /// matched via the same centralized, non-guessing resolver used
  /// throughout the app — see [resolveWalletIdForAccount].
  static bool _belongsToWallet(Transaction t, Wallet wallet, List<Wallet> wallets) {
    return resolveWalletIdForAccount(t.accountId, wallets) == wallet.id;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    this.signed = false,
  });

  final String label;
  final double value;
  final Color color;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final prefix = signed && value >= 0 ? '+' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          '$prefix₹${value.toStringAsFixed(0)}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final type = transaction.transactionType.toLowerCase();
    final isTransfer = type == 'transfer';
    final isIncome = type == 'income';

    final IconData icon;
    final Color color;
    final String sign;
    if (isTransfer) {
      icon = Icons.swap_horiz_rounded;
      color = AppColors.primary;
      sign = transaction.title.startsWith('Transfer from') ? '+' : '-';
    } else if (isIncome) {
      icon = Icons.arrow_downward_rounded;
      color = AppColors.success;
      sign = '+';
    } else {
      icon = Icons.arrow_upward_rounded;
      color = AppColors.danger;
      sign = '-';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _formatDate(transaction.createdAt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '$sign₹${transaction.amount.toStringAsFixed(0)}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
