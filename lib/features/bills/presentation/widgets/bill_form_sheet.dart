import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/bill.dart';

const List<String> _frequencies = <String>['Weekly', 'Monthly', 'Yearly'];
const List<String> _accounts = <String>['Checking', 'Savings', 'Credit Card', 'Cash'];

class BillFormSheet extends StatefulWidget {
  const BillFormSheet({super.key, this.bill, required this.onSave});

  final Bill? bill;
  final Future<void> Function(Bill bill) onSave;

  @override
  State<BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends State<BillFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _noteController = TextEditingController();
  final _reminderController = TextEditingController(text: '2');

  String _account = _accounts.first;
  String _frequency = 'Monthly';
  bool _isRecurring = false;
  late DateTime _dueDate;

  @override
  void initState() {
    super.initState();
    final bill = widget.bill;
    if (bill != null) {
      _titleController.text = bill.title;
      _amountController.text = bill.amount.toStringAsFixed(0);
      _categoryController.text = bill.categoryId;
      _noteController.text = bill.note;
      _reminderController.text = bill.reminderDaysBefore.toString();
      _account = _accounts.contains(bill.accountId)
          ? bill.accountId
          : _accounts.first;
      _frequency = _frequencies.contains(bill.frequency)
          ? bill.frequency
          : _frequencies[1];
      _isRecurring = bill.isRecurring;
      _dueDate = bill.dueDate;
    } else {
      _dueDate = DateTime.now().add(const Duration(days: 7));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _reminderController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
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
        int.tryParse(_reminderController.text.trim()) ?? 2;

    final id = widget.bill?.id ?? const Uuid().v4();
    final createdAt = widget.bill?.createdAt ?? DateTime.now();

    final bill = widget.bill == null
        ? Bill.create(
            id: id,
            title: _titleController.text.trim(),
            amount: amount,
            categoryId: _categoryController.text.trim(),
            accountId: _account,
            dueDate: _dueDate,
            isRecurring: _isRecurring,
            frequency: _frequency,
            reminderDaysBefore: reminderDaysBefore,
            note: _noteController.text.trim(),
            createdAt: createdAt,
          )
        : widget.bill!.copyWith(
            title: _titleController.text.trim(),
            amount: amount,
            categoryId: _categoryController.text.trim(),
            accountId: _account,
            dueDate: _dueDate,
            isRecurring: _isRecurring,
            frequency: _frequency,
            reminderDaysBefore: reminderDaysBefore,
            note: _noteController.text.trim(),
            updatedAt: DateTime.now(),
          );

    await widget.onSave(bill);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
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
                  widget.bill == null ? 'Create Bill' : 'Edit Bill',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Title',
                  controller: _titleController,
                  hint: 'Electricity bill',
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Enter a title' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Amount',
                  controller: _amountController,
                  hint: '1200',
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
                  hint: 'Utilities',
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
                const SizedBox(height: 12),
                _buildDateField(),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isRecurring,
                  onChanged: (value) => setState(() => _isRecurring = value),
                  activeThumbColor: AppColors.primary,
                  title: Text(
                    'Recurring bill',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Automatically reopens for the next cycle when marked paid',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                if (_isRecurring) ...[
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 12),
                ],
                _buildTextField(
                  label: 'Remind me (days before)',
                  controller: _reminderController,
                  hint: '2',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final days = int.tryParse(value?.trim() ?? '');
                    if (days == null || days < 0) {
                      return 'Enter a valid number of days';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Note (optional)',
                  controller: _noteController,
                  hint: 'Account number, plan details, etc.',
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
                  child: const Text('Save bill'),
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

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDueDate,
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
                  'Due date',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
            const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
