import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0;
  final _fullNameController = TextEditingController();
  final _monthlyIncomeController = TextEditingController();
  final _monthlyEmiController = TextEditingController();
  final _savingsGoalController = TextEditingController();
  final _walletNameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _walletTypeController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  DateTime? _targetDate;

  final List<String> _stepTitles = const [
    'Personal Info',
    'Income',
    'EMI',
    'Goals',
    'First Wallet',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _monthlyIncomeController.dispose();
    _monthlyEmiController.dispose();
    _savingsGoalController.dispose();
    _walletNameController.dispose();
    _bankNameController.dispose();
    _walletTypeController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() {
        _targetDate = picked;
      });
    }
  }

  void _goToNextStep() {
    if (_currentStep == 0 && !_validateCurrentStep()) {
      return;
    }

    if (_currentStep == 1 && !_validateCurrentStep()) {
      return;
    }

    if (_currentStep == 2 && !_validateCurrentStep()) {
      return;
    }

    if (_currentStep == 3 && !_validateCurrentStep()) {
      return;
    }

    if (_currentStep == 4 && !_validateCurrentStep()) {
      return;
    }

    if (_currentStep < _stepTitles.length - 1) {
      setState(() {
        _currentStep += 1;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    final currentForm = _formKey.currentState;
    if (currentForm == null) {
      return false;
    }

    if (!currentForm.validate()) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStep + 1) / _stepTitles.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to PaySense',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set up your financial profile in a few taps.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Step ${_currentStep + 1} of ${_stepTitles.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStepContent(
                    context,
                    title: _stepTitles[0],
                    child: _buildTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      validator: 'Please enter your full name',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  _buildStepContent(
                    context,
                    title: _stepTitles[1],
                    child: _buildTextField(
                      controller: _monthlyIncomeController,
                      label: 'Monthly Income',
                      keyboardType: TextInputType.number,
                      validator: 'Please enter your monthly income',
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  _buildStepContent(
                    context,
                    title: _stepTitles[2],
                    child: _buildTextField(
                      controller: _monthlyEmiController,
                      label: 'Monthly EMI',
                      keyboardType: TextInputType.number,
                      validator: 'Please enter your monthly EMI',
                      icon: Icons.credit_card_rounded,
                    ),
                  ),
                  _buildStepContent(
                    context,
                    title: _stepTitles[3],
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _savingsGoalController,
                          label: 'Savings Goal',
                          keyboardType: TextInputType.number,
                          validator: 'Please enter your savings goal',
                          icon: Icons.savings_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildDateSelector(context),
                      ],
                    ),
                  ),
                  _buildStepContent(
                    context,
                    title: _stepTitles[4],
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _walletNameController,
                          label: 'Wallet Name',
                          validator: 'Please enter a wallet name',
                          icon: Icons.wallet_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _bankNameController,
                          label: 'Bank Name',
                          validator: 'Please enter a bank name',
                          icon: Icons.account_balance_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _walletTypeController,
                          label: 'Wallet Type',
                          validator: 'Please enter a wallet type',
                          icon: Icons.category_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _openingBalanceController,
                          label: 'Opening Balance',
                          keyboardType: TextInputType.number,
                          validator: 'Please enter an opening balance',
                          icon: Icons.attach_money_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _goToPreviousStep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _goToNextStep,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentStep == _stepTitles.length - 1
                            ? 'Finish'
                            : 'Continue',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us a bit more so we can tailor your experience.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String validator,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return validator;
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: AppColors.primary) : null,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    return InkWell(
      onTap: () => _pickDate(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _targetDate == null
                    ? 'Select target date'
                    : '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _targetDate == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
