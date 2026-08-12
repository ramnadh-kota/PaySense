import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/providers/app_settings_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';

const List<String> _genders = <String>[
  'Male',
  'Female',
  'Other',
  'Prefer not to say',
];

const List<String> _currencies = <String>['INR', 'USD', 'EUR', 'GBP', 'AED'];

/// Collects the user's profile at the end of onboarding. Only [fullName] is
/// required; every other field is optional.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _occupationController = TextEditingController();
  final _monthlyIncomeController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');

  DateTime? _dateOfBirth;
  String _gender = '';
  String _currency = _currencies.first;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // If an account (or a prior partial profile) already created a
    // UserProfile record, pre-fill from it instead of starting blank.
    final existingProfile = ref.read(userProfileProvider).valueOrNull;
    if (existingProfile != null) {
      _fullNameController.text = existingProfile.fullName;
      _emailController.text = existingProfile.email;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _occupationController.dispose();
    _monthlyIncomeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _handleGetStarted() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final profile = UserProfile(
      id: 'profile',
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      dateOfBirth: _dateOfBirth,
      gender: _gender,
      occupation: _occupationController.text.trim(),
      monthlyIncome: double.tryParse(_monthlyIncomeController.text.trim()) ?? 0.0,
      currency: _currency,
      country: _countryController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(userProfileProvider.notifier).saveProfile(profile);
    await ref.read(isFirstLaunchProvider.notifier).completeFirstLaunch();

    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.navigation, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              Text(
                'Set up your profile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Only your name is required — add more to personalize your experience.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                label: 'Full name',
                controller: _fullNameController,
                hint: 'Jane Doe',
                icon: Icons.person_outline_rounded,
                validator: (value) => value?.trim().isEmpty == true
                    ? 'Please enter your full name'
                    : null,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Email (optional)',
                controller: _emailController,
                hint: 'jane@example.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return null;
                  }
                  return trimmed.contains('@') && trimmed.contains('.')
                      ? null
                      : 'Enter a valid email address';
                },
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Phone (optional)',
                controller: _phoneController,
                hint: '9876543210',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildDateField(),
              const SizedBox(height: 12),
              _buildDropdown(
                label: 'Gender (optional)',
                value: _gender.isEmpty ? null : _gender,
                hint: 'Select gender',
                items: _genders,
                onChanged: (value) => setState(() => _gender = value ?? ''),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Occupation (optional)',
                controller: _occupationController,
                hint: 'Software Engineer',
                icon: Icons.work_outline_rounded,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Monthly income (optional)',
                controller: _monthlyIncomeController,
                hint: '50000',
                icon: Icons.account_balance_wallet_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return null;
                  }
                  return double.tryParse(trimmed) == null
                      ? 'Enter a valid amount'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              _buildDropdown(
                label: 'Currency (optional)',
                value: _currency,
                hint: 'Select currency',
                items: _currencies,
                onChanged: (value) =>
                    setState(() => _currency = value ?? _currencies.first),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Country (optional)',
                controller: _countryController,
                hint: 'India',
                icon: Icons.public_rounded,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _handleGetStarted,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Get Started'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: AppColors.primary) : null,
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
    required String? value,
    required String hint,
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
        hint: Text(hint),
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
      onTap: _pickDateOfBirth,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date of birth (optional)',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateOfBirth == null
                        ? 'Select date'
                        : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _dateOfBirth == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
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
}
