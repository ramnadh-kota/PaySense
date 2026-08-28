import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../providers/financial_report_bundle_provider.dart';
import 'reports_calculator.dart';

/// PDF-only currency formatting: the base14 PDF fonts this generator uses
/// (no bundled Unicode font, to avoid a network font-fetch dependency) can't
/// render ₹ (U+20B9) — it silently drops to a blank glyph, which is exactly
/// the "missing ₹ value" defect this report must never have. The ISO code
/// is used instead of a currency symbol for every currency, not just INR,
/// so this never has to be revisited if another symbol turns out to be
/// unsupported too.
String _pdfMoney(double amount, String currencyCode) =>
    '$currencyCode ${amount.toStringAsFixed(0)}';

/// Builds the PaySense Financial Report PDF from an already-computed
/// [FinancialReportBundle] — every figure comes straight from an existing,
/// already-tested calculator (Reports, Budgets, Goals, Recurring, Financial
/// Health, Safe-to-Spend, Fun Funds, Financial Actions). This file only
/// lays the numbers out on a page; it never computes a new one.
///
/// Uses `pw.MultiPage` throughout, which paginates automatically — long
/// transaction/category/goal lists correctly flow onto additional pages
/// instead of overflowing, and every table cell wraps long merchant/
/// category names rather than clipping them.
class FinancialReportPdfGenerator {
  FinancialReportPdfGenerator._();

  static final _primary = PdfColor.fromHex('#5B47FB');
  static final _danger = PdfColor.fromHex('#E5484D');
  static final _success = PdfColor.fromHex('#12B76A');
  static final _muted = PdfColor.fromHex('#6B7280');

