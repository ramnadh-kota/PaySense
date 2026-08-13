import 'package:flutter/material.dart';
import '../../features/ai/ai_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/bills/presentation/screens/bills_screen.dart';
import '../../features/budget/presentation/screens/budget_screen.dart';
import '../../features/cash_flow/presentation/cash_flow_screen.dart';
import '../../features/financial_health/presentation/financial_health_screen.dart';
import '../../features/goals/presentation/screens/goals_screen.dart';
import '../../features/loans/presentation/screens/loans_screen.dart';
import '../../features/monthly_review/presentation/monthly_review_screen.dart';
import '../../features/navigation/navigation_screen.dart';
import '../../features/notifications/presentation/notification_center_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/recurring/presentation/screens/recurring_screen.dart';
import '../../features/profile/presentation/profile_setup_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/safe_to_spend/presentation/safe_to_spend_screen.dart';
import '../../features/settings/presentation/app_lock_pin_setup_screen.dart';
import '../../features/settings/presentation/change_password_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../../features/wallet/wallet_screen.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case AppRoutes.signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case AppRoutes.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case AppRoutes.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case AppRoutes.profileSetup:
        return MaterialPageRoute(builder: (_) => const ProfileSetupScreen());
      case AppRoutes.navigation:
        return MaterialPageRoute(builder: (_) => const NavigationScreen());
      case AppRoutes.wallet:
        return MaterialPageRoute(builder: (_) => const WalletScreen());
      case AppRoutes.transactions:
        return MaterialPageRoute(builder: (_) => const TransactionsScreen());
      case AppRoutes.financialHealth:
        return MaterialPageRoute(builder: (_) => const FinancialHealthScreen());
      case AppRoutes.analytics:
        return MaterialPageRoute(builder: (_) => const AnalyticsScreen());
      case AppRoutes.budget:
        return MaterialPageRoute(builder: (_) => const BudgetScreen());
      case AppRoutes.goals:
        return MaterialPageRoute(builder: (_) => const GoalsScreen());
      case AppRoutes.recurring:
        return MaterialPageRoute(builder: (_) => const RecurringScreen());
      case AppRoutes.bills:
        return MaterialPageRoute(builder: (_) => const BillsScreen());
      case AppRoutes.loans:
        return MaterialPageRoute(builder: (_) => const LoansScreen());
      case AppRoutes.aiCoach:
        return MaterialPageRoute(builder: (_) => const AiScreen());
      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case AppRoutes.changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());
      case AppRoutes.appLockPinSetup:
        return MaterialPageRoute(builder: (_) => const AppLockPinSetupScreen());
      case AppRoutes.notifications:
        return MaterialPageRoute(builder: (_) => const NotificationCenterScreen());
      case AppRoutes.monthlyReview:
        return MaterialPageRoute(builder: (_) => const MonthlyReviewScreen());
      case AppRoutes.safeToSpend:
        return MaterialPageRoute(builder: (_) => const SafeToSpendScreen());
      case AppRoutes.cashFlow:
        return MaterialPageRoute(builder: (_) => const CashFlowScreen());
      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}
