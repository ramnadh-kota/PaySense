import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/providers/financial_snapshot_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/services/analytics_service.dart';
import 'package:paysense/shared/utils/financial_health_calculator.dart' show financialHealthStatusLabel;
import 'package:paysense/shared/utils/financial_planning_calculator.dart' show GoalProjectionStatus;
import 'package:paysense/shared/widgets/app_card.dart';

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// CONSUMER MONETIZATION FOUNDATION (PHASE 2, Screen 5) — "Your Financial
/// Snapshot." Every figure comes from [financialSnapshotProvider] (→
/// [FinancialSnapshotBuilder], a thin adapter over the SAME calculators
/// the rest of the app already uses). This screen only formats.
class FinancialSnapshotScreen extends ConsumerStatefulWidget {
  const FinancialSnapshotScreen({super.key});

  @override
  ConsumerState<FinancialSnapshotScreen> createState() => _FinancialSnapshotScreenState();
}

class _FinancialSnapshotScreenState extends ConsumerState<FinancialSnapshotScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.log(AnalyticsEvent.financialSnapshotViewed);
  }

  Future<void> _continue() async {
    await AppSettingsRepository.instance.setOnboardingSnapshotViewed();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.ahaMoment, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(financialSnapshotProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                children: [
                  Text(
                    'Your Financial Snapshot',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Here's what PaySense already understands about your money.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  if (!snapshot.hasSufficientData)
                    _EmptySnapshotCard(message: snapshot.personalizedSummary)
                  else ...[
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      color: AppColors.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Net Worth', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 6),
                          Text(
                            _money.format(snapshot.netWorth),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _StatTile(label: 'Monthly Income', value: _money.format(snapshot.monthlyIncome))),
                        const SizedBox(width: 10),
                        Expanded(child: _StatTile(label: 'Monthly Expenses', value: _money.format(snapshot.monthlyExpenses))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            label: 'Savings Rate',
                            value: snapshot.savingsRatePercent != null
                                ? '${snapshot.savingsRatePercent!.toStringAsFixed(0)}%'
                                : 'Not enough data',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            label: 'Safe to Spend',
                            value: snapshot.safeToSpend.hasSufficientData
                                ? _money.format(snapshot.safeToSpend.safeToSpend)
                                : 'Not enough data',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Financial Health'),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: snapshot.healthHasSufficientData
                          ? Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: AppColors.lightTeal, borderRadius: BorderRadius.circular(14)),
                                  child: Icon(Icons.favorite_rounded, color: AppColors.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${snapshot.healthScore}/100',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        financialHealthStatusLabel(snapshot.healthStatus),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Keep tracking to unlock your Financial Health score.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                            ),
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Emergency Fund & Debt'),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshot.emergencyFund.isSourceConfigured
                                ? (snapshot.emergencyFund.isFullyFunded
                                    ? 'Your emergency fund is fully funded.'
                                    : 'Emergency fund: ${_money.format(snapshot.emergencyFund.current)} of '
                                        '${_money.format(snapshot.emergencyFund.target ?? 0)} target.')
                                : "Emergency fund not set up yet — you can configure this in Financial Planning.",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.debt.hasDebt
                                ? 'Monthly EMI burden: ${_money.format(snapshot.debt.monthlyEmiBurden)}'
                                : 'No active loans — no EMI burden.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    if (snapshot.goalProjections.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionLabel('Goals Progress'),
                      const SizedBox(height: 8),
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            for (final goal in snapshot.goalProjections.take(3)) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      goal.title,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                                    ),
                                  ),
                                  Text(
                                    goal.status == GoalProjectionStatus.completed
                                        ? 'Completed'
                                        : '${(goal.currentAmount / (goal.targetAmount == 0 ? 1 : goal.targetAmount) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              if (goal != snapshot.goalProjections.take(3).last) const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              snapshot.personalizedSummary,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _EmptySnapshotCard extends StatelessWidget {
  const _EmptySnapshotCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.insights_rounded, size: 40, color: AppColors.textSecondary),
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
