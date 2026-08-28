import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/providers/compare_periods_provider.dart';
import 'package:paysense/shared/utils/compare_periods_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _monthFormat = DateFormat('MMM yyyy');

/// COMPARE PERIODS 1.0 (PHASE 4) — every figure on this screen comes from
/// [comparePeriodsProvider] (-> [ComparePeriodsCalculator]). This screen
/// only formats; it never computes a comparison itself.
class FinancialCompareScreen extends ConsumerWidget {
  const FinancialCompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(comparePeriodsProvider);
    final preset = ref.watch(comparePeriodsPresetProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Compare Periods'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Text(
              'Compare Your Finances',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'See what changed between two periods.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const _PeriodPresetSelector(),
            if (preset == ComparePeriodsPreset.custom) ...[
              const SizedBox(height: 12),
              const _CustomMonthPickers(),
            ],
            const SizedBox(height: 16),
            _PeriodHeaderRow(current: result.currentPeriod.label, comparison: result.comparisonPeriod.label),
            const SizedBox(height: 20),
            if (!result.hasSufficientData)
              _InsufficientDataCard(message: result.verdict)
            else ...[
              _SummarySection(result: result),
              if (_positiveHighlights(result).isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionTitle("What's Better"),
                const SizedBox(height: 8),
                _HighlightsCard(items: _positiveHighlights(result), positive: true),
              ],
              if (_negativeHighlights(result).isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionTitle('Needs Attention'),
                const SizedBox(height: 8),
                _HighlightsCard(items: _negativeHighlights(result), positive: false),
              ],
              if (result.categoryChanges.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionTitle('Category Changes'),
                const SizedBox(height: 8),
                _CategoryChangesCard(changes: result.categoryChanges),
              ],
              const SizedBox(height: 20),
              const _SectionTitle('Financial Verdict'),
              const SizedBox(height: 8),
              _VerdictCard(verdict: result.verdict),
            ],
          ],
        ),
      ),
    );
  }
}

/// "What's Better" / "Needs Attention" use natural directional language for
/// the OVERALL metrics (income/expense/savings/savings-rate, which have a
/// reliable higher/lower-is-better interpretation) plus the largest
/// category movements — framed only as plain facts ("X spending decreased
/// by ₹Y" / "X spending increased by ₹Y"), never as a value judgment. The
/// separate "Category Changes" section below stays strictly neutral (no
/// ✓/⚠, no color-coded direction) since a category amount moving up or
/// down isn't reliably good or bad on its own (PHASE 1's explicit "a ₹5,000
/// rent increase isn't the same as a ₹5,000 entertainment increase" rule).
List<String> _positiveHighlights(ComparePeriodsResult r) {
  final items = <String>[];
  if (r.savings.direction == ComparisonDirection.improved) {
    items.add('You saved ${_money.format(r.savings.absoluteDifference.abs())} more');
  }
  if (r.savingsRate.direction == ComparisonDirection.improved && r.savingsRate.pointsDifference != null) {
    items.add('Your savings rate increased by ${r.savingsRate.pointsDifference!.abs().toStringAsFixed(0)} points');
  }
  if (r.income.direction == ComparisonDirection.improved) {
    items.add('Your income increased by ${_money.format(r.income.absoluteDifference.abs())}');
  }
  if (r.expense.direction == ComparisonDirection.improved) {
    items.add('Your expenses decreased by ${_money.format(r.expense.absoluteDifference.abs())}');
  }
  for (final c in r.categoryChanges.where((c) => c.direction == CategoryChangeDirection.decreased).take(3)) {
    items.add('${c.categoryId} spending decreased by ${_money.format((c.change.previous - c.change.current).abs())}');
  }
  return items;
}

