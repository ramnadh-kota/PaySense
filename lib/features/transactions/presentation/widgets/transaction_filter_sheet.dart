import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/providers/transaction_filter_provider.dart';
import 'package:paysense/shared/utils/transaction_filters.dart';

/// Staged filter editor: changes only take effect on "Apply filters" (or are
/// discarded immediately by "Clear all"), so the transaction list doesn't
/// re-filter on every chip tap while the sheet is open.
class TransactionFilterSheet extends ConsumerStatefulWidget {
  const TransactionFilterSheet({super.key});

  @override
  ConsumerState<TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends ConsumerState<TransactionFilterSheet> {
  late TransactionTypeFilter _type;
  late String? _category;
  late DateRangeFilter _dateRange;
  late DateTime? _customStart;
  late DateTime? _customEnd;
  late String? _account;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    final current = ref.read(transactionFilterProvider);
    _type = current.type;
    _category = current.category;
    _dateRange = current.dateRange;
    _customStart = current.customStart;
    _customEnd = current.customEnd;
    _account = current.account;
    _minController = TextEditingController(
      text: current.minAmount == null ? '' : current.minAmount!.toStringAsFixed(0),
    );
    _maxController = TextEditingController(
      text: current.maxAmount == null ? '' : current.maxAmount!.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _dateRange = DateRangeFilter.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  void _applyFilters() {
    final notifier = ref.read(transactionFilterProvider.notifier);
    notifier.setType(_type);
    notifier.setCategory(_category);
    notifier.setAccount(_account);
    if (_dateRange == DateRangeFilter.custom &&
        _customStart != null &&
        _customEnd != null) {
      notifier.setCustomDateRange(_customStart!, _customEnd!);
    } else {
      notifier.setDateRange(_dateRange);
    }
    notifier.setAmountRange(
      min: double.tryParse(_minController.text.trim()),
      max: double.tryParse(_maxController.text.trim()),
    );
    Navigator.of(context).pop();
  }

  void _clearAll() {
    ref.read(transactionFilterProvider.notifier).clearAll();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(availableTransactionCategoriesProvider);
    final accounts = ref.watch(availableTransactionAccountsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Text(
                      'Filters',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  children: [
                    _SectionLabel('Transaction Type'),
                    Wrap(
                      spacing: 8,
                      children: [
                        _choiceChip('All', _type == TransactionTypeFilter.all,
                            () => setState(() => _type = TransactionTypeFilter.all)),
                        _choiceChip(
                          'Income',
                          _type == TransactionTypeFilter.income,
                          () => setState(() => _type = TransactionTypeFilter.income),
                        ),
                        _choiceChip(
                          'Expense',
                          _type == TransactionTypeFilter.expense,
                          () => setState(() => _type = TransactionTypeFilter.expense),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Category'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _choiceChip('All', _category == null,
                            () => setState(() => _category = null)),
                        for (final category in categories)
                          _choiceChip(
                            category,
                            _category == category,
                            () => setState(() => _category = category),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Date'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _choiceChip('All', _dateRange == DateRangeFilter.all,
                            () => setState(() => _dateRange = DateRangeFilter.all)),
                        _choiceChip(
                          'Today',
                          _dateRange == DateRangeFilter.today,
                          () => setState(() => _dateRange = DateRangeFilter.today),
                        ),
                        _choiceChip(
                          'This week',
                          _dateRange == DateRangeFilter.thisWeek,
                          () => setState(() => _dateRange = DateRangeFilter.thisWeek),
                        ),
                        _choiceChip(
                          'This month',
                          _dateRange == DateRangeFilter.thisMonth,
                          () => setState(() => _dateRange = DateRangeFilter.thisMonth),
                        ),
                        _choiceChip(
                          'Last month',
                          _dateRange == DateRangeFilter.lastMonth,
                          () => setState(() => _dateRange = DateRangeFilter.lastMonth),
                        ),
                        _choiceChip(
                          _dateRange == DateRangeFilter.custom &&
                                  _customStart != null &&
                                  _customEnd != null
                              ? '${DateFormat('d MMM').format(_customStart!)} - ${DateFormat('d MMM').format(_customEnd!)}'
                              : 'Custom range',
                          _dateRange == DateRangeFilter.custom,
                          _pickCustomRange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Account'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _choiceChip('All', _account == null,
                            () => setState(() => _account = null)),
                        for (final account in accounts)
                          _choiceChip(
                            account,
                            _account == account,
                            () => setState(() => _account = account),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Amount'),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _amountFieldDecoration('Min amount'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _amountFieldDecoration('Max amount'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearAll,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.divider),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Clear all'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _applyFilters,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Apply filters'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.lightTeal,
      backgroundColor: AppColors.background,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.divider,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  InputDecoration _amountFieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
