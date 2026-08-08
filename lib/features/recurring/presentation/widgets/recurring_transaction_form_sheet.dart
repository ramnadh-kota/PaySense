import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';

const List<String> _frequencies = <String>['Daily', 'Weekly', 'Monthly', 'Yearly'];
const List<String> _accounts = <String>['Checking', 'Savings', 'Credit Card', 'Cash'];

class RecurringTransactionFormSheet extends StatefulWidget {
  const RecurringTransactionFormSheet({
    super.key,
    this.item,
    required this.onSave,
  });

  final RecurringTransaction? item;
  final Future<void> Function(RecurringTransaction item) onSave;

  @override
  State<RecurringTransactionFormSheet> createState() =>
      _RecurringTransactionFormSheetState();
}

class _RecurringTransactionFormSheetState
    extends State<RecurringTransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _reminderController = TextEditingController(text: '1');

  String _transactionType = 'expense';
  String _account = _accounts.first;
  String _frequency = 'Monthly';
  late DateTime _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _titleController.text = item.title;
      _amountController.text = item.amount.toStringAsFixed(0);
      _categoryController.text = item.categoryId;
      _reminderController.text = item.reminderDaysBefore.toString();
      _transactionType = item.transactionType;
      _account = _accounts.contains(item.accountId)
          ? item.accountId
          : _accounts.first;
      _frequency = _frequencies.contains(item.frequency)
          ? item.frequency
          : _frequencies[2];
      _startDate = item.startDate;
      _endDate = item.endDate;
    } else {
      _startDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _reminderController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final initial = isStartDate ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isStartDate) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      return;
    }

    final reminderDaysBefore =
        int.tryParse(_reminderController.text.trim()) ?? 1;

    final id = widget.item?.id ?? const Uuid().v4();
    final createdAt = widget.item?.createdAt ?? DateTime.now();

    final item = widget.item == null
        ? RecurringTransaction.create(
            id: id,
            title: _titleController.text.trim(),
            amount: amount,
            categoryId: _categoryController.text.trim(),
            accountId: _account,
            transactionType: _transactionType,
            frequency: _frequency,
            startDate: _startDate,
            endDate: _endDate,
            reminderDaysBefore: reminderDaysBefore,
            createdAt: createdAt,
          )
        : widget.item!.copyWith(
            title: _titleController.text.trim(),
            amount: amount,
            categoryId: _categoryController.text.trim(),
            accountId: _account,
            transactionType: _transactionType,
            frequency: _frequency,
            startDate: _startDate,
            endDate: _endDate,
            clearEndDate: _endDate == null,
            reminderDaysBefore: reminderDaysBefore,
            updatedAt: DateTime.now(),
          );

    await widget.onSave(item);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: controller,
              children: [
                Text(
                  widget.item == null
                      ? 'Create Recurring Transaction'
                      : 'Edit Recurring Transaction',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Expense'),
                        selected: _transactionType == 'expense',
                        onSelected: (_) =>
                            setState(() => _transactionType = 'expense'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Income'),
                        selected: _transactionType == 'income',
                        onSelected: (_) =>
                            setState(() => _transactionType = 'income'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Title',
                  controller: _titleController,
                  hint: 'Netflix subscription',
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Enter a title' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Amount',
                  controller: _amountController,
                  hint: '499',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Category',
                  controller: _categoryController,
                  hint: 'Subscriptions',
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Enter a category' : null,
                ),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: 'Account',
                  value: _account,
                  items: _accounts,
                  onChanged: (value) => setState(() => _account = value!),
                ),
                const SizedBox(height: 16),
                Text(
                  'Frequency',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final frequency in _frequencies)
                      ChoiceChip(
                        label: Text(frequency),
                        selected: _frequency == frequency,
                        onSelected: (_) =>
                            setState(() => _frequency = frequency),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDateField(
                  label: 'Start date',
                  date: _startDate,
                  onTap: () => _pickDate(isStartDate: true),
                ),
                const SizedBox(height: 12),
                _buildDateField(
                  label: 'End date (optional)',
                  date: _endDate,
                  onTap: () => _pickDate(isStartDate: false),
                  onClear: _endDate == null
                      ? null
                      : () => setState(() => _endDate = null),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Remind me (days before)',
                  controller: _reminderController,
                  hint: '1',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final days = int.tryParse(value?.trim() ?? '');
                    if (days == null || days < 0) {
                      return 'Enter a valid number of days';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _handleSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Save recurring transaction'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 8,
          ),
        ),
        items: items
            .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
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
                  date == null
                      ? 'None'
                      : '${date.day}/${date.month}/${date.year}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
            Row(
              children: [
                if (onClear != null)
                  IconButton(
                    onPressed: onClear,
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
