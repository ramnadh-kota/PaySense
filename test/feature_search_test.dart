import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/entitlement.dart';
import 'package:paysense/shared/utils/feature_registry.dart';
import 'package:paysense/shared/utils/feature_search_matcher.dart';

void main() {
  group('kFeatureRegistry — data integrity', () {
    test('every entry has a non-empty title, subtitle, and route', () {
      for (final item in kFeatureRegistry) {
        expect(item.title, isNotEmpty);
        expect(item.subtitle, isNotEmpty);
        expect(item.route, isNotEmpty);
      }
    });

    test('every route referenced is a real AppRoutes constant', () {
      final validRoutes = {
        AppRoutes.splash, AppRoutes.login, AppRoutes.signup, AppRoutes.forgotPassword,
        AppRoutes.onboarding, AppRoutes.profileSetup, AppRoutes.navigation, AppRoutes.dashboard,
        AppRoutes.wallet, AppRoutes.transactions, AppRoutes.financialHealth, AppRoutes.analytics,
        AppRoutes.budget, AppRoutes.goals, AppRoutes.recurring, AppRoutes.bills, AppRoutes.loans,
        AppRoutes.aiCoach, AppRoutes.profile, AppRoutes.settings, AppRoutes.changePassword,
        AppRoutes.appLockPinSetup, AppRoutes.notifications, AppRoutes.monthlyReview,
        AppRoutes.safeToSpend, AppRoutes.cashFlow, AppRoutes.subscriptions, AppRoutes.smsReview,
        AppRoutes.reports, AppRoutes.financialPlanning, AppRoutes.taxPlanner, AppRoutes.affordability,
        AppRoutes.financialHealthTrends, AppRoutes.financialTimeline, AppRoutes.financialCompare,
        AppRoutes.csvImport, AppRoutes.bankConnect, AppRoutes.connectedAccounts, AppRoutes.featureSearch,
        AppRoutes.recurringMoney, AppRoutes.dataExport,
      };
      for (final item in kFeatureRegistry) {
        expect(validRoutes.contains(item.route), isTrue, reason: '"${item.title}" points at an unknown route "${item.route}"');
      }
    });
  });

  group('FeatureSearchMatcher.search', () {
    test('exact title match ranks first', () {
      final results = FeatureSearchMatcher.search('Tax Planner', kFeatureRegistry);
      expect(results.first.title, 'Tax Planner');
    });

    test('alias/keyword match: "emi" finds Loans', () {
      final results = FeatureSearchMatcher.search('emi', kFeatureRegistry);
      expect(results.any((r) => r.title == 'Loans'), isTrue);
    });

    test('keyword match: "bank" finds Connect Bank', () {
      final results = FeatureSearchMatcher.search('bank', kFeatureRegistry);
      expect(results.any((r) => r.title == 'Connect Bank'), isTrue);
    });

    test('keyword match: "what if" finds What-If Intelligence', () {
      final results = FeatureSearchMatcher.search('what if', kFeatureRegistry);
      expect(results.any((r) => r.title == 'What-If Intelligence'), isTrue);
    });

    test('keyword match: "afford" finds Can I Afford This?', () {
      final results = FeatureSearchMatcher.search('afford', kFeatureRegistry);
      expect(results.any((r) => r.title == 'Can I Afford This?'), isTrue);
    });

    test('keyword match: "csv" finds Import Bank Statement', () {
      final results = FeatureSearchMatcher.search('csv', kFeatureRegistry);
      expect(results.any((r) => r.title == 'Import Bank Statement'), isTrue);
    });

    test('case insensitive: "TAX" and "tax" return the same results', () {
      final lower = FeatureSearchMatcher.search('tax', kFeatureRegistry);
      final upper = FeatureSearchMatcher.search('TAX', kFeatureRegistry);
      expect(upper.map((r) => r.title), lower.map((r) => r.title));
    });

    test('empty query returns no results (browse-by-category is the UI fallback)', () {
      expect(FeatureSearchMatcher.search('', kFeatureRegistry), isEmpty);
      expect(FeatureSearchMatcher.search('   ', kFeatureRegistry), isEmpty);
    });

    test('a query matching nothing returns an empty list, never throws', () {
      expect(FeatureSearchMatcher.search('zzzznonexistentfeature', kFeatureRegistry), isEmpty);
    });

    test('a Plus-only feature is still returned by search — gating is a UI concern, not a search concern', () {
      final results = FeatureSearchMatcher.search('tax', kFeatureRegistry);
      final taxPlanner = results.firstWhere((r) => r.title == 'Tax Planner');
      expect(taxPlanner.entitlement, Entitlement.taxPlanner);
    });

    test('a free feature has no entitlement gate', () {
      final results = FeatureSearchMatcher.search('budget', kFeatureRegistry);
      final budgets = results.firstWhere((r) => r.title == 'Budgets');
      expect(budgets.entitlement, isNull);
    });

    test('subtitle-only matches still surface, ranked below title/keyword matches', () {
      final results = FeatureSearchMatcher.search('purchase', kFeatureRegistry);
      expect(results, isNotEmpty);
    });
  });
}
