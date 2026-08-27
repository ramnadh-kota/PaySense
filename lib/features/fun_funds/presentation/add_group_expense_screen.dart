import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/fun_group_expense.dart';
import 'package:paysense/shared/providers/fun_group_expense_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'package:uuid/uuid.dart';

/// Logs a shared/group expense (dinner, trip, movie, ...) and splits it
/// evenly across everyone involved — purely a local calculation/tracking
/// record, never a payment or money transfer.
class AddGroupExpenseScreen extends ConsumerStatefulWidget {
  const AddGroupExpenseScreen({super.key});

  @override
  ConsumerState<AddGroupExpenseScreen> createState() =>
      _AddGroupExpenseScreenState();
}

class _AddGroupExpenseScreenState
    extends ConsumerState<AddGroupExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final List<TextEditingController> _friendControllers = [
    TextEditingController(),
  ];

  FunGroupExpenseCategory _category = FunGroupExpenseCategory.dinner;
  int _paidByIndex = 0; // 0 == "Me"; 1..n == friend index (n = i - 1)
  final DateTime _date = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (final controller in _friendControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> get _participantNames {
    final names = <String>['Me'];
    for (final controller in _friendControllers) {
      final name = controller.text.trim();
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
    return names;
  }

  double get _totalAmount => double.tryParse(_amountController.text.trim()) ?? 0;

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('Please enter what this expense was for.');
      return;
    }
    final total = _totalAmount;
    if (total <= 0) {
      _showError('Please enter a valid total amount.');
      return;
    }
    final names = _participantNames;
    if (names.length < 2) {
      _showError('Add at least one friend to split this with.');
      return;
    }
    if (_paidByIndex >= names.length) {
      _showError('Please choose who paid.');
      return;
    }

    final participants = FunGroupExpense.equalSplit(
      totalAmount: total,
      participantNames: names,
    );
    final paidByParticipantId = participants[_paidByIndex].id;

    // Whoever actually paid is trivially "settled" with themselves.
    final settledParticipants = participants
        .map(
          (p) => p.id == paidByParticipantId
              ? p.copyWith(isSettled: true)
              : p,
        )
        .toList();

    final expense = FunGroupExpense(
      id: const Uuid().v4(),
      title: title,
      categoryKey: _category.name,
      totalAmount: total,
      date: _date,
      paidByParticipantId: paidByParticipantId,
      participants: settledParticipants,
      createdAt: DateTime.now(),
    );

    await ref.read(funGroupExpensesProvider.notifier).addExpense(expense);

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addFriendField() {
    setState(() => _friendControllers.add(TextEditingController()));
  }

  void _removeFriendField(int index) {
    setState(() {
      _friendControllers[index].dispose();
      _friendControllers.removeAt(index);
      if (_paidByIndex > index) {
        _paidByIndex--;
      } else if (_paidByIndex == index + 1) {
        _paidByIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final names = _participantNames;
    final total = _totalAmount;
    final perPerson = names.length > 1 ? total / names.length : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Add Group Expense'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'What was this for?',
                hintText: 'Dinner with friends',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Total amount',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FunGroupExpenseCategory.values.map((category) {
                final selected = category == _category;
                return ChoiceChip(
                  label: Text(category.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = category),
                  selectedColor: AppColors.primary.withValues(alpha: 0.16),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'People',
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
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Me',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  for (var i = 0; i < _friendControllers.length; i++) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _friendControllers[i],
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: "Friend ${i + 1}'s name",
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AppColors.textSecondary,
                          onPressed: () => _removeFriendField(i),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addFriendField,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add another friend'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Paid by',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(names.length, (i) {
                final selected = i == _paidByIndex;
                return ChoiceChip(
                  label: Text(names[i]),
                  selected: selected,
                  onSelected: (_) => setState(() => _paidByIndex = i),
                  selectedColor: AppColors.primary.withValues(alpha: 0.16),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  ),
                );
              }),
            ),
            if (total > 0 && names.length > 1) ...[
              const SizedBox(height: 24),
              AppCard(
                color: AppColors.primary.withValues(alpha: 0.06),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Split ₹${perPerson.toStringAsFixed(0)} each · ${names.length} people',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _paidByIndex == 0
                          ? 'You paid ₹${total.toStringAsFixed(0)} · others owe you ₹${(total - perPerson).toStringAsFixed(0)}'
                          : '${names[_paidByIndex]} paid ₹${total.toStringAsFixed(0)} · you owe ₹${perPerson.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _handleSave,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
