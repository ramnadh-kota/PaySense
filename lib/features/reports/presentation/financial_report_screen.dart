import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/financial_report.dart';
import 'package:paysense/shared/providers/financial_report_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/financial_report_pdf_builder.dart';
import 'package:paysense/shared/utils/personal_cfo_insights.dart';
import 'package:paysense/shared/widgets/app_card.dart';

/// MILESTONE 7 — REPORT ACCESS IN THE APP. The smallest appropriate
/// integration: one new screen reached from the existing Reports screen
/// (`AppRoutes.reports` -> "Financial Report" entry), not a new
/// top-level navigation destination. Every figure shown here is read
/// directly from [financialReportProvider] (-> `FinancialReportEngine`)
/// — this screen computes nothing itself.
class FinancialReportScreen extends ConsumerStatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  ConsumerState<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends ConsumerState<FinancialReportScreen> {
  bool _isGeneratingPdf = false;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(selectedFinancialReportPeriodProvider);
    final report = ref.watch(financialReportProvider);
    final currencyCode = ref.watch(userProfileProvider).value?.currency.isNotEmpty == true
        ? ref.watch(userProfileProvider).value!.currency
        : 'INR';
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: CurrencyFormatter.symbolFor(currencyCode), decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Financial Report'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                children: [
                  _PeriodSelector(
                    selected: period,
                    onChanged: (value) => ref.read(selectedFinancialReportPeriodProvider.notifier).state = value,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${DateFormat('d MMM').format(report.periodStart)} - ${DateFormat('d MMM yyyy').format(report.periodEnd)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (!report.hasAnyActivity)
                    AppCard(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Not enough data for this period yet.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  else ...[
                    _SummaryCard(report: report, formatter: formatter),
                    const SizedBox(height: 16),
                    if (report.spendingByCategory.isNotEmpty) ...[
                      _SectionLabel('Spending by category'),
                      _CategoryCard(report: report, formatter: formatter),
                      const SizedBox(height: 16),
                    ],
                    if (report.budgetSummary != null) ...[
                      _SectionLabel('Budget performance'),
                      _BudgetCard(report: report, formatter: formatter),
                      const SizedBox(height: 16),
                    ],
                    if (report.recurringSummary != null && !report.recurringSummary!.isEmpty) ...[
                      _SectionLabel('Recurring commitments'),
                      _RecurringCard(report: report, formatter: formatter),
                      const SizedBox(height: 16),
                    ],
                    if (report.debt != null && report.debt!.hasDebt) ...[
                      _SectionLabel('Debt & EMI'),
                      _DebtCard(report: report, formatter: formatter),
                      const SizedBox(height: 16),
                    ],
                    if (report.goalProjections.isNotEmpty) ...[
                      _SectionLabel('Goal progress'),
                      _GoalCard(report: report),
                      const SizedBox(height: 16),
                    ],
                    if (report.healthResult != null) ...[
                      _SectionLabel('Financial health'),
                      _HealthCard(report: report),
                      const SizedBox(height: 16),
                    ],
                    if (report.safetySignals.isNotEmpty) ...[
                      _SectionLabel('Financial safety'),
                      _SafetyCard(report: report),
                      const SizedBox(height: 16),
                    ],
                    if (report.recommendations.isNotEmpty) ...[
                      _SectionLabel('Recommendations'),
                      _RecommendationsCard(report: report),
                      const SizedBox(height: 16),
                    ],
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isGeneratingPdf ? null : () => _generateAndShare(context, report),
                  icon: _isGeneratingPdf
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_isGeneratingPdf ? 'Preparing PDF...' : 'Download / Share PDF'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndShare(BuildContext context, FinancialReport report) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await FinancialReportPdfBuilder.build(report);
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'paysense_${report.period.name}_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = await _writeFile('${dir.path}/$filename', bytes);

      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'PaySense ${report.period.label} Financial Report'),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("We couldn't prepare the PDF. Please try again.")),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<File> _writeFile(String path, List<int> bytes) async {
    final file = File(path);
    return file.writeAsBytes(bytes);
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});
  final FinancialReportPeriod selected;
  final ValueChanged<FinancialReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: FinancialReportPeriod.values.map((p) {
        final isSelected = p == selected;
        return ChoiceChip(
          label: Text(p.label),
          selected: isSelected,
          onSelected: (_) => onChanged(p),
          selectedColor: AppColors.lightTeal,
          backgroundColor: AppColors.surface,
          labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
          side: BorderSide(color: isSelected ? AppColors.primary : AppColors.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        );
      }).toList(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report, required this.formatter});
  final FinancialReport report;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final rate = report.savingsRatePercent;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _Stat(label: 'Income', value: formatter.format(report.totalIncome), color: AppColors.success)),
              Expanded(child: _Stat(label: 'Expenses', value: formatter.format(report.totalExpenses), color: AppColors.danger)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Net cash flow',
                  value: formatter.format(report.netCashFlow),
                  color: report.netCashFlow >= 0 ? AppColors.success : AppColors.danger,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Savings rate',
                  value: rate == null ? 'Not enough data' : '${rate.toStringAsFixed(0)}%',
                  color: rate == null ? AppColors.textSecondary : (rate >= 0 ? AppColors.success : AppColors.danger),
                ),
              ),
            ],
          ),
          if (PersonalCfoInsights.amIOverspending(report).isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              PersonalCfoInsights.amIOverspending(report),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.report, required this.formatter});
  final FinancialReport report;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < report.spendingByCategory.take(6).length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text(report.spendingByCategory[i].categoryId, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
                Text(formatter.format(report.spendingByCategory[i].amount), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                SizedBox(width: 40, child: Text('${report.spendingByCategory[i].percentOfExpenses.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.report, required this.formatter});
  final FinancialReport report;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final summary = report.budgetSummary!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${formatter.format(summary.totalSpent)} of ${formatter.format(summary.totalBudget)} used (${summary.overallPercentageUsed.toStringAsFixed(0)}%)', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          if (report.budgetOverspend != null && report.budgetOverspend!.hasOverspend) ...[
            const SizedBox(height: 6),
            Text('${formatter.format(report.budgetOverspend!.totalOverspend)} over across ${report.budgetOverspend!.categoryCount} categories', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({required this.report, required this.formatter});
  final FinancialReport report;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final summary = report.recurringSummary!;
    return AppCard(
      child: Text(
        '${formatter.format(summary.totalMonthlyCost)}/month (${formatter.format(summary.totalAnnualCost)}/year) across ${summary.totalCommitmentCount} commitments',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.report, required this.formatter});
  final FinancialReport report;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final debt = report.debt!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${debt.activeLoanCount} active loan${debt.activeLoanCount == 1 ? '' : 's'} · ${formatter.format(debt.totalOutstanding)} outstanding', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('EMI ${formatter.format(debt.monthlyEmiBurden)}/month${debt.emiToIncomePercent != null ? ' (${debt.emiToIncomePercent!.toStringAsFixed(0)}% of income)' : ''}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.report});
  final FinancialReport report;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < report.goalProjections.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Text(report.goalProjections[i].title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            Text(PersonalCfoInsights.amIOnTrackForGoal(report.goalProjections[i]) ?? 'Not enough history yet to project this goal.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.report});
  final FinancialReport report;

  @override
  Widget build(BuildContext context) {
    final health = report.healthResult!;
    if (!health.hasSufficientData) {
      return AppCard(child: Text('Not enough data', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)));
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${health.overallScore}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary)),
              Text(' / 100', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(health.status.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          for (final insight in health.insights.take(3)) ...[
            const SizedBox(height: 6),
            Text('- ${insight.message}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.report});
  final FinancialReport report;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < report.safetySignals.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Text(report.safetySignals[i].title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            Text(report.safetySignals[i].explanation, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _RecommendationsCard extends StatelessWidget {
  const _RecommendationsCard({required this.report});
  final FinancialReport report;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < report.recommendations.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(report.recommendations[i], style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
