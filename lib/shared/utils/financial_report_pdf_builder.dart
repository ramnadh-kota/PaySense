import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/financial_report.dart';

/// MILESTONE 6 — DOWNLOADABLE PDF FINANCIAL REPORT. A pure rendering
/// layer over an already-computed [FinancialReport] (see
/// `FinancialReportEngine`) — this class performs NO financial
/// calculation of its own; every figure it prints is read directly off
/// the report.
///
/// Currency is printed as "Rs." rather than "₹": the `pdf` package's
/// default base-14 font (Helvetica) has no glyph for U+20B9 (the Indian
/// Rupee sign), and bundling a custom font just for one symbol isn't
/// justified for this milestone — "Rs." renders correctly with zero
/// added complexity/dependencies.
///
/// DATA INTEGRITY RULE: every section either prints a real value traced
/// to [report] or prints "Not enough data" — never a fabricated number,
/// mirroring the exact rule [FinancialReportEngine] itself follows.
class FinancialReportPdfBuilder {
  FinancialReportPdfBuilder._();

  static String _money(double v) => 'Rs. ${v.toStringAsFixed(0)}';
  static String _date(DateTime d) => DateFormat('d MMM yyyy').format(d);

  /// Every OTHER string on this page is composed fresh with [_money], so
  /// it's already PDF-font-safe. Strings reused as-is from other engines
  /// (FinancialSafetyEngine/PainOfPayingEngine/FinancialHealthCalculator
  /// message text — reused deliberately, not reformatted, per the
  /// "don't duplicate calculations" rule) were written for the in-app UI,
  /// which uses a font that DOES support "₹"/"—"; the PDF's default
  /// Helvetica does not. This only substitutes characters for rendering —
  /// it never touches a number or changes what the text says.
  static String _pdfSafe(String text) =>
      text.replaceAll('₹', 'Rs. ').replaceAll('—', ' - ').replaceAll('–', '-');

