import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/feature_search_item.dart';
import 'package:paysense/shared/models/financial_search_result.dart';
import 'package:paysense/shared/providers/bill_provider.dart';
import 'package:paysense/shared/providers/entitlement_provider.dart';
import 'package:paysense/shared/providers/goal_provider.dart';
import 'package:paysense/shared/providers/loan_provider.dart';
import 'package:paysense/shared/providers/recurring_transaction_provider.dart';
import 'package:paysense/shared/providers/safe_to_spend_provider.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/recent_search_repository.dart';
import 'package:paysense/shared/services/analytics_service.dart';
import 'package:paysense/shared/utils/feature_registry.dart';
import 'package:paysense/shared/utils/feature_search_matcher.dart';
import 'package:paysense/shared/utils/financial_search_engine.dart';

/// PAYSENSE SEARCH — PART E/F. Extends the original Feature Search (kept
/// fully intact — [kFeatureRegistry]/[FeatureSearchMatcher] are unchanged)
/// into a unified search over BOTH app features and real financial data
/// ([FinancialSearchEngine]), following PART L's hybrid architecture:
/// deterministic engines answer first; this screen never calls AI.
class FeatureSearchScreen extends ConsumerStatefulWidget {
  const FeatureSearchScreen({super.key});

  @override
  ConsumerState<FeatureSearchScreen> createState() => _FeatureSearchScreenState();
}

const _suggestedSearches = [
  'Biggest expenses',
  'This month\'s spending',
  'Salary received',
  'Recurring payments',
  'Upcoming bills',
];

class _FeatureSearchScreenState extends ConsumerState<FeatureSearchScreen> {
  final _controller = TextEditingController();
  List<FeatureSearchItem> _featureResults = const [];
  List<FinancialSearchResult> _financialResults = const [];
  FinancialSearchAnswer? _answer;
  List<String> _recentSearches = const [];

  @override
  void initState() {
    super.initState();
    RecentSearchRepository.instance.getRecent().then((recent) {
      if (mounted) setState(() => _recentSearches = recent);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSearch(String query) {
    _controller.text = query;
    _onQueryChanged(query);
  }

  void _onQueryChanged(String query) {
    final now = DateTime.now();
    final transactions = ref.read(transactionsProvider).value ?? const [];
    final wallets = ref.read(walletsProvider).value ?? const [];
    final recurring = ref.read(recurringTransactionsProvider).value ?? const [];
    final loans = ref.read(loansProvider).value ?? const [];
    final goals = ref.read(goalsProvider).value ?? const [];
    final bills = ref.read(billsProvider).value ?? const [];
    final safeToSpend = ref.read(safeToSpendProvider);

    setState(() {
      _featureResults = FeatureSearchMatcher.search(query, kFeatureRegistry);
      _answer = FinancialSearchEngine.answer(
        query: query,
        transactions: transactions,
        wallets: wallets,
        loans: loans,
        now: now,
        bills: bills,
        recurringTransactions: recurring,
        safeToSpend: safeToSpend,
      );
      _financialResults = _answer != null
          ? const []
          : FinancialSearchEngine.search(
              query: query,
              transactions: transactions,
              wallets: wallets,
              recurringTransactions: recurring,
              loans: loans,
              goals: goals,
              now: now,
            );
    });

    if (query.trim().length >= 3) {
      RecentSearchRepository.instance.record(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final hasResults = _answer != null || _featureResults.isNotEmpty || _financialResults.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onQueryChanged,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search PaySense — "Where did my money go?"',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            border: InputBorder.none,
          ),
        ),
      ),
      body: SafeArea(
        child: query.isEmpty
            ? _buildEmptyState(context)
            : hasResults
                ? _buildResults(context)
                : _buildNoResults(context, query),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final byType = <FinancialSearchResultType, List<FinancialSearchResult>>{};
    for (final result in _financialResults) {
      byType.putIfAbsent(result.type, () => []).add(result);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_answer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
              child: Text(
                _answer!.answer,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
          ),
        if (byType[FinancialSearchResultType.transaction]?.isNotEmpty ?? false)
          _ResultSection(title: 'Transactions', results: byType[FinancialSearchResultType.transaction]!),
        if (byType[FinancialSearchResultType.wallet]?.isNotEmpty ?? false)
          _ResultSection(title: 'Accounts', results: byType[FinancialSearchResultType.wallet]!),
        if (byType[FinancialSearchResultType.recurring]?.isNotEmpty ?? false)
          _ResultSection(title: 'Recurring', results: byType[FinancialSearchResultType.recurring]!),
        if (byType[FinancialSearchResultType.loan]?.isNotEmpty ?? false)
          _ResultSection(title: 'Loans', results: byType[FinancialSearchResultType.loan]!),
        if (byType[FinancialSearchResultType.goal]?.isNotEmpty ?? false)
          _ResultSection(title: 'Goals', results: byType[FinancialSearchResultType.goal]!),
        if (_featureResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text('Features', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          for (final item in _featureResults) _FeatureTile(item: item),
        ],
      ],
    );
  }

  Widget _buildNoResults(BuildContext context, String query) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.search_off_rounded, size: 40, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(
          'No results for "$query"',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Try a merchant name, category, or amount — like "food" or "above 1000".',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _suggestedSearches.map((q) => ActionChip(label: Text(q), onPressed: () => _runSearch(q))).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Recent searches', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((q) => ActionChip(label: Text(q), onPressed: () => _runSearch(q))).toList(),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text('Suggested', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedSearches.map((q) => ActionChip(label: Text(q), onPressed: () => _runSearch(q))).toList(),
          ),
        ),
        const SizedBox(height: 16),
        ..._buildBrowseByCategory(context),
      ],
    );
  }

  List<Widget> _buildBrowseByCategory(BuildContext context) {
    final byCategory = <String, List<FeatureSearchItem>>{};
    for (final item in kFeatureRegistry) {
      byCategory.putIfAbsent(item.category, () => []).add(item);
    }
    return [
      for (final entry in byCategory.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(entry.key, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
        for (final item in entry.value) _FeatureTile(item: item),
      ],
    ];
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.results});
  final String title;
  final List<FinancialSearchResult> results;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
        for (final result in results.take(10))
          ListTile(
            title: Text(result.title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            subtitle: Text(result.subtitle, style: TextStyle(color: AppColors.textSecondary)),
            trailing: result.amount != null
                ? Text('₹${result.amount!.toStringAsFixed(0)}', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600))
                : null,
            onTap: result.route == null
                ? null
                : () {
                    AnalyticsService.instance.log(
                      AnalyticsEvent.financialSearchResultTapped,
                      metadata: {'type': result.type.name, 'route': result.route},
                    );
                    Navigator.of(context).pushNamed(result.route!);
                  },
          ),
      ],
    );
  }
}

class _FeatureTile extends ConsumerWidget {
  const _FeatureTile({required this.item});
  final FeatureSearchItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = item.entitlement != null && !canAccessEntitlement(ref, item.entitlement!);

    return ListTile(
      leading: Icon(item.icon, color: AppColors.accent),
      title: Text(item.title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(item.subtitle, style: TextStyle(color: AppColors.textSecondary)),
      trailing: isLocked
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'PaySense Plus',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      onTap: () {
        AnalyticsService.instance.log(
          AnalyticsEvent.featureSearchResultTapped,
          metadata: {'feature': item.title, 'locked': isLocked},
        );
        if (isLocked) {
          Navigator.of(context).pushNamed(AppRoutes.paywall);
        } else {
          Navigator.of(context).pushNamed(item.route);
        }
      },
    );
  }
}