List<String> _negativeHighlights(ComparePeriodsResult r) {
  final items = <String>[];
  if (r.expense.direction == ComparisonDirection.worsened) {
    items.add('Expenses increased by ${_money.format(r.expense.absoluteDifference.abs())}');
  }
  if (r.income.direction == ComparisonDirection.worsened) {
    items.add('Your income decreased by ${_money.format(r.income.absoluteDifference.abs())}');
  }
  if (r.savingsRate.direction == ComparisonDirection.worsened && r.savingsRate.pointsDifference != null) {
    items.add('Your savings rate dropped by ${r.savingsRate.pointsDifference!.abs().toStringAsFixed(0)} points');
  }
  for (final c in r.categoryChanges.where((c) => c.direction == CategoryChangeDirection.increased).take(3)) {
    items.add('${c.categoryId} spending increased by ${_money.format((c.change.current - c.change.previous).abs())}');
  }
  return items;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _PeriodPresetSelector extends ConsumerWidget {
  const _PeriodPresetSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(comparePeriodsPresetProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ComparePeriodsPreset.values.map((preset) {
        final isSelected = selected == preset;
        return ChoiceChip(
          label: Text(preset.label),
          selected: isSelected,
          onSelected: (_) => ref.read(comparePeriodsPresetProvider.notifier).state = preset,
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.primary.withValues(alpha: 0.16),
          labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }
}

class _CustomMonthPickers extends ConsumerWidget {
  const _CustomMonthPickers();

  static List<DateTime> _recentMonths() {
    final now = DateTime.now();
    return List.generate(36, (i) => DateTime(now.year, now.month - i, 1));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = _recentMonths();
    final current = ref.watch(compareCustomCurrentMonthProvider);
    final comparison = ref.watch(compareCustomComparisonMonthProvider);

    return Row(
      children: [
        Expanded(
          child: _MonthDropdown(
            label: 'Current month',
            value: current,
            months: months,
            onChanged: (value) => ref.read(compareCustomCurrentMonthProvider.notifier).state = value,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MonthDropdown(
            label: 'Compare to',
            value: comparison,
            months: months,
            onChanged: (value) => ref.read(compareCustomComparisonMonthProvider.notifier).state = value,
          ),
        ),
      ],
    );
  }
}

class _MonthDropdown extends StatelessWidget {
  const _MonthDropdown({
    required this.label,
    required this.value,
    required this.months,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final List<DateTime> months;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = months.firstWhere(
      (m) => m.year == value.year && m.month == value.month,
      orElse: () => months.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DateTime>(
              value: selected,
              isExpanded: true,
              items: months
                  .map((m) => DropdownMenuItem(value: m, child: Text(_monthFormat.format(m))))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodHeaderRow extends StatelessWidget {
  const _PeriodHeaderRow({required this.current, required this.comparison});
  final String current;
  final String comparison;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _PeriodPill(label: current, emphasized: true)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'vs',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: _PeriodPill(label: comparison, emphasized: false)),
      ],
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({required this.label, required this.emphasized});
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: emphasized ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
    );
  }
}

Color _directionColor(ComparisonDirection direction) {
  switch (direction) {
    case ComparisonDirection.improved:
      return AppColors.success;
    case ComparisonDirection.worsened:
      return AppColors.danger;
    case ComparisonDirection.unchanged:
    case ComparisonDirection.insufficientData:
      return AppColors.textSecondary;
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.result});
  final ComparePeriodsResult result;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _MetricRow(label: 'Income', metric: result.income),
          const Divider(height: 24),
          _MetricRow(label: 'Expenses', metric: result.expense),
          const Divider(height: 24),
          _MetricRow(label: 'Savings', metric: result.savings),
          const Divider(height: 24),
          _SavingsRateRow(rate: result.savingsRate),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.metric});
  final String label;
  final ComparePeriodMetric metric;

  @override
  Widget build(BuildContext context) {
    final color = _directionColor(metric.direction);
    final pct = metric.percentageDifference;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_money.format(metric.comparisonValue)} → ${_money.format(metric.currentValue)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (pct != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
              child: Text(
                '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            )
          else
            Text('—', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SavingsRateRow extends StatelessWidget {
  const _SavingsRateRow({required this.rate});
  final SavingsRateComparison rate;

  @override
  Widget build(BuildContext context) {
    final color = _directionColor(rate.direction);
    final current = rate.currentRate;
    final comparison = rate.comparisonRate;
    final points = rate.pointsDifference;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Savings Rate',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comparison != null && current != null
                      ? '${comparison.toStringAsFixed(0)}% → ${current.toStringAsFixed(0)}%'
                      : 'Not enough income data',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (points != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
              child: Text(
                '${points >= 0 ? '+' : ''}${points.toStringAsFixed(0)} pts',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            )
          else
            Text('—', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({required this.items, required this.positive});
  final List<String> items;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  positive ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  size: 18,
                  color: positive ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            if (item != items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CategoryChangesCard extends StatelessWidget {
  const _CategoryChangesCard({required this.changes});
  final List<CategoryComparison> changes;

  IconData _icon(CategoryChangeDirection direction) {
    switch (direction) {
      case CategoryChangeDirection.increased:
        return Icons.arrow_upward_rounded;
      case CategoryChangeDirection.decreased:
        return Icons.arrow_downward_rounded;
      case CategoryChangeDirection.unchanged:
      case CategoryChangeDirection.insufficientData:
        return Icons.remove_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final change in changes) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        change.categoryId,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_money.format(change.change.previous)} → ${_money.format(change.change.current)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Deliberately neutral (textSecondary), never success/danger
                // — a category's own amount moving isn't reliably good or
                // bad without context PaySense doesn't have.
                Row(
                  children: [
                    Icon(_icon(change.direction), size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _money.format((change.change.current - change.change.previous).abs()),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (change != changes.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.verdict});
  final String verdict;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.lightTeal, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.insights_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              verdict,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsufficientDataCard extends StatelessWidget {
  const _InsufficientDataCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
