import '../models/csv_import_session.dart';
import 'csv_column_detector.dart';

/// CSV BANK STATEMENT IMPORT — PHASE 2. Header-based bank format
/// detection. This inspects ONLY column headers (never account numbers or
/// other row content) and scores each supported bank's known column
/// signature against the file's actual headers.
///
/// Deliberately conservative: a bank is only ever reported when its
/// signature terms are found with no ambiguity against every other
/// supported bank. Any file that doesn't clear this bar is reported as
/// [DetectedBankFormat.generic] — never a guessed bank name — per this
/// phase's explicit instruction not to fabricate a detection.
class CsvFormatDetector {
  CsvFormatDetector._();

  /// Each bank's distinctive header vocabulary (normalized the same way
  /// as [CsvColumnDetector.normalizeHeader]). These mirror the column
  /// layouts commonly published in Indian bank CSV/statement exports —
  /// used only as detection evidence, never as a requirement for parsing
  /// (parsing always goes through [CsvColumnDetector]'s generic aliases).
  static const Map<DetectedBankFormat, List<String>> _signatures = {
    DetectedBankFormat.hdfc: ['narration', 'chqrefno', 'valuedate', 'withdrawalamt', 'depositamt', 'closingbalance'],
    DetectedBankFormat.icici: ['transactiondate', 'transactionremarks', 'withdrawalamountinr', 'depositamountinr', 'balanceinr'],
    DetectedBankFormat.sbi: ['txndate', 'valuedate', 'debit', 'credit', 'refnochequeno'],
    DetectedBankFormat.axis: ['trandate', 'particulars', 'chqno', 'debit', 'credit'],
    DetectedBankFormat.kotak: ['transactiondate', 'description', 'withdrawaldr', 'depositcr'],
  };

  /// Minimum number of a bank's signature terms that must appear before
  /// it is even considered a candidate.
  static const int _minMatchesToConsider = 3;

  /// Minimum fraction of a bank's own signature that must be present to
  /// report it with confidence, rather than falling back to generic.
  static const double _minConfidenceToReport = 0.6;

  static CsvDetectionResult detect(List<String> headers) {
    final normalizedHeaders = headers.map(CsvColumnDetector.normalizeHeader).toSet();
    final detectedColumns = CsvColumnDetector.detectColumns(headers);
    final warnings = <String>[];

    final scores = <DetectedBankFormat, double>{};
    for (final entry in _signatures.entries) {
      final matches = entry.value.where(normalizedHeaders.contains).length;
      if (matches >= _minMatchesToConsider) {
        scores[entry.key] = matches / entry.value.length;
      }
    }

    DetectedBankFormat? best;
    var bestScore = 0.0;
    var tie = false;
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        best = entry.key;
        bestScore = entry.value;
        tie = false;
      } else if (entry.value == bestScore && entry.key != best) {
        tie = true;
      }
    }

    final requiresManualMapping = !detectedColumns.isUsable;
    if (requiresManualMapping) {
      warnings.add('Some required columns could not be identified automatically — please map them manually.');
    }

    if (best != null && !tie && bestScore >= _minConfidenceToReport) {
      return CsvDetectionResult(
        detectedBank: best,
        confidence: bestScore.clamp(0.0, 0.95),
        detectedColumns: detectedColumns,
        requiresManualMapping: requiresManualMapping,
        warnings: warnings,
      );
    }

    if (tie) {
      warnings.add('Header layout matches more than one known bank format — treating as a generic statement.');
    }

    return CsvDetectionResult(
      detectedBank: DetectedBankFormat.generic,
      confidence: bestScore.clamp(0.0, 0.4),
      detectedColumns: detectedColumns,
      requiresManualMapping: requiresManualMapping,
      warnings: warnings,
    );
  }
}