  static Future<List<int>> build(FinancialReportBundle bundle) async {
    final doc = pw.Document();
    final money = (double amount) => _pdfMoney(amount, bundle.currencyCode);
    final dateFormat = DateFormat('d MMM yyyy');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
        header: (context) => _header(bundle, dateFormat),
        footer: (context) => _footer(context),
        build: (context) => [
          pw.SizedBox(height: 12),
          _overviewSection(bundle, money),
          pw.SizedBox(height: 16),
          _categorySection(bundle, money),
          pw.SizedBox(height: 16),
          _topExpensesSection(bundle, money, dateFormat),
          pw.SizedBox(height: 16),
          _walletSection(bundle, money),
          pw.SizedBox(height: 16),
          _budgetSection(bundle, money),
          pw.SizedBox(height: 16),
          _goalsSection(bundle, money),
          pw.SizedBox(height: 16),
          _recurringSection(bundle, money, dateFormat),
          pw.SizedBox(height: 16),
          _financialHealthSection(bundle),
          pw.SizedBox(height: 16),
          _safeToSpendSection(bundle, money),
          pw.SizedBox(height: 16),
          _funFundsSection(bundle, money),
          pw.SizedBox(height: 16),
          _recommendationsSection(bundle),
          pw.SizedBox(height: 20),
          _disclaimer(),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(FinancialReportBundle bundle, DateFormat fmt) {
    final range = bundle.reports.range;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'PaySense',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: _primary,
              ),
            ),
            pw.Text(
              'Generated ${fmt.format(bundle.generatedAt)}',
              style: pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Financial Report - ${bundle.reports.period.label}'
          '${bundle.userName.isNotEmpty ? ' - ${bundle.userName}' : ''}',
          style: pw.TextStyle(fontSize: 12, color: _muted),
        ),
        pw.Text(
          '${fmt.format(range.start)} to '
          '${fmt.format(range.end.subtract(const Duration(days: 1)))}',
          style: pw.TextStyle(fontSize: 10, color: _muted),
        ),
        pw.Divider(color: PdfColors.grey300, height: 16),
      ],
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 8, color: _muted),
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(
      title,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    ),
  );

  static pw.Widget _emptyNote(String message) => pw.Text(
    message,
    style: pw.TextStyle(fontSize: 10, color: _muted, fontStyle: pw.FontStyle.italic),
  );

  static pw.Widget _overviewSection(
    FinancialReportBundle bundle,
    String Function(double) money,
  ) {
    final r = bundle.reports;
    if (!r.hasAnyTransactions) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Financial Overview'),
          _emptyNote('Not enough data yet.'),
        ],
      );
    }
    final savingsRate = r.savingsRate;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Financial Overview'),
        pw.Row(
          children: [
            _statBox('Income', money(r.totalIncome), _success),
            _statBox('Expense', money(r.totalExpense), _danger),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _statBox(
              'Net Cash Flow',
              money(r.netCashFlow),
              r.netCashFlow >= 0 ? _success : _danger,
            ),
            _statBox(
              'Savings Rate',
              savingsRate == null ? 'Not enough data yet' : '${savingsRate.toStringAsFixed(0)}%',
              _primary,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _statBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _muted)),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _categorySection(
    FinancialReportBundle bundle,
    String Function(double) money,
  ) {
    final categories = bundle.reports.categoryBreakdown;
    if (categories.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Top Spending Categories'),
          _emptyNote('No expenses recorded in this period.'),
        ],
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Top Spending Categories'),
        pw.TableHelper.fromTextArray(
          headers: ['Category', 'Amount', '%'],
          data: categories
              .map(
                (c) => [
                  c.categoryId,
                  money(c.amount),
                  '${c.percentage.toStringAsFixed(0)}%',
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1),
          },
          border: null,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
      ],
    );
  }

  static pw.Widget _topExpensesSection(
    FinancialReportBundle bundle,
    String Function(double) money,
    DateFormat dateFormat,
  ) {
    final expenses = bundle.reports.topExpenses;
    if (expenses.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Largest Transactions'),
          _emptyNote('No expenses recorded in this period.'),
        ],
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Largest Transactions'),
        pw.TableHelper.fromTextArray(
          headers: ['Merchant', 'Category', 'Wallet', 'Date', 'Amount'],
          data: expenses
              .map(
                (e) => [
                  e.title,
                  e.categoryId,
                  e.walletName,
                  dateFormat.format(e.date),
                  money(e.amount),
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
          },
          border: null,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
      ],
    );
  }

  static pw.Widget _walletSection(
    FinancialReportBundle bundle,
    String Function(double) money,
  ) {
    final wallets = bundle.reports.walletBreakdown;
    if (wallets.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('By Wallet'),
          _emptyNote('Not enough data yet.'),
        ],
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('By Wallet'),
        pw.TableHelper.fromTextArray(
          headers: ['Wallet', 'In', 'Out', 'Net'],
          data: wallets
              .map(
                (w) => [
                  w.walletName,
                  money(w.income),
                  money(w.expense),
                  money(w.net),
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          border: null,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
      ],
    );
  }

  static pw.Widget _budgetSection(
    FinancialReportBundle bundle,
    String Function(double) money,
  ) {
    final b = bundle.budgetTotals;
    if (b.totalBudget <= 0) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Budget Performance'),
          _emptyNote('Not enough data yet.'),
        ],
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Budget Performance'),
        pw.Text(
          '${money(b.totalSpent)} of ${money(b.totalBudget)} spent '
          '(${b.percentageUsed.toStringAsFixed(0)}%)',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          b.remainingBudget < 0
              ? '${money(-b.remainingBudget)} over budget'
              : 'Remaining: ${money(b.remainingBudget)}',
          style: pw.TextStyle(
            fontSize: 10,
            color: b.remainingBudget < 0 ? _danger : _muted,
          ),
        ),
      ],
    );
  }

  static pw.Widget _goalsSection(
    FinancialReportBundle bundle,
    String Function(double) money,
  ) {
    final goals = bundle.goals;
    if (goals.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Goal Progress'),
          _emptyNote('Not enough data yet.'),
        ],
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Goal Progress'),
        pw.TableHelper.fromTextArray(
          headers: ['Goal', 'Saved', 'Target', 'Progress'],
          data: goals
              .map(
                (g) => [
                  g.title,
                  money(g.currentAmount),
                  money(g.targetAmount),
                  '${g.progressPercentage.clamp(0, 100).toStringAsFixed(0)}%',
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          border: null,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
      ],
    );
  }

  static pw.Widget _recurringSection(
    FinancialReportBundle bundle,
    String Function(double) money,
    DateFormat dateFormat,
  ) {
    final items = bundle.upcomingRecurring;
    if (items.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Upcoming Recurring Obligations'),
          _emptyNote('No upcoming recurring payments in the next 7 days.'),
        ],
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Upcoming Recurring Obligations'),
        pw.TableHelper.fromTextArray(
          headers: ['Title', 'Type', 'Due', 'Amount'],
          data: items
              .map(
                (i) => [
                  i.title,
                  i.transactionType,
                  dateFormat.format(i.nextDueDate),
                  money(i.amount),
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          border: null,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
      ],
    );
  }

  static pw.Widget _financialHealthSection(FinancialReportBundle bundle) {
    final h = bundle.financialHealth;
    if (!h.hasSufficientData) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Financial Health Score'),
          _emptyNote('Not enough data yet.'),
        ],
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Financial Health Score'),
        pw.Text(
          '${h.overallScore}/100',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _primary,
          ),
        ),
        if (h.insights.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          ...h.insights
              .take(3)
              .map(
                (insight) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    '- ${insight.message}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ),
        ],
      ],
    );
  }

  static pw.Widget _safeToSpendSection(
    FinancialReportBundle bundle,
    String Function(double) money,
  ) {
    final s = bundle.safeToSpend;
    if (!s.hasSufficientData) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Safe-to-Spend'),
          _emptyNote('Not enough data yet.'),
        ],
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Safe-to-Spend'),
        pw.Text(
          s.isShortfall
              ? '${money(s.shortfall)} short for upcoming commitments'
              : '${money(s.safeToSpend)} safe to spend over the next '
                    '${s.windowDays} days (${money(s.dailySafeToSpend)}/day)',
          style: pw.TextStyle(
            fontSize: 10,
            color: s.isShortfall ? _danger : null,
          ),
        ),
      ],
    );
  }

  static pw.Widget _funFundsSection(
    FinancialReportBundle bundle,
    String Function(double) money,
  ) {
    final f = bundle.funFunds;
    if (!f.hasSufficientData) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Fun Funds'),
          _emptyNote('Not enough data yet.'),
        ],
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Fun Funds'),
        pw.Text(
          '${money(f.remaining)} remaining of ${money(f.monthlyAvailable)} '
          'this month (${f.utilizationPercent.clamp(0, 999).toStringAsFixed(0)}% used)',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  static pw.Widget _recommendationsSection(FinancialReportBundle bundle) {
    final actions = bundle.actionPlan.actions;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recommendations'),
        for (final action in actions)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  action.explanation,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  action.recommendedAction,
                  style: pw.TextStyle(fontSize: 9, color: _muted),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _disclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        'This report is generated entirely from data you\'ve recorded in '
        'PaySense and stays on your device. It is provided for '
        'informational purposes only and is not financial, tax, or '
        'investment advice.',
        style: pw.TextStyle(fontSize: 8, color: _muted, fontStyle: pw.FontStyle.italic),
      ),
    );
  }
}
