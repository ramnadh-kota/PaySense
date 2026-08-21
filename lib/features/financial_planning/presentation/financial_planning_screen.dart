import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/financial_planning_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';

final _currencyFormatter = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

String _money(double value) => _currencyFormatter.format(value);

String _monthYear(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

Color _statusColor(PlanningComponentStatus status) {
  switch (status) {
    case PlanningComponentStatus.good:
      return AppColors.success;
    case PlanningComponentStatus.fair:
      return AppColors.warning;
    case PlanningComponentStatus.needsAttention:
      return AppColors.danger;
    case PlanningComponentStatus.insufficientData:
      return AppColors.textSecondary;
  }
}

String _statusLabel(PlanningComponentStatus status) {
  switch (status) {
    case PlanningComponentStatus.good:
      return 'Good';
    case PlanningComponentStatus.fair:
      return 'Fair';
    case PlanningComponentStatus.needsAttention:
      return 'Needs attention';
    case PlanningComponentStatus.insufficientData:
      return 'Not enough data';
  }
}

/// Financial Planning 2.0's main screen — "How financially prepared am I?"
/// Every figure here is read from [financialPlanningProvider]
/// (FinancialPlanningCalculator), which is read-only against existing
/// Wallet/Transaction/Goal/Loan/Bill/RecurringTransaction data. This screen
/// never creates, edits, or deletes any of those records.
class FinancialPlanningScreen extends ConsumerWidget {
  const FinancialPlanningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(financialPlanningProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Financial Planning'),
      ),
      body: SafeArea(
        child: !result.hasSufficientData
            ? const _EmptyPlanningState()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReadinessHeader(result: result),
                    const SizedBox(height: 20),
                    _TaxPlannerEntryCard(),
                    const SizedBox(height: 10),
                    _AffordabilityEntryCard(),
                    const SizedBox(height: 20),
                    _ActionPlanCard(recommendations: result.recommendations),
                    const SizedBox(height: 20),
                    _SectionTitle('Financial Overview'),
                    const SizedBox(height: 10),
                    _OverviewCard(overview: result.overview),
                    const SizedBox(height: 20),
                    _SectionTitle('Emergency Fund', status: result.emergencyFundStatus),
                    const SizedBox(height: 10),
                    _EmergencyFundCard(emergencyFund: result.emergencyFund),
                    const SizedBox(height: 20),
                    _SectionTitle('Goal Projections', status: result.goalStatus),
                    const SizedBox(height: 10),
                    _GoalProjectionsSection(goals: result.goalProjections),
                    const SizedBox(height: 20),
                    _SectionTitle('Monthly Commitments', status: result.commitmentStatus),
                    const SizedBox(height: 10),
                    _CommitmentsCard(commitments: result.commitments),
                    const SizedBox(height: 20),
                    _SectionTitle('Debt Overview', status: result.debtStatus),
                    const SizedBox(height: 10),
                    _DebtCard(debt: result.debt, priority: result.debtPriority),
                    const SizedBox(height: 20),
                    _SectionTitle('Savings Plan', status: result.savingsStatus),
                    const SizedBox(height: 10),
                    _SavingsPlanCard(plan: result.savingsPlan),
                    const SizedBox(height: 20),
                    _SectionTitle('What If?'),
                    const SizedBox(height: 10),
                    _WhatIfCard(result: result),
                    const SizedBox(height: 20),
                    _SectionTitle('Timeline'),
                    const SizedBox(height: 10),
                    _TimelineCard(result: result),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Entry point into the Tax Planner (PHASE 13) — deliberately not another
/// bottom-nav Quick Action, just a card here and in the AI screen.
class _TaxPlannerEntryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.taxPlanner),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.lightTeal, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tax Planner',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Estimate your income tax and compare Old vs New Regime',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

/// Entry point into "Can I Afford This?" (PHASE 10/13) — same compact-card
/// pattern as [_TaxPlannerEntryCard], not a bottom-nav Quick Action.
class _AffordabilityEntryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.affordability),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.lightTeal, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Can I Afford This?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Simulate a purchase against your financial plan',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _EmptyPlanningState extends StatelessWidget {
  const _EmptyPlanningState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Add a few transactions to unlock financial planning insights.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.status});

  final String text;
  final PlanningComponentStatus? status;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (status != null) _StatusChip(status!),
      ],
    );
  }
}

class _ReadinessHeader extends StatelessWidget {
  const _ReadinessHeader({required this.result});

