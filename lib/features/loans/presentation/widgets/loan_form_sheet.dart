import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/features/loans/presentation/widgets/emi_calculator_widget.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/utils/wallet_account_resolver.dart';
import 'package:paysense/shared/widgets/wallet_selector_field.dart';

const List<String> _loanTypes = <String>[
  'Home',
  'Personal',
  'Car',
  'Education',
  'Credit Card',
  'Other',
];

class LoanFormSheet extends StatefulWidget {
  const LoanFormSheet({super.key, this.loan, required this.wallets, required this.onSave});

  final Loan? loan;

  /// Non-archived wallets, plus the loan's currently-associated wallet if it
  /// happens to be archived (so editing an old loan never silently loses
  /// its existing, still-valid selection).
  final List<Wallet> wallets;
  final Future<void> Function(Loan loan) onSave;

  @override
  State<LoanFormSheet> createState() => _LoanFormSheetState();
}

class _LoanFormSheetState extends State<LoanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _loanNameController = TextEditingController();
  final _lenderNameController = TextEditingController();
  final _principalController = TextEditingController();
  final _rateController = TextEditingController();
  final _tenureController = TextEditingController();
  final _manualEmiController = TextEditingController();

  String _loanType = _loanTypes.first;

  /// The real Wallet.id EMIs are paid from — never a display label. Null
  /// means "no wallet resolved/selected yet"; the form refuses to save
  /// until the user picks one (see [_handleSave]).
  String? _selectedWalletId;
  String? _walletError;
  bool _autoCalculate = true;
  late DateTime _startDate;
  late DateTime _nextDueDate;

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;
    if (loan != null) {
      _loanNameController.text = loan.loanName;
      _lenderNameController.text = loan.lenderName;
      _principalController.text = loan.principalAmount.toStringAsFixed(0);
      _rateController.text = loan.interestRate.toString();
      _tenureController.text = loan.tenureMonths.toString();
      _manualEmiController.text = loan.emiAmount.toStringAsFixed(0);
      _loanType = _loanTypes.contains(loan.loanType) ? loan.loanType : _loanTypes.last;
      // Never guess: resolves to a wallet only when the existing accountId
      // already is one, or unambiguously identifies exactly one wallet by
      // name/type. Ambiguous or unmatched legacy data leaves this null.
      _selectedWalletId = resolveWalletIdForAccount(loan.accountId, widget.wallets);
      _startDate = loan.startDate;
      _nextDueDate = loan.nextDueDate;
      _autoCalculate = false;
    } else {
      _startDate = DateTime.now();
      _nextDueDate = DateTime.now().add(const Duration(days: 30));
      _selectedWalletId = widget.wallets.isEmpty ? null : widget.wallets.first.id;
    }

    for (final controller in [
      _principalController,
      _rateController,
      _tenureController,
    ]) {
      controller.addListener(_onCalculatorInputsChanged);
    }
  }

  void _onCalculatorInputsChanged() {
    if (_autoCalculate) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _loanNameController.dispose();
    _lenderNameController.dispose();
    _principalController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    _manualEmiController.dispose();
    super.dispose();
  }

  double get _principal => double.tryParse(_principalController.text.trim()) ?? 0;
  double get _rate => double.tryParse(_rateController.text.trim()) ?? 0;
  int get _tenure => int.tryParse(_tenureController.text.trim()) ?? 0;

  EmiCalculation get _currentCalculation {
    if (_autoCalculate) {
      return Loan.calculateEmi(
        principal: _principal,
        annualRatePercent: _rate,
        tenureMonths: _tenure,
      );
    }
    final manualEmi = double.tryParse(_manualEmiController.text.trim()) ?? 0;
    final totalPayable = manualEmi * _tenure;
    final totalInterest = (totalPayable - _principal).clamp(0.0, double.infinity);
    return EmiCalculation(
      emiAmount: manualEmi,
      totalInterest: totalInterest,
      totalPayable: totalPayable,
    );
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final initial = isStartDate ? _startDate : _nextDueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 40)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _nextDueDate = picked;
        }
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final calculation = _currentCalculation;
    if (calculation.emiAmount <= 0) {
      return;
    }

    final walletId = _selectedWalletId;
    if (walletId == null || widget.wallets.every((w) => w.id != walletId)) {
      setState(() => _walletError = 'Please choose a payment account.');
      return;
    }
    setState(() => _walletError = null);

    final id = widget.loan?.id ?? const Uuid().v4();
    final createdAt = widget.loan?.createdAt ?? DateTime.now();

    final loan = widget.loan == null
        ? Loan.create(
            id: id,
            loanName: _loanNameController.text.trim(),
            lenderName: _lenderNameController.text.trim(),
            loanType: _loanType,
            principalAmount: _principal,
            interestRate: _rate,
            tenureMonths: _tenure,
            emiAmount: calculation.emiAmount,
            totalInterest: calculation.totalInterest,
            // The real Wallet.id, never a display label.
            accountId: walletId,
            startDate: _startDate,
            nextDueDate: _nextDueDate,
            createdAt: createdAt,
          )
        : widget.loan!.copyWith(
            loanName: _loanNameController.text.trim(),
            lenderName: _lenderNameController.text.trim(),
            loanType: _loanType,
            principalAmount: _principal,
            interestRate: _rate,
            tenureMonths: _tenure,
            emiAmount: calculation.emiAmount,
            totalInterest: calculation.totalInterest,
            accountId: walletId,
            startDate: _startDate,
            nextDueDate: _nextDueDate,
            updatedAt: DateTime.now(),
          );

    await widget.onSave(loan);
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
                  widget.loan == null ? 'Create Loan' : 'Edit Loan',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Loan name',
                  controller: _loanNameController,
                  hint: 'Home Loan',
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Enter a loan name' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Lender name',
                  controller: _lenderNameController,
                  hint: 'HDFC Bank',
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Enter a lender name' : null,
                ),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: 'Loan type',
                  value: _loanType,
                  items: _loanTypes,
                  onChanged: (value) => setState(() => _loanType = value!),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Principal amount',
                  controller: _principalController,
                  hint: '500000',
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
                  label: 'Interest rate (% per year)',
                  controller: _rateController,
                  hint: '9.5',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final rate = double.tryParse(value?.trim() ?? '');
                    if (rate == null || rate < 0) {
                      return 'Enter a valid rate';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Tenure (months)',
                  controller: _tenureController,
                  hint: '60',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final months = int.tryParse(value?.trim() ?? '');
                    if (months == null || months <= 0) {
                      return 'Enter a valid tenure';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (widget.wallets.isEmpty)
                  const NoWalletsMessage(
                    message: 'Add an account first to choose where EMIs are paid from.',
                  )
                else ...[
                  WalletSelectorField(
                    label: 'Payment account',
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
                const SizedBox(height: 12),
                _buildDateField(
                  label: 'Start date',
                  date: _startDate,
                  onTap: () => _pickDate(isStartDate: true),
                ),
                const SizedBox(height: 12),
                _buildDateField(
                  label: 'Next due date',
                  date: _nextDueDate,
                  onTap: () => _pickDate(isStartDate: false),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _autoCalculate,
                  onChanged: (value) => setState(() => _autoCalculate = value),
                  activeThumbColor: AppColors.primary,
                  title: Text(
                    'Auto-calculate EMI',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Turn off if you already know your EMI amount',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                if (!_autoCalculate) ...[
                  const SizedBox(height: 8),
                  _buildTextField(
                    label: 'EMI amount',
                    controller: _manualEmiController,
                    hint: '10000',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      final emi = double.tryParse(value?.trim() ?? '');
                      if (emi == null || emi <= 0) {
                        return 'Enter a valid EMI amount';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                EmiCalculatorWidget(calculation: _currentCalculation),
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
                  child: const Text('Save loan'),
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
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
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
    required DateTime date,
    required VoidCallback onTap,
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
                  '${date.day}/${date.month}/${date.year}',
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
