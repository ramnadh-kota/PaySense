import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/fun_funds_expense.dart';
import 'package:paysense/shared/providers/fun_funds_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/group_expense_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'package:uuid/uuid.dart';

class AddGroupExpenseScreen extends ConsumerStatefulWidget {
  const AddGroupExpenseScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<AddGroupExpenseScreen> createState() => _AddGroupExpenseScreenState();
}

class _AddGroupExpenseScreenState extends ConsumerState<AddGroupExpenseScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String? _payer;
  final Set<String> _participants = {};
  String? _error;
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _ensureInitialized(List<String> members) {
    if (_initialized || members.isEmpty) return;
    _payer = members.first;
    _participants.addAll(members);
    _initialized = true;
  }

  Future<void> _save(double totalAmount) async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Describe what this expense was for.');
      return;
    }
    if (totalAmount <= 0) {
      setState(() => _error = 'Enter an amount greater than ₹0.');
      return;
    }
    if (_payer == null) {
      setState(() => _error = 'Choose who paid.');
      return;
    }
    if (_participants.isEmpty) {
      setState(() => _error = 'Select at least one participant.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    await ref.read(funFundsExpensesProvider.notifier).addExpense(
          FunFundsExpense(
            id: const Uuid().v4(),
            groupId: widget.groupId,
            description: description,
            totalAmount: totalAmount,
            payerName: _payer!,
            participantNames: List<String>.unmodifiable(_participants),
            createdAt: DateTime.now(),
          ),
        );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(funFundsGroupsProvider);
    final matchingGroups = (groupsAsync.value ?? const []).where((g) => g.id == widget.groupId);
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
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    _ensureInitialized(group.memberNames);

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final shares = _participants.isEmpty ? const <double>[] : GroupExpenseCalculator.equalSplit(amount, _participants.length);
    final shareAmount = shares.isEmpty ? 0.0 : shares.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Add Expense'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              'Description',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'e.g. Hotel, Dinner, Cab'),
            ),
            const SizedBox(height: 20),
            Text(
              'Total amount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(prefixText: '₹ ', hintText: '0'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Text(
              'Paid by',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.memberNames
                  .map(
                    (member) => ChoiceChip(
                      label: Text(member),
                      selected: _payer == member,
                      onSelected: (_) => setState(() => _payer = member),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Split equally between',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: group.memberNames
                    .map(
                      (member) => CheckboxListTile(
                        value: _participants.contains(member),
                        title: Text(member),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _participants.add(member);
                            } else {
                              _participants.remove(member);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            if (amount > 0 && _participants.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${currencyFormatter.format(shareAmount)} per person '
                '(${_participants.length} ${_participants.length == 1 ? 'person' : 'people'})',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : () => _save(amount),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
