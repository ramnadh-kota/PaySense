import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/financial_safety_alert.dart';
import 'package:paysense/shared/providers/financial_safety_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';

/// FINANCIAL SAFETY ENGINE — PART H / FINANCIAL SAFETY 2.0. Groups
/// deterministic alerts into the categories requested (Attention/
/// Upcoming/Spending/Income/Recurring — "Bills"/"Credit" have no alert
/// type today, see `FinancialSafetyEngine`'s documented credit-
/// utilization limitation). Now also supports the full ACTIVE ->
/// DISMISSED/SNOOZED/RESOLVED lifecycle, with a history view reachable
/// from the app bar.
class FinancialAlertsScreen extends ConsumerWidget {
  const FinancialAlertsScreen({super.key});

  static const _categoryFor = {
    FinancialSafetyAlertType.spendingSpike: 'Spending',
    FinancialSafetyAlertType.lowBalanceRisk: 'Attention',
    FinancialSafetyAlertType.upcomingEmiPressure: 'Upcoming',
    FinancialSafetyAlertType.recurringPaymentPressure: 'Recurring',
    FinancialSafetyAlertType.salaryIrregularity: 'Income',
    FinancialSafetyAlertType.largeUnusualTransaction: 'Spending',
    FinancialSafetyAlertType.cashFlowDeficit: 'Attention',
    FinancialSafetyAlertType.multipleLargeTransactionsCluster: 'Spending',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(financialSafetyAlertsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Financial Alerts'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Alert history',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.surface,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              builder: (context) => const _AlertHistorySheet(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: alertsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Text(
              'Unable to load alerts right now.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          data: (alerts) {
            if (alerts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 48, color: AppColors.success),
                      const SizedBox(height: 16),
                      Text(
                        'Nothing needs your attention right now',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final grouped = <String, List<FinancialSafetyAlert>>{};
            for (final alert in alerts) {
              grouped.putIfAbsent(_categoryFor[alert.type] ?? 'Attention', () => []).add(alert);
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final entry in grouped.entries) ...[
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final alert in entry.value) _AlertCard(alert: alert),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  const _AlertCard({required this.alert});
  final FinancialSafetyAlert alert;

  // Visually compact (so three actions fit without truncating), but keeps
  // Material's default `padded` tap target size — the touch AREA stays at
  // least 48x48 via invisible padding even though the visible button is
  // smaller, so this doesn't shrink real tap targets.
  static const _compactButtonStyle = ButtonStyle(
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
    visualDensity: VisualDensity.compact,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = switch (alert.severity) {
      FinancialSafetyAlertSeverity.high => AppColors.danger,
      FinancialSafetyAlertSeverity.attention => AppColors.warning,
      FinancialSafetyAlertSeverity.info => AppColors.primary,
    };

    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Why am I seeing this?',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(alert.explanation, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            'What can I do?',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(alert.recommendedAction, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          // A Wrap (not a Row) so three actions never overflow horizontally
          // on a narrow device — they simply flow to a second line instead.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              TextButton(
                style: _compactButtonStyle,
                onPressed: () => ref.read(financialSafetyAlertsProvider.notifier).snooze(alert.id),
                child: const Text('Snooze 3 days'),
              ),
              TextButton(
                style: _compactButtonStyle,
                onPressed: () => ref.read(financialSafetyAlertsProvider.notifier).resolve(alert.id),
                child: const Text('Resolve'),
              ),
              TextButton(
                style: _compactButtonStyle,
                onPressed: () => ref.read(financialSafetyAlertsProvider.notifier).dismiss(alert.id),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertHistorySheet extends ConsumerWidget {
  const _AlertHistorySheet();

  String _statusLabel(FinancialSafetyAlertLifecycle status) {
    switch (status) {
      case FinancialSafetyAlertLifecycle.dismissed:
        return 'Dismissed';
      case FinancialSafetyAlertLifecycle.snoozed:
        return 'Snoozed';
      case FinancialSafetyAlertLifecycle.resolved:
        return 'Resolved';
      case FinancialSafetyAlertLifecycle.active:
        return 'Active';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(financialSafetyHistoryProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alert history',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: historyAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Text(
                  'Unable to load history.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                data: (history) {
                  if (history.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No dismissed, snoozed, or resolved alerts yet.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final state = history[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          state.alertId,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${_statusLabel(state.status)} · ${DateFormat('MMM d, yyyy').format(state.updatedAt)}'
                          '${state.snoozedUntil != null ? ' · until ${DateFormat('MMM d').format(state.snoozedUntil!)}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            await ref.read(financialSafetyAlertsProvider.notifier).reopen(state.alertId);
                            ref.invalidate(financialSafetyHistoryProvider);
                          },
                          child: const Text('Reopen'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
