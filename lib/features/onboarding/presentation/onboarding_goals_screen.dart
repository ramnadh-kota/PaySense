import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/onboarding_models.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/services/analytics_service.dart';

/// CONSUMER MONETIZATION FOUNDATION (PHASE 1, Screen 2) — "What matters
/// most to you?" Multi-select, purely for presentation/prioritization
/// (PHASE 11) — never feeds a financial calculation.
class OnboardingGoalsScreen extends ConsumerStatefulWidget {
  const OnboardingGoalsScreen({super.key});

  @override
  ConsumerState<OnboardingGoalsScreen> createState() => _OnboardingGoalsScreenState();
}

class _OnboardingGoalsScreenState extends ConsumerState<OnboardingGoalsScreen> {
  final Set<FinancialGoalPreference> _selected = {};

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.log(AnalyticsEvent.onboardingStarted, metadata: {'step': 'goals'});
  }

  Future<void> _continue() async {
    await AppSettingsRepository.instance.setOnboardingGoals(_selected.map((g) => g.name).toList());
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.onboardingIncomeSource, (route) => false);
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
                'What matters most to you?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick as many as you like — we\'ll prioritize what you see first.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView.separated(
                  itemCount: FinancialGoalPreference.values.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final goal = FinancialGoalPreference.values[index];
                    final isSelected = _selected.contains(goal);
                    return _GoalTile(
                      label: goal.label,
                      selected: isSelected,
                      onTap: () => setState(() {
                        if (isSelected) {
                          _selected.remove(goal);
                        } else {
                          _selected.add(goal);
                        }
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected.isEmpty ? null : _continue,
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

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.10) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
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
  }
}
