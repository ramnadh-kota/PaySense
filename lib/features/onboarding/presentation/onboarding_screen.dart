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
    title: 'Welcome to PaySense',
    description:
        'Your AI-powered personal finance companion. Let\'s get your money organized in minutes.',
  ),
  _OnboardingPageData(
    icon: Icons.receipt_long_rounded,
    title: 'Track every rupee',
    description:
        'Log income and expenses in seconds and see exactly where your money goes.',
  ),
  _OnboardingPageData(
    icon: Icons.savings_rounded,
    title: 'Budgets, goals & reminders',
    description:
        'Set category budgets and savings goals, and automate recurring bills with smart reminders.',
  ),
  _OnboardingPageData(
    icon: Icons.auto_awesome_rounded,
    title: 'Meet your AI money coach',
    description:
        'Ask questions, get personalized insights, and make smarter financial decisions every day.',
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