  final FinancialPlanningResult result;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      color: AppColors.primary,
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (result.readinessScore / 100).clamp(0.0, 1.0),
                  strokeWidth: 8,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                ),
                Text(
                  '${result.readinessScore}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're ${result.readinessScore}% financially prepared",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  planningReadinessStatusLabel(result.status),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPlanCard extends StatelessWidget {
  const _ActionPlanCard({required this.recommendations});

  final List<String> recommendations;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_circle_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Top actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < recommendations.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    recommendations[i],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.overview});

  final FinancialOverview overview;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverviewRow('Net worth', _money(overview.netWorth),
              valueColor: overview.netWorth < 0 ? AppColors.danger : AppColors.textPrimary),
          const _Divider(),
          _OverviewRow('Monthly income', _money(overview.monthlyIncome)),
          const _Divider(),
          _OverviewRow('Monthly expenses', _money(overview.monthlyExpenses)),
          const _Divider(),
          _OverviewRow(
            'Monthly savings',
            _money(overview.monthlySavings),
            valueColor: overview.monthlySavings < 0 ? AppColors.danger : AppColors.success,
          ),
          const _Divider(),
          _OverviewRow(
            'Savings rate',
            overview.savingsRatePercent == null
                ? 'No income data'
                : '${overview.savingsRatePercent!.toStringAsFixed(0)}%',
          ),
          const _Divider(),
          _OverviewRow('Monthly fixed commitments', _money(overview.monthlyFixedCommitments)),
          const _Divider(),
          _OverviewRow('Total debt', _money(overview.totalDebt)),
          const _Divider(),
          _OverviewRow('Emergency fund', _money(overview.emergencyFundCurrent)),
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: AppColors.divider);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final PlanningComponentStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

class _EmergencyFundCard extends ConsumerWidget {
  const _EmergencyFundCard({required this.emergencyFund});

