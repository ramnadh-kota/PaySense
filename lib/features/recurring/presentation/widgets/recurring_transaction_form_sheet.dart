import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/wallet_account_resolver.dart';
import 'package:paysense/shared/widgets/wallet_selector_field.dart';

const List<String> _frequencies = <String>['Daily', 'Weekly', 'Monthly', 'Yearly'];

class RecurringTransactionFormSheet extends StatefulWidget {
  const RecurringTransactionFormSheet({
    super.key,
    this.item,
    required this.wallets,
    required this.onSave,
  });

  final RecurringTransaction? item;

  /// Non-archived wallets, plus the item's currently-associated wallet if it
  /// happens to be archived (so editing an old recurring transaction never
  /// silently loses its existing, still-valid selection).
  final List<Wallet> wallets;
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

  /// The real Wallet.id this item pays from/into — never a display label.
  /// Null means "no wallet resolved/selected yet"; the form refuses to save
  /// until the user picks one (see [_handleSave]). Used for both expense
  /// and income recurring transactions — the model requires an account
  /// regardless of transaction type, so there is no separate mechanism.
  String? _selectedWalletId;
  String _frequency = 'Monthly';
  late DateTime _startDate;
  DateTime? _endDate;
  String? _walletError;

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
      // Never guess: resolves to a wallet only when the existing accountId
      // already is one, or unambiguously identifies exactly one wallet by
      // name/type. Ambiguous or unmatched legacy data leaves this null.
      _selectedWalletId = resolveWalletIdForAccount(item.accountId, widget.wallets);
      _frequency = _frequencies.contains(item.frequency)
          ? item.frequency
          : _frequencies[2];
      _startDate = item.startDate;
      _endDate = item.endDate;
    } else {
      _startDate = DateTime.now();
      _selectedWalletId = widget.wallets.isEmpty ? null : widget.wallets.first.id;
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

    final walletId = _selectedWalletId;
    if (walletId == null || widget.wallets.every((w) => w.id != walletId)) {
      setState(() => _walletError = 'Please choose an account.');
      return;
    }
    setState(() => _walletError = null);

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
            // The real Wallet.id, never a display label.
            accountId: walletId,
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
            accountId: walletId,
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
                if (widget.wallets.isEmpty)
                  const NoWalletsMessage(
                    message: 'Add an account first to choose where this transaction goes.',
                  )
                else ...[
                  WalletSelectorField(
                    label: 'Account',
                    wallets: widget.wallets,
                    selectedWalletId: _selectedWalletId,
                    onChanged: (value) => setState(() {
                      _selectedWalletId = value;
                      _walletError = null;
                    }),
                  ),
                  if (_walletError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        _walletError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                ],
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
