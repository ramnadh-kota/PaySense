import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/features/goals/presentation/goal_presets.dart';
import 'package:paysense/shared/models/goal.dart';

class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({super.key, this.goal, required this.onSave});

  final Goal? goal;
  final Future<void> Function(Goal goal) onSave;

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _currentController = TextEditingController();

  late GoalPreset _selectedPreset;
  late DateTime _targetDate;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _selectedPreset = goal == null
        ? goalPresets.first
        : goalPresets.firstWhere(
            (preset) => preset.iconKey == goal.icon,
            orElse: () => goalPresets.first,
          );
    _targetDate = goal?.targetDate ?? DateTime.now().add(const Duration(days: 30));

    if (goal != null) {
      _titleController.text = goal.title;
      _targetController.text = goal.targetAmount.toStringAsFixed(0);
      _currentController.text = goal.currentAmount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final targetAmount = double.tryParse(_targetController.text.trim()) ?? 0.0;
    final currentAmount = double.tryParse(_currentController.text.trim()) ?? 0.0;
    if (targetAmount <= 0) {
      return;
    }

    final id = widget.goal?.id ?? const Uuid().v4();
    final createdAt = widget.goal?.createdAt ?? DateTime.now();

    final goal = Goal.create(
      id: id,
      title: _titleController.text.trim(),
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      targetDate: _targetDate,
      category: _selectedPreset.category,
      icon: _selectedPreset.iconKey,
      color: _selectedPreset.color.toARGB32(),
      createdAt: createdAt,
    );

    await widget.onSave(goal);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
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
                  widget.goal == null ? 'Create Goal' : 'Edit Goal',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Category',
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
                    for (final preset in goalPresets)
                      ChoiceChip(
                        label: Text(preset.category),
                        avatar: Icon(preset.icon, size: 18, color: preset.color),
                        selected: _selectedPreset.category == preset.category,
                        onSelected: (_) =>
                            setState(() => _selectedPreset = preset),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Goal title',
                  controller: _titleController,
                  hint: 'New laptop',
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Enter a title' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Target amount',
                  controller: _targetController,
                  hint: '50000',
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
                  label: 'Current savings',
                  controller: _currentController,
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final amount = double.tryParse(value.trim());
                    if (amount == null || amount < 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickTargetDate,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
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
                              'Target date',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_targetDate.day}/${_targetDate.month}/${_targetDate.year}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textPrimary),
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
                  child: const Text('Save goal'),
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
