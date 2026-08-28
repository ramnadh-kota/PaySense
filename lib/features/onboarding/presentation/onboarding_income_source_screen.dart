import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/onboarding_models.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';

/// CONSUMER MONETIZATION FOUNDATION (PHASE 1, Screen 3) — "How do you
/// usually earn?" Single-select, recorded for presentation only. This
/// NEVER creates income data — real income only ever comes from
/// [UserProfile.monthlyIncome] or real transaction history.
class OnboardingIncomeSourceScreen extends ConsumerStatefulWidget {
  const OnboardingIncomeSourceScreen({super.key});

  @override
  ConsumerState<OnboardingIncomeSourceScreen> createState() => _OnboardingIncomeSourceScreenState();
}

class _OnboardingIncomeSourceScreenState extends ConsumerState<OnboardingIncomeSourceScreen> {
  IncomeSourceType? _selected;

  Future<void> _continue() async {
    final selected = _selected;
    if (selected == null) return;
    await AppSettingsRepository.instance.setOnboardingIncomeSource(selected.name);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.onboardingBuildPicture, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How do you usually earn?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "This just helps us tailor what we show you — you'll add your real income separately.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView.separated(
                  itemCount: IncomeSourceType.values.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final source = IncomeSourceType.values[index];
                    final isSelected = _selected == source;
                    return InkWell(
                      onTap: () => setState(() => _selected = source),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.10) : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.divider,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                source.label,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected == null ? null : _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
