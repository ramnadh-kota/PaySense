import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/budget.dart';

class BudgetFormSheet extends StatefulWidget {
  const BudgetFormSheet({super.key, this.budget, required this.onSave});

  final Budget? budget;
  final Future<void> Function(Budget budget) onSave;

  @override
  State<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<BudgetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  final _allocatedController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();
  bool _isSaving = false;

  static const List<String> _validMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _categoryController.text = widget.budget!.categoryName;
      _allocatedController.text = widget.budget!.allocatedAmount
          .toStringAsFixed(0);
      _monthController.text = widget.budget!.month;
      _yearController.text = widget.budget!.year.toString();
    }
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _allocatedController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    // Guards against a double-tap on "Save budget" creating two identical
    // records — mirrors the in-flight guards used elsewhere for financial
    // mutations that have no confirmation dialog in between.
    if (_isSaving) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final allocatedAmount =
        double.tryParse(_allocatedController.text.trim()) ?? 0.0;
    if (allocatedAmount <= 0) {
      return;
    }

    final month = _monthController.text.trim();
    final year =
        int.tryParse(_yearController.text.trim()) ?? DateTime.now().year;
    final categoryName = _categoryController.text.trim();
    // The real Transaction.categoryId is always the raw category label a
    // user picked when adding an expense (e.g. "Groceries") — reusing that
    // exact string here (rather than a lowercase-dashed transform of it)
    // is what lets BudgetRepository.refreshBudgets actually match spend
    // against this budget instead of silently tracking ₹0 forever.
    final categoryId = categoryName;
    final id = widget.budget?.id ?? const Uuid().v4();

    final budget = Budget.create(
      id: id,
      categoryId: categoryId,
      categoryName: categoryName,
      allocatedAmount: allocatedAmount,
      month: month,
      year: year,
      createdAt: widget.budget?.createdAt ?? DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      await widget.onSave(budget);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
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
                  widget.budget == null ? 'Create Budget' : 'Edit Budget',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Category',
                  controller: _categoryController,
                  hint: 'Groceries',
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Enter category' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Allocated amount',
                  controller: _allocatedController,
                  hint: '20000',
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
                  label: 'Month',
                  controller: _monthController,
                  hint: 'March',
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Enter month';
                    }
                    final isValid = _validMonths.any(
                      (month) => month.toLowerCase() == trimmed.toLowerCase(),
                    );
                    // A month name BudgetRepository can't recognize (typo,
                    // abbreviation) would otherwise save successfully but
                    // silently track ₹0 spent forever, with no error ever
                    // shown to the user.
                    return isValid
                        ? null
                        : 'Enter a full month name, e.g. March';
                  },
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Year',
                  controller: _yearController,
                  hint: DateTime.now().year.toString(),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final year = int.tryParse(value?.trim() ?? '');
                    if (year == null || year < 1900) {
                      return 'Enter a valid year';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Save budget'),
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
}
