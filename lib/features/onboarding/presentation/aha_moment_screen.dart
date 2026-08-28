import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/providers/app_settings_provider.dart';
import 'package:paysense/shared/providers/financial_action_provider.dart';
import 'package:paysense/shared/providers/financial_insight_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/services/analytics_service.dart';
import 'package:paysense/shared/utils/aha_moment_builder.dart';
import 'package:paysense/shared/widgets/app_card.dart';

/// CONSUMER MONETIZATION FOUNDATION (PHASE 3) — "Here's what PaySense
/// found." The true end of onboarding: this is the ONLY place
/// `completeFirstLaunch()` is called now (moved here from
/// ProfileSetupScreen so it fires after the user has actually seen value,
/// not before).
class AhaMomentScreen extends ConsumerStatefulWidget {
  const AhaMomentScreen({super.key});

  @override
  ConsumerState<AhaMomentScreen> createState() => _AhaMomentScreenState();
}

class _AhaMomentScreenState extends ConsumerState<AhaMomentScreen> {
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.log(AnalyticsEvent.ahaMomentViewed);
  }

  Future<void> _getStarted() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await AppSettingsRepository.instance.setOnboardingAhaMomentViewed();
    await ref.read(isFirstLaunchProvider.notifier).completeFirstLaunch();
    AnalyticsService.instance.log(AnalyticsEvent.onboardingCompleted);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.navigation, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final actionPlan = ref.watch(financialActionPlanProvider);
    final insights = ref.watch(financialInsightsProvider);
    final aha = AhaMomentBuilder.build(actions: actionPlan.actions, insights: insights.insights);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                children: [
                  Text(
                    "Here's what PaySense found.",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!aha.hasSufficientData)
                    AppCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 40, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'Keep adding your income, expenses, and goals — PaySense will start '
                            'surfacing personalized findings here.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    if (aha.riskTitle != null) ...[
                      _AhaCard(
                        emoji: '🔴',
                        label: 'Biggest Financial Risk',
                        title: aha.riskTitle!,
                        explanation: aha.riskExplanation ?? '',
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (aha.opportunityTitle != null) ...[
                      _AhaCard(
                        emoji: '🟡',
                        label: 'Biggest Opportunity',
                        title: aha.opportunityTitle!,
                        explanation: aha.opportunityExplanation ?? '',
                        color: AppColors.warning,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (aha.doingWellTitle != null) ...[
                      _AhaCard(
                        emoji: '🟢',
                        label: "What You're Doing Well",
                        title: aha.doingWellTitle!,
                        explanation: aha.doingWellExplanation ?? '',
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (aha.nextBestMoveTitle != null) ...[
                      Text(
                        'Your next best move',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.lightTeal, borderRadius: BorderRadius.circular(14)),
                              child: Icon(Icons.flag_circle_rounded, color: AppColors.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    aha.nextBestMoveTitle!,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    aha.nextBestMoveAction ?? '',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _finishing ? null : _getStarted,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _finishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Get Started'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AhaCard extends StatelessWidget {
  const _AhaCard({
    required this.emoji,
    required this.label,
    required this.title,
    required this.explanation,
    required this.color,
  });

  final String emoji;
  final String label;
  final String title;
  final String explanation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
