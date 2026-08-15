import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/subscription_summary.dart';
import 'package:paysense/shared/providers/subscription_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/subscription_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(subscriptionTotalsProvider);
    final upcoming = ref.watch(subscriptionUpcomingRenewalsProvider);
    final filtered = ref.watch(filteredSubscriptionsProvider);
    final sortOption = ref.watch(subscriptionSortOptionProvider);
    final categoryFilter = ref.watch(subscriptionCategoryFilterProvider);

    final currencyCode = ref.watch(userProfileProvider).value?.currency.isNotEmpty == true
        ? ref.watch(userProfileProvider).value!.currency
        : 'INR';
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: CurrencyFormatter.symbolFor(currencyCode),
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Subscriptions & Recurring Services'),
      ),
      body: SafeArea(
        child: !totals.hasSubscriptions
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  _SummaryHero(totals: totals, currencyFormatter: currencyFormatter),
                  const SizedBox(height: 20),
                  _UpcomingSection(events: upcoming, currencyFormatter: currencyFormatter),
                  const SizedBox(height: 20),
                  _AllSubscriptionsSection(
                    subscriptions: filtered,
                    sortOption: sortOption,
                    categoryFilter: categoryFilter,
                    categories: totals.categoryTotals.keys.toList(),
                    currencyFormatter: currencyFormatter,
                    onSortChanged: (value) =>
                        ref.read(subscriptionSortOptionProvider.notifier).state = value,
                    onCategoryChanged: (value) =>
                        ref.read(subscriptionCategoryFilterProvider.notifier).state = value,
                  ),
                  if (totals.mostExpensive != null) ...[
                    const SizedBox(height: 20),
                    _MostExpensiveSection(
                      subscription: totals.mostExpensive!,
                      currencyFormatter: currencyFormatter,
                    ),
                  ],
                  if (totals.categoryTotals.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _CategoryBreakdownSection(
                      categoryTotals: totals.categoryTotals,
                      currencyFormatter: currencyFormatter,
                    ),
                  ],
                  const SizedBox(height: 20),
                  _AnnualCostCard(totals: totals, currencyFormatter: currencyFormatter),
                ],
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.subscriptions_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No recurring services yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add a recurring expense to start tracking your subscriptions.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({required this.totals, required this.currencyFormatter});

  final SubscriptionTotals totals;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscriptions',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            '${currencyFormatter.format(totals.totalMonthlyCost)} / month',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${currencyFormatter.format(totals.totalAnnualCost)} / year',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Text(
            '${totals.activeCount} active service${totals.activeCount == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({required this.events, required this.currencyFormatter});

  final List<SubscriptionSummary> events;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Text(
              "You're all caught up 🎉",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.recurring),
            child: Column(
              children: events.map((subscription) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (subscription.isOverdue ? AppColors.danger : AppColors.accent)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.autorenew_rounded,
                          color: subscription.isOverdue ? AppColors.danger : AppColors.accent,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subscription.name,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              subscription.isOverdue
                                  ? 'Overdue'
                                  : 'Due ${DateFormat('d MMM').format(subscription.nextDueDate)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: subscription.isOverdue
                                    ? AppColors.danger
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFormatter.format(subscription.amount),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _AllSubscriptionsSection extends StatelessWidget {
  const _AllSubscriptionsSection({
    required this.subscriptions,
    required this.sortOption,
    required this.categoryFilter,
    required this.categories,
    required this.currencyFormatter,
    required this.onSortChanged,
    required this.onCategoryChanged,
  });

  final List<SubscriptionSummary> subscriptions;
  final SubscriptionSortOption sortOption;
  final String? categoryFilter;
  final List<String> categories;
  final NumberFormat currencyFormatter;
  final ValueChanged<SubscriptionSortOption> onSortChanged;
  final ValueChanged<String?> onCategoryChanged;

  static const _sortLabels = {
    SubscriptionSortOption.all: 'All',
    SubscriptionSortOption.highestCost: 'Highest cost',
    SubscriptionSortOption.lowestCost: 'Lowest cost',
    SubscriptionSortOption.upcoming: 'Upcoming',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All subscriptions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in SubscriptionSortOption.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_sortLabels[option]!),
                    selected: sortOption == option,
                    onSelected: (_) => onSortChanged(option),
                    selectedColor: AppColors.lightTeal,
                    labelStyle: TextStyle(
                      color: sortOption == option ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.surface,
                  ),
                ),
              if (categories.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All categories'),
                    selected: categoryFilter == null,
                    onSelected: (_) => onCategoryChanged(null),
                    selectedColor: AppColors.softCoral,
                    labelStyle: TextStyle(
                      color: categoryFilter == null ? AppColors.accent : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.surface,
                  ),
                ),
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: categoryFilter == category,
                      onSelected: (_) => onCategoryChanged(category),
                      selectedColor: AppColors.softCoral,
                      labelStyle: TextStyle(
                        color: categoryFilter == category
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: AppColors.surface,
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (subscriptions.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No subscriptions match this filter.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.recurring),
            child: Column(
              children: subscriptions.map((subscription) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subscription.name,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              subscription.category.isEmpty
                                  ? 'Uncategorized'
                                  : subscription.category,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${currencyFormatter.format(subscription.monthlyEquivalent)} / month',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _MostExpensiveSection extends StatelessWidget {
  const _MostExpensiveSection({required this.subscription, required this.currencyFormatter});

  final SubscriptionSummary subscription;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Most expensive',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.trending_up_rounded, color: AppColors.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  subscription.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${currencyFormatter.format(subscription.monthlyEquivalent)}/month',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryBreakdownSection extends StatelessWidget {
  const _CategoryBreakdownSection({
    required this.categoryTotals,
    required this.currencyFormatter,
  });

  final Map<String, double> categoryTotals;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    final entries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'By category',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${currencyFormatter.format(entry.value)}/month',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _AnnualCostCard extends StatelessWidget {
  const _AnnualCostCard({required this.totals, required this.currencyFormatter});

  final SubscriptionTotals totals;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      color: AppColors.lightTeal,
      child: Text(
        "You're currently spending ${currencyFormatter.format(totals.totalAnnualCost)}/year "
        'on recurring services. This is an app-generated summary based on the '
        'financial information currently recorded in PaySense.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
