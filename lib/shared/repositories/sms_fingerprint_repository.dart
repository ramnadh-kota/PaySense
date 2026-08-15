import 'package:hive/hive.dart';

/// Tracks which SMS fingerprints have already been processed (auto-added,
/// sent to review, or ignored as low-confidence/non-financial), so a
/// re-delivered or repeatedly-fetched copy of the same SMS is never acted
/// on twice — the guarantee has to survive app restarts and the native
/// receiver re-broadcasting, which is why this lives in Hive rather than
/// in-memory.
///
/// Deliberately the smallest architecture-consistent mechanism for this:
/// one untyped Hive box holding a single bounded list of strings, matching
/// the existing pattern of small flags/lists in [AppSettingsRepository]
/// rather than a dedicated typed box per fingerprint.
class SmsFingerprintRepository {
  SmsFingerprintRepository._();

  static final SmsFingerprintRepository instance = SmsFingerprintRepository._();

  static const String _boxName = 'sms_processed_fingerprints';
  static const String _key = 'processed';

  /// Caps how many fingerprints are retained — old bank SMS are extremely
  /// unlikely to ever be redelivered once this many newer ones have been
  /// processed, so this bounds memory/storage without a real risk of
  /// duplicate transactions slipping through.
  static const int _maxRetained = 2000;

  Box get _box => Hive.box(_boxName);

  bool isProcessed(String fingerprint) {
    final processed = _box.get(_key) as List<Object?>? ?? const [];
    return processed.contains(fingerprint);
  }

  Future<void> markProcessed(String fingerprint) async {
    final processed = (_box.get(_key) as List<Object?>? ?? const [])
        .cast<String>()
        .toList();
    if (processed.contains(fingerprint)) {
      return;
    }
    processed.add(fingerprint);
    final bounded = processed.length > _maxRetained
        ? processed.sublist(processed.length - _maxRetained)
        : processed;
    await _box.put(_key, bounded);
  }
}