  final EmergencyFundResult emergencyFund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!emergencyFund.isSourceConfigured) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency fund amount needs to be configured',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose which wallets count toward your emergency fund so '
              'PaySense can track progress accurately.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _showWalletPicker(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Choose eligible wallets'),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target: ${emergencyFund.targetMonths} months',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => _showMonthPicker(context, ref),
                child: const Text('Change'),
              ),
            ],
          ),
          if (!emergencyFund.hasExpenseData)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Add a few months of expense history to calculate your '
                'emergency fund target.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 10),
            _OverviewRow('Emergency fund target', _money(emergencyFund.target!)),
            const _Divider(),
            _OverviewRow('Current', _money(emergencyFund.current)),
            const _Divider(),
            _OverviewRow(
              'Remaining',
              _money(emergencyFund.remaining!),
              valueColor: emergencyFund.remaining! > 0 ? AppColors.warning : AppColors.success,
            ),
            const _Divider(),
            _OverviewRow(
              'Monthly contribution',
              emergencyFund.monthlyContribution == null
                  ? 'No positive savings this month'
                  : _money(emergencyFund.monthlyContribution!),
            ),
            const _Divider(),
            _OverviewRow(
              'Estimated completion',
              emergencyFund.estimatedMonths == null
                  ? 'Not enough data'
                  : emergencyFund.estimatedMonths == 0
                      ? 'Reached'
                      : '${emergencyFund.estimatedMonths} month'
                          '${emergencyFund.estimatedMonths == 1 ? '' : 's'}'
                          ' (${_monthYear(emergencyFund.estimatedCompletionDate!)})',
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _showWalletPicker(context, ref),
              child: const Text('Edit eligible wallets'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMonthPicker(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: emergencyFundTargetMonthOptions
                .map(
                  (months) => ListTile(
                    title: Text('$months months'),
                    trailing: months == emergencyFund.targetMonths
                        ? Icon(Icons.check_rounded, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(months),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (selected != null) {
      await ref.read(emergencyFundTargetMonthsProvider.notifier).setTargetMonths(selected);
    }
  }

  Future<void> _showWalletPicker(BuildContext context, WidgetRef ref) async {
    final wallets = ref.read(walletsProvider).value ?? const <Wallet>[];
    final current = ref.read(emergencyFundEligibleWalletIdsProvider).value ?? const <String>[];
    final selectedIds = {...current};

    if (wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a wallet first to configure an emergency fund.')),
      );
      return;
    }

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency fund wallets',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select the wallets that hold your emergency savings.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final wallet in wallets.where((w) => !w.isArchived))
                      CheckboxListTile(
                        value: selectedIds.contains(wallet.id),
                        title: Text(wallet.name),
                        subtitle: Text(_money(wallet.currentBalance)),
                        activeColor: AppColors.primary,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              selectedIds.add(wallet.id);
                            } else {
                              selectedIds.remove(wallet.id);
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(selectedIds),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      await ref
          .read(emergencyFundEligibleWalletIdsProvider.notifier)
          .setEligibleWallets(result.toList());
    }
  }
}

class _GoalProjectionsSection extends StatelessWidget {
  const _GoalProjectionsSection({required this.goals});

  final List<GoalProjection> goals;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Add a savings goal to see completion projections here.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      children: goals
          .map(
            (goal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GoalProjectionCard(goal: goal),
            ),
          )
          .toList(),
    );
  }
}

class _GoalProjectionCard extends StatelessWidget {
  const _GoalProjectionCard({required this.goal});

  final GoalProjection goal;

  Color get _statusColorForGoal {
    switch (goal.status) {
      case GoalProjectionStatus.completed:
        return AppColors.success;
      case GoalProjectionStatus.onTrack:
        return AppColors.success;
      case GoalProjectionStatus.atRisk:
        return AppColors.danger;
      case GoalProjectionStatus.insufficientData:
        return AppColors.textSecondary;
    }
  }

  String get _statusLabelForGoal {
    switch (goal.status) {
      case GoalProjectionStatus.completed:
        return 'Completed';
      case GoalProjectionStatus.onTrack:
        return 'On track';
      case GoalProjectionStatus.atRisk:
        return 'At risk';
      case GoalProjectionStatus.insufficientData:
        return 'Not enough data';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColorForGoal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabelForGoal,
                  style: TextStyle(
                    color: _statusColorForGoal,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _OverviewRow('Target', _money(goal.targetAmount)),
          _OverviewRow('Current', _money(goal.currentAmount)),
          _OverviewRow('Remaining', _money(goal.remainingAmount)),
          _OverviewRow(
            'Avg. monthly contribution',
            goal.impliedMonthlyContribution == null
                ? 'Not enough history'
                : _money(goal.impliedMonthlyContribution!),
          ),
          _OverviewRow(
            'Estimated completion',
            goal.estimatedCompletionDate == null
                ? 'Not enough data'
                : _monthYear(goal.estimatedCompletionDate!),
          ),
          if (goal.requiredMonthlyContribution != null) ...[
            _OverviewRow(
              'Required monthly (for ${_monthYear(goal.targetDate)})',
              _money(goal.requiredMonthlyContribution!),
            ),
            if (goal.contributionGap != null && goal.contributionGap! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Behind by ${_money(goal.contributionGap!)}/month',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CommitmentsCard extends StatelessWidget {
  const _CommitmentsCard({required this.commitments});

  final CommitmentBreakdown commitments;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverviewRow('Monthly commitments', _money(commitments.total)),
          const _Divider(),
          _OverviewRow(
            'Percentage of income',
            commitments.percentageOfIncome == null
                ? 'Income data unavailable'
                : '${commitments.percentageOfIncome!.toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 10),
          Text(
            'Breakdown',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          _OverviewRow('Loans', _money(commitments.loanEmi)),
          _OverviewRow('Bills', _money(commitments.recurringBills)),
          _OverviewRow('Subscriptions', _money(commitments.subscriptions)),
          _OverviewRow('Recurring', _money(commitments.otherRecurring)),
          if (commitments.excludedRecurringCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${commitments.excludedRecurringCount} recurring item'
                '${commitments.excludedRecurringCount == 1 ? '' : 's'} could not be '
                'included (unrecognized frequency).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.debt, required this.priority});

  final DebtOverview debt;
  final DebtPriorityResult priority;

  @override
  Widget build(BuildContext context) {
    if (!debt.hasDebt) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Text(
          "You have no active loans. That's the best possible debt position.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OverviewRow('Total outstanding debt', _money(debt.totalOutstanding)),
              const _Divider(),
              _OverviewRow('Monthly EMI burden', _money(debt.monthlyEmiBurden)),
              const _Divider(),
              _OverviewRow('Active loans', '${debt.activeLoanCount}'),
              const _Divider(),
              _OverviewRow(
                'EMI / income',
                debt.emiToIncomePercent == null
                    ? 'Income data unavailable'
                    : '${debt.emiToIncomePercent!.toStringAsFixed(0)}%',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final loan in debt.loans)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LoanDetailCard(loan: loan),
          ),
        if (priority.ranked.length > 1) _DebtPriorityCard(priority: priority),
      ],
    );
  }
}

class _LoanDetailCard extends StatelessWidget {
  const _LoanDetailCard({required this.loan});

  final LoanPlanningDetail loan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loan.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          _OverviewRow('Outstanding', _money(loan.outstandingAmount)),
          _OverviewRow('EMI', _money(loan.emiAmount)),
          _OverviewRow(
            'Interest rate',
            loan.interestRate == null ? 'Not enough data' : '${loan.interestRate!.toStringAsFixed(1)}%',
          ),
          _OverviewRow(
            'Remaining tenure',
            loan.remainingMonths == null
                ? 'Not enough data'
                : '${loan.remainingMonths} month${loan.remainingMonths == 1 ? '' : 's'}',
          ),
          _OverviewRow('Estimated payoff', _monthYear(loan.payoffDate)),
        ],
      ),
    );
  }
}

class _DebtPriorityCard extends StatelessWidget {
  const _DebtPriorityCard({required this.priority});

  final DebtPriorityResult priority;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended priority',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            priority.reason,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < priority.ranked.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${i + 1}. ${priority.ranked[i].name}'
                '${priority.ranked[i].interestRate != null && priority.method == DebtPriorityMethod.byInterestRate ? ' — ${priority.ranked[i].interestRate!.toStringAsFixed(1)}% interest' : ' — ${_money(priority.ranked[i].outstandingAmount)} outstanding'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SavingsPlanCard extends StatelessWidget {
  const _SavingsPlanCard({required this.plan});

  final SavingsPlan plan;

  @override
  Widget build(BuildContext context) {
    if (!plan.hasSufficientData) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Add a few transactions to see your savings plan.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverviewRow(
            'Current savings rate',
            plan.currentSavingsRatePercent == null
                ? 'No income data'
                : '${plan.currentSavingsRatePercent!.toStringAsFixed(0)}%',
          ),
          const _Divider(),
          _OverviewRow('Target', '${plan.recommendedTargetPercent.toStringAsFixed(0)}%'),
          const _Divider(),
          _OverviewRow(
            'Gap',
            plan.monthlyGapToTarget == null
                ? "You're at or above target"
                : '${_money(plan.monthlyGapToTarget!)}/month',
            valueColor: plan.monthlyGapToTarget != null ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(height: 8),
          Text(
            'Target is a general benchmark (part of the common 50/30/20 '
            'guideline), not personalized financial advice.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatIfCard extends StatefulWidget {
  const _WhatIfCard({required this.result});

  final FinancialPlanningResult result;

  @override
  State<_WhatIfCard> createState() => _WhatIfCardState();
}

class _WhatIfCardState extends State<_WhatIfCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final current = widget.result.overview.monthlySavings > 0
        ? widget.result.overview.monthlySavings
        : 0.0;
    _controller = TextEditingController(text: current.round().toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hypothetical = double.tryParse(_controller.text.trim()) ?? 0;
    final projection = hypothetical > 0
        ? FinancialPlanningCalculator.whatIf(
            result: widget.result,
            hypotheticalMonthlySavings: hypothetical,
          )
        : null;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What if I saved this much per month?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixText: '₹ ',
              filled: true,
              fillColor: AppColors.inputBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          if (projection != null) ...[
            const SizedBox(height: 14),
            if (projection.goalId != null)
              _WhatIfRow(
                label: '"${_goalTitleFor(projection.goalId!)}" completion',
                before: projection.goalDateBefore == null
                    ? 'Unknown'
                    : _monthYear(projection.goalDateBefore!),
                after: projection.goalDateAfter == null
                    ? 'Unknown'
                    : _monthYear(projection.goalDateAfter!),
              ),
            _WhatIfRow(
              label: 'Emergency fund completion',
              before: projection.emergencyFundMonthsBefore == null
                  ? 'Unknown'
                  : '${projection.emergencyFundMonthsBefore} months',
              after: projection.emergencyFundMonthsAfter == null
                  ? 'Unknown'
                  : '${projection.emergencyFundMonthsAfter} months',
            ),
          ],
        ],
      ),
    );
  }

  String _goalTitleFor(String goalId) {
    final match = widget.result.goalProjections.where((g) => g.goalId == goalId);
    return match.isEmpty ? 'Goal' : match.first.title;
  }
}

class _WhatIfRow extends StatelessWidget {
  const _WhatIfRow({required this.label, required this.before, required this.after});

  final String label;
  final String before;
  final String after;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                before,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                after,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.result});

  final FinancialPlanningResult result;

  @override
  Widget build(BuildContext context) {
    final milestones = FinancialPlanningCalculator.buildTimeline(result, DateTime.now());

    if (milestones.length <= 1) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No upcoming milestones can be calculated yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < milestones.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: i == 0 ? AppColors.primary : AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i != milestones.length - 1)
                      Container(width: 2, height: 32, color: AppColors.divider),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestones[i].label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          i == 0 ? 'Today' : _monthYear(milestones[i].date),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
