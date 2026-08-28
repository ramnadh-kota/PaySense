import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/features/reports/presentation/widgets/reports_income_expense_chart.dart';
import 'package:paysense/shared/providers/financial_report_bundle_provider.dart';
import 'package:paysense/shared/providers/reports_provider.dart';
import 'package:paysense/shared/providers/transaction_filter_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/financial_report_file_writer.dart';
import 'package:paysense/shared/utils/reports_calculator.dart';
import 'package:paysense/shared/utils/transaction_filters.dart';
import 'package:paysense/shared/widgets/app_card.dart';

/// Read-only financial reporting: "Where did my money go?" — every figure
/// is derived from already-stored transactions/wallets via
/// [ReportsCalculator]. Never creates, edits, or deletes a transaction,
/// wallet, budget, goal, or recurring transaction.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedReportPeriodProvider);
    final result = ref.watch(reportsResultProvider);

    final currencyCode =
        ref.watch(userProfileProvider).value?.currency.isNotEmpty == true
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
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF report',
            onPressed: result.hasAnyTransactions
                ? () => _handleExportPdf(context, ref)
                : null,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            _PeriodSelector(
              selected: period,
              onChanged: (value) =>
                  ref.read(selectedReportPeriodProvider.notifier).state = value,
            ),
            const SizedBox(height: 20),
            if (!result.hasAnyTransactions)
              _NoDataState(period: period)
            else ...[
              _FinancialSummaryCard(result: result, formatter: currencyFormatter),
              const SizedBox(height: 20),
              _SectionLabel('Income vs Expense'),
              AppCard(
                child: ReportsIncomeExpenseChart(
                  monthlyTotals: result.monthlyTotals,
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel('Top Spending Categories'),
              _CategorySpendingCard(result: result, formatter: currencyFormatter),
              const SizedBox(height: 20),
              _SectionLabel('Top Expenses'),
              _TopExpensesCard(
                result: result,
                formatter: currencyFormatter,
                onViewAll: result.totalExpense > 0
                    ? () => _viewAllExpenses(context, ref, result)
                    : null,
              ),
              const SizedBox(height: 20),
              _SectionLabel('By Wallet'),
              _WalletAnalysisCard(result: result, formatter: currencyFormatter),
              const SizedBox(height: 20),
              _SectionLabel('Compared to Previous Period'),
              _MonthOverMonthCard(result: result, formatter: currencyFormatter),
              if (result.insights.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionLabel('Insights'),
                _InsightsCard(insights: result.insights),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Same save-to-documents-directory-and-show-the-path pattern Settings'
  /// "Export financial data" already uses — the PDF stays entirely
  /// on-device, no new sharing mechanism/dependency introduced for it.
  Future<void> _handleExportPdf(BuildContext context, WidgetRef ref) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? resultPath;
    String? errorMessage;
    try {
      final bundle = ref.read(financialReportBundleProvider);
      resultPath = await FinancialReportFileWriter.instance.writeToFile(
        bundle,
      );
    } catch (e) {
      errorMessage = e.toString();
    }

    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(errorMessage == null ? 'Report saved' : 'Export failed'),
        content: Text(
          errorMessage == null
              ? 'Your financial report was saved to:\n\n$resultPath\n\n'
                  'The file stays on this device — PaySense doesn\'t upload '
                  'or share it anywhere.'
              : 'Something went wrong: $errorMessage',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Reuses the existing Transactions screen + its filter architecture
  /// (type=expense, custom date range = the selected report period)
  /// instead of building a second "all expenses" screen.
  void _viewAllExpenses(BuildContext context, WidgetRef ref, ReportsResult result) {
    final notifier = ref.read(transactionFilterProvider.notifier);
    notifier.setType(TransactionTypeFilter.expense);
    notifier.setCustomDateRange(
      result.range.start,
      result.range.end.subtract(const Duration(days: 1)),
    );
    Navigator.of(context).pushNamed(AppRoutes.transactions);
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});

  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ReportPeriod.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final period = ReportPeriod.values[index];
          final isSelected = period == selected;
          return ChoiceChip(
            label: Text(period.label),
            selected: isSelected,
            onSelected: (_) => onChanged(period),
            selectedColor: AppColors.lightTeal,
            backgroundColor: AppColors.surface,
            labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.divider,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}

class _FinancialSummaryCard extends StatelessWidget {
  const _FinancialSummaryCard({required this.result, required this.formatter});

  final ReportsResult result;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final savingsRate = result.savingsRate;
    final isPositiveNet = result.netCashFlow >= 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Income',
                  value: formatter.format(result.totalIncome),
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Expense',
                  value: formatter.format(result.totalExpense),
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Net Cash Flow',
                  value: formatter.format(result.netCashFlow),
                  color: isPositiveNet ? AppColors.success : AppColors.danger,
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Savings Rate',
                  value: savingsRate == null
                      ? '—'
                      : '${savingsRate.toStringAsFixed(0)}%',
                  color: savingsRate == null
                      ? AppColors.textSecondary
                      : (savingsRate >= 0 ? AppColors.success : AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

List<Color> get _reportsPalette => <Color>[
  AppColors.primary,
  AppColors.secondary,
  AppColors.warning,
  AppColors.danger,
  AppColors.success,
  Color(0xFF0EA5E9),
  Color(0xFFEC4899),
  Color(0xFF8B5CF6),
];

class _CategorySpendingCard extends StatelessWidget {
  const _CategorySpendingCard({required this.result, required this.formatter});

  final ReportsResult result;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    if (result.categoryBreakdown.isEmpty) {
      return AppCard(
        child: Text(
          'No expenses recorded in this period.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < result.categoryBreakdown.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _CategoryRow(
              breakdown: result.categoryBreakdown[i],
              color: _reportsPalette[i % _reportsPalette.length],
              formatter: formatter,
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.breakdown,
    required this.color,
    required this.formatter,
  });

  final ReportCategoryBreakdown breakdown;
  final Color color;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                breakdown.categoryId,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatter.format(breakdown.amount),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 42,
              child: Text(
                '${breakdown.percentage.toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (breakdown.percentage / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.background,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _TopExpensesCard extends StatelessWidget {
  const _TopExpensesCard({
    required this.result,
    required this.formatter,
    required this.onViewAll,
  });

  final ReportsResult result;
  final NumberFormat formatter;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    if (result.topExpenses.isEmpty) {
      return AppCard(
        child: Text(
          'No expenses recorded in this period.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < result.topExpenses.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider, indent: 16, endIndent: 16),
            _TopExpenseTile(expense: result.topExpenses[i], formatter: formatter),
          ],
          if (onViewAll != null) ...[
            Divider(height: 1, color: AppColors.divider),
            InkWell(
              onTap: onViewAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'View all',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopExpenseTile extends StatelessWidget {
  const _TopExpenseTile({required this.expense, required this.formatter});

  final ReportTopExpense expense;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${expense.categoryId} · ${expense.walletName} · '
                  '${DateFormat('d MMM').format(expense.date)}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatter.format(expense.amount),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletAnalysisCard extends StatelessWidget {
  const _WalletAnalysisCard({required this.result, required this.formatter});

  final ReportsResult result;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    if (result.walletBreakdown.isEmpty) {
      return AppCard(
        child: Text(
          'No wallets to show yet.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < result.walletBreakdown.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider, indent: 16, endIndent: 16),
            _WalletRow(breakdown: result.walletBreakdown[i], formatter: formatter),
          ],
        ],
      ),
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({required this.breakdown, required this.formatter});

  final ReportWalletBreakdown breakdown;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final isPositive = breakdown.net >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  breakdown.walletName,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'In ${formatter.format(breakdown.income)} · '
                  'Out ${formatter.format(breakdown.expense)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isPositive ? '+' : ''}${formatter.format(breakdown.net)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isPositive ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthOverMonthCard extends StatelessWidget {
  const _MonthOverMonthCard({required this.result, required this.formatter});

  final ReportsResult result;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final comparison = result.comparison;
    if (comparison.previousIncome == 0 && comparison.previousExpense == 0) {
      return AppCard(
        child: Text(
          'No data from the previous period to compare with yet.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          _ChangeRow(label: 'Income', change: comparison.incomeChange, higherIsGood: true),
          const SizedBox(height: 14),
          _ChangeRow(label: 'Expense', change: comparison.expenseChange, higherIsGood: false),
          const SizedBox(height: 14),
          _ChangeRow(label: 'Net', change: comparison.netChange, higherIsGood: true),
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.label,
    required this.change,
    required this.higherIsGood,
  });

  final String label;
  final ReportChange change;
  final bool higherIsGood;

  @override
  Widget build(BuildContext context) {
    String display;
    Color color;
    if (change.percentage == null) {
      display = change.isNew ? 'New this period' : '—';
      color = AppColors.textSecondary;
    } else {
      final pct = change.percentage!;
      final isGood = higherIsGood ? pct >= 0 : pct <= 0;
      display = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%';
      color = pct == 0
          ? AppColors.textSecondary
          : (isGood ? AppColors.success : AppColors.danger);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          display,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < insights.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insights[i],
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

class _NoDataState extends StatelessWidget {
  const _NoDataState({required this.period});

  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.insert_chart_outlined_rounded, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            'No transactions for ${period.label.toLowerCase()}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add an income or expense, or try a different period.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
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
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
