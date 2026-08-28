import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../providers/financial_report_bundle_provider.dart';
import 'financial_report_pdf_generator.dart';

/// Writes the Financial Report PDF to the app's own documents directory —
/// the same on-device-only save pattern [FinancialDataExporter] already
/// uses for the JSON export. Nothing is uploaded or shared off the app
/// sandbox; the resulting path is shown to the user via the existing
/// platform file-location mechanism, not a new sharing dependency.
class FinancialReportFileWriter {
  FinancialReportFileWriter._();

  static final FinancialReportFileWriter instance =
      FinancialReportFileWriter._();

  Future<String> writeToFile(FinancialReportBundle bundle) async {
    final bytes = await FinancialReportPdfGenerator.build(bundle);

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final periodSlug = bundle.reports.period.name;
    final file = File(
      '${directory.path}/paysense_report_${periodSlug}_$timestamp.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
