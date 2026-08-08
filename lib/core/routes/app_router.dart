import 'package:flutter/material.dart';
import '../../features/ai/ai_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/budget/presentation/screens/budget_screen.dart';
import '../../features/goals/presentation/screens/goals_screen.dart';
import '../../features/navigation/navigation_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/recurring/presentation/screens/recurring_screen.dart';
import '../../features/profile/presentation/profile_setup_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/wallet/wallet_screen.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case AppRoutes.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case AppRoutes.profileSetup:
        return MaterialPageRoute(builder: (_) => const ProfileSetupScreen());
      case AppRoutes.navigation:
        return MaterialPageRoute(builder: (_) => const NavigationScreen());
      case AppRoutes.wallet:
        return MaterialPageRoute(builder: (_) => const WalletScreen());
      case AppRoutes.analytics:
        return MaterialPageRoute(builder: (_) => const AnalyticsScreen());
      case AppRoutes.budget:
        return MaterialPageRoute(builder: (_) => const BudgetScreen());
      case AppRoutes.goals:
        return MaterialPageRoute(builder: (_) => const GoalsScreen());
      case AppRoutes.recurring:
        return MaterialPageRoute(builder: (_) => const RecurringScreen());
      case AppRoutes.aiCoach:
        return MaterialPageRoute(builder: (_) => const AiScreen());
      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}
