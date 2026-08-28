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
import '../../features/financial_planning/presentation/financial_planning_screen.dart';
import '../../features/goals/presentation/screens/goals_screen.dart';
import '../../features/loans/presentation/screens/loans_screen.dart';
import '../../features/monthly_review/presentation/monthly_review_screen.dart';
import '../../features/navigation/navigation_screen.dart';
import '../../features/notifications/presentation/notification_center_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/recurring/presentation/screens/recurring_screen.dart';
import '../../features/profile/presentation/profile_setup_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/tax/presentation/tax_planner_screen.dart';
import '../../features/affordability/presentation/affordability_screen.dart';
import '../../features/financial_trends/presentation/financial_health_trends_screen.dart';
import '../../features/financial_timeline/presentation/financial_timeline_screen.dart';
import '../../features/compare_periods/presentation/financial_compare_screen.dart';
import '../../features/onboarding/presentation/onboarding_goals_screen.dart';
import '../../features/onboarding/presentation/onboarding_income_source_screen.dart';
import '../../features/onboarding/presentation/onboarding_build_picture_screen.dart';
import '../../features/onboarding/presentation/financial_snapshot_screen.dart';
import '../../features/onboarding/presentation/aha_moment_screen.dart';
import '../../features/premium/presentation/paywall_screen.dart';
import '../../shared/services/analytics_service.dart';
import '../../features/reports/presentation/financial_report_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/safe_to_spend/presentation/safe_to_spend_screen.dart';
import '../../features/settings/presentation/app_lock_pin_setup_screen.dart';
import '../../features/settings/presentation/change_password_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/sms/presentation/sms_review_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/subscriptions/presentation/subscriptions_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../../features/transactions/presentation/csv_import_screen.dart';
import '../../features/account_aggregator/presentation/bank_connect_screen.dart';
import '../../features/account_aggregator/presentation/connected_accounts_screen.dart';
import '../../features/search/presentation/feature_search_screen.dart';
import '../../features/recurring_money/presentation/recurring_money_screen.dart';
import '../../features/settings/presentation/data_export_screen.dart';
import '../../features/financial_safety/presentation/financial_alerts_screen.dart';
import '../../features/settings/presentation/account_deletion_screen.dart';
import '../../features/wallet/wallet_screen.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    _logRouteAnalytics(settings.name);
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
      case AppRoutes.dashboard:
        return MaterialPageRoute(builder: (_) => const NavigationScreen());
      case AppRoutes.wallet:
        return MaterialPageRoute(builder: (_) => const WalletScreen());
      case AppRoutes.transactions:
        return MaterialPageRoute(builder: (_) => const TransactionsScreen());
      case AppRoutes.csvImport:
        return MaterialPageRoute(builder: (_) => const CsvImportScreen());
      case AppRoutes.bankConnect:
        return MaterialPageRoute(builder: (_) => const BankConnectScreen());
      case AppRoutes.connectedAccounts:
        return MaterialPageRoute(builder: (_) => const ConnectedAccountsScreen());
      case AppRoutes.featureSearch:
        return MaterialPageRoute(builder: (_) => const FeatureSearchScreen());
      case AppRoutes.recurringMoney:
        return MaterialPageRoute(builder: (_) => const RecurringMoneyScreen());
      case AppRoutes.dataExport:
        return MaterialPageRoute(builder: (_) => const DataExportScreen());
      case AppRoutes.financialAlerts:
        return MaterialPageRoute(builder: (_) => const FinancialAlertsScreen());
      case AppRoutes.accountDeletion:
        return MaterialPageRoute(builder: (_) => const AccountDeletionScreen());
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
      case AppRoutes.subscriptions:
        return MaterialPageRoute(builder: (_) => const SubscriptionsScreen());
      case AppRoutes.smsReview:
        return MaterialPageRoute(builder: (_) => const SmsReviewScreen());
      case AppRoutes.reports:
        return MaterialPageRoute(builder: (_) => const ReportsScreen());
      case AppRoutes.financialReport:
        return MaterialPageRoute(builder: (_) => const FinancialReportScreen());
      case AppRoutes.financialPlanning:
        return MaterialPageRoute(builder: (_) => const FinancialPlanningScreen());
      case AppRoutes.taxPlanner:
        return MaterialPageRoute(builder: (_) => const TaxPlannerScreen());
      case AppRoutes.affordability:
        return MaterialPageRoute(builder: (_) => const AffordabilityScreen());
      case AppRoutes.financialHealthTrends:
        return MaterialPageRoute(builder: (_) => const FinancialHealthTrendsScreen());
      case AppRoutes.financialTimeline:
        return MaterialPageRoute(builder: (_) => const FinancialTimelineScreen());
      case AppRoutes.financialCompare:
        return MaterialPageRoute(builder: (_) => const FinancialCompareScreen());
      case AppRoutes.onboardingGoals:
        return MaterialPageRoute(builder: (_) => const OnboardingGoalsScreen());
      case AppRoutes.onboardingIncomeSource:
        return MaterialPageRoute(builder: (_) => const OnboardingIncomeSourceScreen());
      case AppRoutes.onboardingBuildPicture:
        return MaterialPageRoute(builder: (_) => const OnboardingBuildPictureScreen());
      case AppRoutes.financialSnapshot:
        return MaterialPageRoute(builder: (_) => const FinancialSnapshotScreen());
      case AppRoutes.ahaMoment:
        return MaterialPageRoute(builder: (_) => const AhaMomentScreen());
      case AppRoutes.paywall:
        return MaterialPageRoute(builder: (_) => const PaywallScreen());
      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }

  /// CONSUMER MONETIZATION FOUNDATION (PHASE 10) — the single, centralized
  /// place ENGAGEMENT events are logged from, since every navigation in
  /// this app already passes through here. This deliberately avoids
  /// touching any individual existing screen's code to wire analytics.
  static void _logRouteAnalytics(String? routeName) {
    final event = switch (routeName) {
      AppRoutes.dashboard || AppRoutes.navigation => AnalyticsEvent.dashboardOpened,
      AppRoutes.financialPlanning => AnalyticsEvent.financialPlanningOpened,
      AppRoutes.aiCoach => AnalyticsEvent.aiOpened,
      AppRoutes.affordability => AnalyticsEvent.affordabilityUsed,
      AppRoutes.taxPlanner => AnalyticsEvent.taxPlannerUsed,
      AppRoutes.financialTimeline => AnalyticsEvent.timelineOpened,
      AppRoutes.financialCompare => AnalyticsEvent.comparePeriodsUsed,
      // AppRoutes.paywall is intentionally excluded — PaywallScreen logs
      // paywallViewed itself (it needs no route-name metadata), so
      // routing it here too would double-count every paywall view.
      _ => null,
    };
    if (event != null) {
      AnalyticsService.instance.log(event, metadata: {'route': routeName});
    }
  }
}
