import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/providers/financial_timeline_provider.dart';
import 'package:paysense/shared/utils/financial_health_trends_calculator.dart' show TrendDirection;
import 'package:paysense/shared/utils/financial_momentum_calculator.dart';
import 'package:paysense/shared/utils/financial_timeline_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';

/// FINANCIAL INTELLIGENCE TIMELINE 1.0 (PHASE 5) — every event and momentum
/// signal on this screen comes from [financialTimelineProvider]/
/// [financialMomentumProvider] (-> [FinancialTimelineCalculator]/
/// [FinancialMomentumCalculator]). This screen only formats; it never
/// computes a figure itself.
class FinancialTimelineScreen extends ConsumerWidget {
  const FinancialTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(financialTimelineProvider);
    final period = ref.watch(financialTimelinePeriodProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Financial Timeline'),
      ),
      body: SafeArea(
        child: !result.hasSufficientData
            ? _EmptyState(monthsOfDataAvailable: result.monthsOfDataAvailable)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Text(
                    'What\'s happened with your money recently.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  const _MomentumCard(),
                  const SizedBox(height: 12),
                  _PeriodSelector(selected: period),
                  const SizedBox(height: 12),
                  _CashFlowSummary(result: result),
                  const SizedBox(height: 12),
                  if (result.isEmpty)
                    _NoEventsNote(period: period)
                  else
                    ...result.events.map((event) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TimelineRow(event: event),
                        )),
                ],
              ),
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector({required this.selected});
  final TimelinePeriod selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<TimelinePeriod>(
        segments: TimelinePeriod.values.map((p) => ButtonSegment(value: p, label: Text(p.label))).toList(),
        selected: {selected},
        onSelectionChanged: (selection) =>
            ref.read(financialTimelinePeriodProvider.notifier).state = selection.first,
      ),
    );
  }
}

/// FINANCIAL TIMELINE 2.0 — real income/expense/net-cash-flow sums for
/// the selected window, direct from transactions (see
/// [FinancialTimelineResult.periodIncome]/[periodExpense]) — the one
/// thing a day/week view can show even when there are no narrative
/// events yet.
class _CashFlowSummary extends StatelessWidget {
  const _CashFlowSummary({required this.result});
  final FinancialTimelineResult result;

  @override
  Widget build(BuildContext context) {
    final net = result.periodNetCashFlow;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _CashFlowStat(label: 'Income', value: result.periodIncome, color: AppColors.success),
          ),
          Expanded(
            child: _CashFlowStat(label: 'Expenses', value: result.periodExpense, color: AppColors.danger),
          ),
          Expanded(
            child: _CashFlowStat(
              label: 'Net',
              value: net,
              color: net >= 0 ? AppColors.success : AppColors.danger,
              showSign: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashFlowStat extends StatelessWidget {
  const _CashFlowStat({required this.label, required this.value, required this.color, this.showSign = false});
  final String label;
  final double value;
  final Color color;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final formatted = '${showSign && value >= 0 ? '+' : ''}₹${value.toStringAsFixed(0)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          formatted,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _MomentumCard extends ConsumerWidget {
  const _MomentumCard();

  (IconData, Color, String) _visualsFor(FinancialMomentumStatus status) {
    switch (status) {
      case FinancialMomentumStatus.improving:
        return (Icons.trending_up_rounded, AppColors.success, 'Your finances are improving');
      case FinancialMomentumStatus.declining:
        return (Icons.trending_down_rounded, AppColors.danger, 'Your finances need attention');
      case FinancialMomentumStatus.stable:
        return (Icons.trending_flat_rounded, AppColors.textSecondary, 'Your finances are steady');
      case FinancialMomentumStatus.insufficientData:
        return (Icons.auto_graph_rounded, AppColors.primary, 'Not enough history yet to judge momentum');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final momentum = ref.watch(financialMomentumProvider);
    final (icon, color, label) = _visualsFor(momentum.status);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (momentum.signals.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: momentum.signals.map((s) => _SignalChip(signal: s)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.signal});
  final FinancialMomentumSignal signal;

  (IconData, Color) _visualsFor(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.improving:
        return (Icons.arrow_upward_rounded, AppColors.success);
      case TrendDirection.declining:
        return (Icons.arrow_downward_rounded, AppColors.danger);
      case TrendDirection.stable:
        return (Icons.remove_rounded, AppColors.textSecondary);
      case TrendDirection.insufficientData:
        return (Icons.remove_rounded, AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _visualsFor(signal.direction);
    return Tooltip(
      message: signal.detail,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              signal.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event});
  final FinancialTimelineEvent event;

  (IconData, Color, Color) _visualsFor() {
    switch (event.tone) {
      case TimelineEventTone.positive:
        return (_iconForType(), AppColors.success, AppColors.lightTeal);
      case TimelineEventTone.warning:
        return (_iconForType(), AppColors.danger, AppColors.softCoral);
      case TimelineEventTone.neutral:
        return (_iconForType(), AppColors.textSecondary, AppColors.surfaceVariant);
    }
  }

  IconData _iconForType() {
    switch (event.type) {
      case TimelineEventType.spendingIncrease:
        return Icons.trending_up_rounded;
      case TimelineEventType.spendingDecrease:
        return Icons.trending_down_rounded;
      case TimelineEventType.budgetWarning:
        return Icons.info_outline_rounded;
      case TimelineEventType.budgetOverLimit:
        return Icons.warning_amber_rounded;
      case TimelineEventType.savingsImprovement:
        return Icons.savings_rounded;
      case TimelineEventType.savingsDecline:
        return Icons.money_off_rounded;
      case TimelineEventType.emergencyFundChange:
        return Icons.shield_rounded;
      case TimelineEventType.goalProgress:
        return Icons.flag_rounded;
      case TimelineEventType.debtProgress:
        return Icons.account_balance_rounded;
      case TimelineEventType.newSubscription:
        return Icons.autorenew_rounded;
      case TimelineEventType.recurringCommitmentChange:
        return Icons.repeat_rounded;
      case TimelineEventType.positiveMilestone:
        return Icons.emoji_events_rounded;
      case TimelineEventType.largeTransaction:
        return Icons.receipt_long_rounded;
    }
  }

  String _formatDate(DateTime date, DateTime now) {
    final pattern = date.year == now.year ? 'MMM d' : 'MMM d, yyyy';
    return DateFormat(pattern).format(date);
  }

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor, chipTint) = _visualsFor();
    final route = event.actionRoute;

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: route == null ? null : () => Navigator.of(context).pushNamed(route),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              _formatDate(event.date, DateTime.now()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: chipTint, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.explanation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoEventsNote extends StatelessWidget {
  const _NoEventsNote({required this.period});
  final TimelinePeriod period;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'No notable events in the last ${period.label}. Try a longer period.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.monthsOfDataAvailable});
  final int monthsOfDataAvailable;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Not enough history yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              monthsOfDataAvailable > 0
                  ? 'Keep tracking your transactions — your timeline will build up over time.'
                  : 'Add some transactions to start building your financial timeline.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