  static final _titleStyle = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
  static final _sectionStyle = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1F2937));
  static final _bodyStyle = const pw.TextStyle(fontSize: 10);
  static final _mutedStyle = pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF6B7280));
  static final _labelStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);

  static Future<Uint8List> build(FinancialReport report) async {
    final doc = pw.Document(title: 'PaySense Financial Report');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => context.pageNumber == 1 ? _coverHeader(report) : _runningHeader(report),
        footer: (context) => _footer(context),
        build: (context) => [
          _executiveSummary(report),
          _sectionSpacer(),
          _incomeAndCashFlow(report),
          _sectionSpacer(),
          _spendingAnalysis(report),
          _sectionSpacer(),
          _budgetPerformance(report),
          _sectionSpacer(),
          _recurringCommitments(report),
          _sectionSpacer(),
          _debtOverview(report),
          _sectionSpacer(),
          _goalProgress(report),
          _sectionSpacer(),
          _financialHealth(report),
          _sectionSpacer(),
          _financialSafety(report),
          _sectionSpacer(),
          _spendingBehaviour(report),
          _sectionSpacer(),
          _recommendations(report),
          _sectionSpacer(),
          _disclaimer(),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _sectionSpacer() => pw.SizedBox(height: 16);

  static pw.Widget _coverHeader(FinancialReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('PaySense', style: _titleStyle),
        pw.SizedBox(height: 2),
        pw.Text('Personal Financial Report', style: pw.TextStyle(fontSize: 12, color: PdfColor.fromInt(0xFF6B7280))),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${report.period.label} report · ${_date(report.periodStart)} to ${_date(report.periodEnd)}', style: _mutedStyle),
            pw.Text('Generated ${_date(report.generatedAt)}', style: _mutedStyle),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: PdfColor.fromInt(0xFFE5E7EB)),
      ],
    );
  }

  static pw.Widget _runningHeader(FinancialReport report) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('PaySense - ${report.period.label} Report', style: _mutedStyle),
        pw.Text(_date(report.generatedAt), style: _mutedStyle),
      ],
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('PaySense', style: _mutedStyle),
        pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: _mutedStyle),
      ],
    );
  }

  static pw.Widget _section(String title, pw.Widget content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: _sectionStyle),
        pw.SizedBox(height: 6),
        content,
      ],
    );
  }

  static pw.Widget _noData() => pw.Text('Not enough data', style: _mutedStyle);

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label, style: _bodyStyle), pw.Text(value, style: _labelStyle)],
      ),
    );
  }

  // ---- 1. Executive Summary ----
  static pw.Widget _executiveSummary(FinancialReport report) {
    if (!report.hasAnyActivity) {
      return _section('1. Executive Summary', _noData());
    }
    final rate = report.savingsRatePercent;
    return _section(
      '1. Executive Summary',
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _kv('Total income', _money(report.totalIncome)),
          _kv('Total expenses', _money(report.totalExpenses)),
          _kv('Net cash flow', _money(report.netCashFlow)),
          _kv('Savings rate', rate == null ? 'Not enough data' : '${rate.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }

  // ---- 2. Income & Cash Flow ----
  static pw.Widget _incomeAndCashFlow(FinancialReport report) {
    return _section(
      '2. Income & Cash Flow',
      report.hasAnyActivity
          ? pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kv('Income', _money(report.totalIncome)),
                _kv('Expenses', _money(report.totalExpenses)),
                _kv('Net cash flow', _money(report.netCashFlow)),
              ],
            )
          : _noData(),
    );
  }

  // ---- 3. Spending Analysis ----
  static pw.Widget _spendingAnalysis(FinancialReport report) {
    if (report.spendingByCategory.isEmpty && report.largestTransactions.isEmpty) {
      return _section('3. Spending Analysis', _noData());
    }
    return _section(
      '3. Spending Analysis',
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (report.spendingByCategory.isNotEmpty) ...[
            pw.Text('By category', style: _labelStyle),
            pw.SizedBox(height: 4),
            for (final c in report.spendingByCategory.take(8))
              _kv(_pdfSafe(c.categoryId), '${_money(c.amount)} (${c.percentOfExpenses.toStringAsFixed(0)}%)'),
            pw.SizedBox(height: 8),
          ],
          if (report.largestTransactions.isNotEmpty) ...[
            pw.Text('Largest transactions', style: _labelStyle),
            pw.SizedBox(height: 4),
            for (final t in report.largestTransactions)
              _kv('${_pdfSafe(t.title)} (${_date(t.createdAt)})', _money(t.amount)),
          ],
        ],
      ),
    );
  }

  // ---- 4. Budget Performance ----
  static pw.Widget _budgetPerformance(FinancialReport report) {
    final summary = report.budgetSummary;
    if (summary == null) {
      return _section('4. Budget Performance', _noData());
    }
    return _section(
      '4. Budget Performance',
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _kv('Total budgeted', _money(summary.totalBudget)),
          _kv('Total spent', _money(summary.totalSpent)),
          _kv('Remaining', _money(summary.totalRemaining)),
          _kv('Used', '${summary.overallPercentageUsed.toStringAsFixed(0)}%'),
          if (report.budgetOverspend != null && report.budgetOverspend!.hasOverspend)
            _kv('Over budget by', '${_money(report.budgetOverspend!.totalOverspend)} across ${report.budgetOverspend!.categoryCount} categories'),
        ],
      ),
    );
  }

  // ---- 5. Recurring Commitments ----
  static pw.Widget _recurringCommitments(FinancialReport report) {
    final summary = report.recurringSummary;
    if (summary == null || summary.isEmpty) {
      return _section('5. Recurring Commitments', _noData());
    }
    return _section(
      '5. Recurring Commitments',
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _kv('Monthly commitment total', _money(summary.totalMonthlyCost)),
          _kv('Annual commitment total', _money(summary.totalAnnualCost)),
          pw.SizedBox(height: 6),
          if (report.upcomingBills.isNotEmpty || report.upcomingPayments.isNotEmpty) ...[
            pw.Text('Upcoming in this period', style: _labelStyle),
            pw.SizedBox(height: 4),
            for (final b in report.upcomingBills) _kv('${_pdfSafe(b.title)} - due ${_date(b.dueDate)}', _money(b.amount)),
            for (final p in report.upcomingPayments) _kv('${_pdfSafe(p.title)} - due ${_date(p.nextDueDate)}', _money(p.amount)),
          ],
        ],
      ),
    );
  }

  // ---- 6. Debt & EMI Overview ----
  static pw.Widget _debtOverview(FinancialReport report) {
    final debt = report.debt;
    if (debt == null || !debt.hasDebt) {
      return _section('6. Debt & EMI Overview', _noData());
    }
    return _section(
      '6. Debt & EMI Overview',
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _kv('Active loans', '${debt.activeLoanCount}'),
          _kv('Total outstanding', _money(debt.totalOutstanding)),
          _kv('Monthly EMI burden', _money(debt.monthlyEmiBurden)),
          _kv('EMI as % of income', debt.emiToIncomePercent == null ? 'Not enough data' : '${debt.emiToIncomePercent!.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }

  // ---- 7. Goal Progress ----
  static pw.Widget _goalProgress(FinancialReport report) {
    if (report.goalProjections.isEmpty) {
      return _section('7. Goal Progress', _noData());
    }
    return _section(
      '7. Goal Progress',
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final g in report.goalProjections) ...[
            pw.Text(_pdfSafe(g.title), style: _labelStyle),
            _kv('Progress', '${_money(g.currentAmount)} of ${_money(g.targetAmount)}'),
            _kv('Remaining', _money(g.remainingAmount)),
            if (g.estimatedCompletionDate != null) _kv('Estimated completion', _date(g.estimatedCompletionDate!)),
            _kv('Status', g.status.name),
            pw.SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  // ---- 8. Financial Health ----
  static pw.Widget _financialHealth(FinancialReport report) {
    final health = report.healthResult;
    if (health == null || !health.hasSufficientData) {
      return _section('8. Financial Health', _noData());
    }
    return _section(
      '8. Financial Health',
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _kv('Score', '${health.overallScore} / 100'),
          _kv('Status', health.status.name),
          pw.SizedBox(height: 6),
          if (health.insights.isNotEmpty) ...[
            pw.Text('Contributing factors', style: _labelStyle),
            pw.SizedBox(height: 4),
            for (final i in health.insights) pw.Text('- ${_pdfSafe(i.message)}', style: _bodyStyle),
            pw.SizedBox(height: 6),
          ],
          if (health.recommendations.isNotEmpty) ...[
            pw.Text('Improvement opportunities', style: _labelStyle),
            pw.SizedBox(height: 4),
            for (final r in health.recommendations) pw.Text('- ${_pdfSafe(r)}', style: _bodyStyle),
          ],
        ],
      ),
    );
  }

  // ---- 9. Financial Safety ----
  static pw.Widget _financialSafety(FinancialReport report) {
    if (report.safetySignals.isEmpty) {
      return _section('9. Financial Safety', pw.Text('No safety concerns detected in your recorded data.', style: _bodyStyle));
    }
    return _section(
      '9. Financial Safety',
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final alert in report.safetySignals) ...[
            pw.Text(_pdfSafe(alert.title), style: _labelStyle),
            pw.Text(_pdfSafe(alert.explanation), style: _bodyStyle),
            pw.Text(_pdfSafe(alert.recommendedAction), style: _mutedStyle),
            pw.SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  // ---- 10. Spending Behaviour ----
  static pw.Widget _spendingBehaviour(FinancialReport report) {
    if (report.notableSpendingBehaviors.isEmpty) {
      return _section('10. Spending Behaviour', pw.Text('No unusual spending patterns detected in your recorded data.', style: _bodyStyle));
    }
    return _section(
      '10. Spending Behaviour',
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final b in report.notableSpendingBehaviors) ...[
            pw.Text(_pdfSafe(b.headline), style: _labelStyle),
            for (final s in b.signals) pw.Text('- ${_pdfSafe(s.detail)}', style: _bodyStyle),
            pw.SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  // ---- 11. Recommendations ----
  static pw.Widget _recommendations(FinancialReport report) {
    if (report.recommendations.isEmpty) {
      return _section('11. Recommendations', pw.Text('Nothing needs your attention right now.', style: _bodyStyle));
    }
    return _section(
      '11. Recommendations',
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [for (final r in report.recommendations) pw.Text('- ${_pdfSafe(r)}', style: _bodyStyle)],
      ),
    );
  }

  // ---- 12. Disclaimer ----
  static pw.Widget _disclaimer() {
    return _section(
      '12. Disclaimer',
      pw.Text(
        'This report is generated automatically from data you recorded in PaySense. It is provided for personal '
        'awareness only and is not financial, investment, tax, or legal advice, and not a credit assessment. '
        'PaySense is not a licensed financial advisor. Figures reflect only what has been entered into the app '
        'and may not reflect your complete financial position.',
        style: _mutedStyle,
      ),
    );
  }
}
