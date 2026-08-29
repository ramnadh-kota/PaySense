import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/onboarding_models.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/user_profile_repository.dart';
import 'package:paysense/shared/services/analytics_service.dart';

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const List<_OnboardingPageData> _pages = <_OnboardingPageData>[
  _OnboardingPageData(
    icon: Icons.account_balance_wallet_rounded,
    title: 'Mindful Money in a Digital World',
    description:
        'PaySense helps you spend with awareness and intention, restoring the natural emotional friction that frictionless digital payments removed.',
  ),
  _OnboardingPageData(
    icon: Icons.psychology_rounded,
    title: 'Think Before You Pay & Decision Coach',
    description:
        'Pause before making purchases. Decision Coach shows real-time impact on your debts, goals, and safe-to-spend headroom.',
  ),
  _OnboardingPageData(
    icon: Icons.insights_rounded,
    title: 'Pain of Paying & Safe-to-Spend',
    description:
        'Know your exact safe-to-spend limit after upcoming bills, subscriptions, and EMIs, and feel clear post-purchase awareness without guilt.',
  ),
  _OnboardingPageData(
    icon: Icons.sms_rounded,
    title: 'Local SMS Detection & Total Privacy',
    description:
        'Optionally detect bank and UPI SMS alerts locally on your device. Your data stays 100% private on your phone and is never sold or shared.',
  ),
  _OnboardingPageData(
    icon: Icons.shield_outlined,
    title: 'Your Independent Money Companion',
    description:
        'PaySense is your independent personal finance guide. PaySense is not a bank and never directly moves or accesses your bank accounts.',
  ),
];

/// A four-page introduction to PaySense shown on first launch, before the
/// user sets up their profile.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_isLastPage) {
      _finishOnboarding();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  /// CONSUMER MONETIZATION FOUNDATION (PHASE 13) — "resume intelligently":
  /// a user who already progressed past this intro carousel in an earlier
  /// session (e.g. they saved a profile, then closed the app) is routed
  /// straight to whichever onboarding step comes next, not back to the
  /// very start.
  Future<void> _finishOnboarding() async {
    final settings = AppSettingsRepository.instance;
    final profile = await UserProfileRepository.instance.getProfile();
    final stage = OnboardingFlow.resumeStage(
      profileExists: profile != null,
      goalsSet: settings.onboardingGoalsSet(),
      incomeSourceSet: settings.onboardingIncomeSourceSet(),
      buildPictureAcknowledged: settings.onboardingBuildPictureAcknowledged(),
      snapshotViewed: settings.onboardingSnapshotViewed(),
      ahaMomentViewed: settings.onboardingAhaMomentViewed(),
    );

    if (!mounted) return;

    final route = switch (stage) {
      OnboardingStage.profile => AppRoutes.profileSetup,
      OnboardingStage.goals => AppRoutes.onboardingGoals,
      OnboardingStage.incomeSource => AppRoutes.onboardingIncomeSource,
      OnboardingStage.buildPicture => AppRoutes.onboardingBuildPicture,
      OnboardingStage.snapshot => AppRoutes.financialSnapshot,
      OnboardingStage.ahaMoment || OnboardingStage.completed => AppRoutes.ahaMoment,
    };
    AnalyticsService.instance.log(AnalyticsEvent.onboardingStarted, metadata: {'step': 'intro'});
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Visibility(
                  visible: !_isLastPage,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      'Skip',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(
                            page.icon,
                            size: 72,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _goToNextPage,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(_isLastPage ? 'Get Started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
