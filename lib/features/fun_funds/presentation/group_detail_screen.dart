import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/fun_funds_settlement.dart';
import 'package:paysense/shared/providers/fun_funds_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/group_expense_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'add_group_expense_screen.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(funFundsGroupsProvider);
    final expensesAsync = ref.watch(funFundsExpensesProvider);
    final settlementsAsync = ref.watch(funFundsSettlementsProvider);

    final matchingGroups = (groupsAsync.value ?? const []).where((g) => g.id == groupId);
    final group = matchingGroups.isEmpty ? null : matchingGroups.first;
    final currencyCode = ref.watch(userProfileProvider).value?.currency.isNotEmpty == true
        ? ref.watch(userProfileProvider).value!.currency
        : 'INR';
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: CurrencyFormatter.symbolFor(currencyCode),
      decimalDigits: 0,
    );

    if (group == null) {
      // The group was just deleted, or its provider is still loading —
      // never show a broken/blank screen.
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final expenses = (expensesAsync.value ?? const [])
        .where((e) => e.groupId == groupId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final settlements = (settlementsAsync.value ?? const []).where((s) => s.groupId == groupId).toList();

    final balances = GroupExpenseCalculator.netBalances(
      group: group, expenses: expenses, settlements: settlements,
    );
    final allDebts = GroupExpenseCalculator.allDebts(expenses: expenses, settlements: settlements);
    final pendingDebts = allDebts.where((d) => !d.isSettled).toList();
    final settledDebts = allDebts.where((d) => d.isSettled).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AddGroupExpenseScreen(groupId: groupId),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              color: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group total',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currencyFormatter.format(GroupExpenseCalculator.groupTotal(expenses)),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.memberNames.length} members · ${expenses.length} expense${expenses.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Balances',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (var i = 0; i < balances.length; i++) ...[
                    if (i > 0) const Divider(height: 20),
                    _BalanceRow(balance: balances[i], currencyFormatter: currencyFormatter),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Who owes whom',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (pendingDebts.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.celebration_rounded, color: AppColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        expenses.isEmpty
                            ? 'No expenses yet — add one to start splitting.'
                            : 'Everyone is settled up.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...pendingDebts.map(
                (debt) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DebtCard(
                    groupId: groupId,
                    debt: debt,
                    currencyFormatter: currencyFormatter,
                  ),
                ),
              ),
            if (settledDebts.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Settled',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...settledDebts.map(
                (debt) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DebtCard(
                    groupId: groupId,
                    debt: debt,
                    currencyFormatter: currencyFormatter,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Expenses',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (expenses.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No expenses recorded yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              )
            else
              ...expenses.map(
                (expense) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Paid by ${expense.payerName} · split ${expense.participantNames.length} ways',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          currencyFormatter.format(expense.totalAmount),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              kSettlementTrackingOnlyDisclaimer,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.balance, required this.currencyFormatter});

  final GroupMemberBalance balance;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    final color = balance.isOwed
        ? AppColors.success
        : balance.owes
            ? AppColors.danger
            : AppColors.textSecondary;
    final label = balance.isOwed
        ? 'is owed ${currencyFormatter.format(balance.netAmount)}'
        : balance.owes
            ? 'owes ${currencyFormatter.format(-balance.netAmount)}'
            : 'is settled up';

    return Row(
      children: [
        Expanded(
          child: Text(
            balance.memberName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

class _DebtCard extends ConsumerWidget {
  const _DebtCard({required this.groupId, required this.debt, required this.currencyFormatter});

  final String groupId;
  final GroupDebt debt;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Two rows, not one packed Row: with three-way real estate (debtor->
    // creditor text, amount, and the settle button) sharing a single Row,
    // long member names truncated the single most important piece of
    // information here — WHO the debt is owed to (confirmed on-device:
    // "Priya owes …" with the creditor's name silently cut off). The
    // description gets the full card width on its own line and is allowed
    // to wrap instead of ellipsizing.
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${debt.debtorName} owes ${debt.creditorName}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                currencyFormatter.format(debt.amount),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'for ${debt.expenseDescription}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () {
                if (debt.isSettled) {
                  ref.read(funFundsSettlementsProvider.notifier).markPending(
                        expenseId: debt.expenseId,
                        debtorName: debt.debtorName,
                      );
                } else {
                  ref.read(funFundsSettlementsProvider.notifier).markSettled(
                        groupId: groupId,
                        expenseId: debt.expenseId,
                        debtorName: debt.debtorName,
                      );
                }
              },
              child: Text(debt.isSettled ? 'Reopen' : 'Record settlement'),
            ),
          ),
        ],
      ),
    );
  }
}
