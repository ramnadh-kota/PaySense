import 'package:hive/hive.dart';

import '../models/decision_memory_record.dart';

/// Phase 6E — Decision Memory Repository
///
/// Local, deterministic persistence for spending decision records made via
/// PaySense Decision Coach. Uses Hive storage with toMap/fromMap serialization.
/// Purely on-device, zero network or external dependencies.
class DecisionMemoryRepository {
  DecisionMemoryRepository._();

  static final DecisionMemoryRepository instance =
      DecisionMemoryRepository._();

  static const String boxName = 'decision_memory';

  Future<Box> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return Hive.openBox(boxName);
  }

  /// Records a new decision or updates an existing one.
  Future<void> recordDecision(DecisionMemoryRecord record) async {
    final box = await _box();
    await box.put(record.id, record.toMap());
  }

  /// Retrieves all recorded decisions sorted by timestamp (newest first).
  Future<List<DecisionMemoryRecord>> getAll() async {
    final box = await _box();
    if (box.isEmpty) return const [];

    final records = <DecisionMemoryRecord>[];
    for (final raw in box.values) {
      if (raw is Map) {
        try {
          records.add(DecisionMemoryRecord.fromMap(raw));
        } catch (_) {
          // Ignore malformed entries gracefully
        }
      }
    }

    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List<DecisionMemoryRecord>.unmodifiable(records);
  }

  /// Retrieves the most recent decisions up to [limit] (newest first).
  Future<List<DecisionMemoryRecord>> getRecentDecisions({
    int limit = 20,
  }) async {
    final all = await getAll();
    if (limit <= 0) return const [];
    return all.take(limit).toList();
  }

  /// Retrieves decisions matching [categoryId] (case-insensitive, newest first).
  Future<List<DecisionMemoryRecord>> getByCategory(
    String categoryId, {
    int limit = 20,
  }) async {
    final normalized = categoryId.trim().toLowerCase();
    final all = await getAll();
    final filtered = all.where((r) => r.categoryId.toLowerCase() == normalized);
    if (limit <= 0) return const [];
    return filtered.take(limit).toList();
  }

  /// Retrieves decisions similar to a prospective purchase based on category
  /// and optional amount proximity (default ±30% tolerance).
  Future<List<DecisionMemoryRecord>> getSimilarDecisions({
    required String categoryId,
    double? amount,
    double tolerancePercentage = 30.0,
    int limit = 10,
  }) async {
    final categoryMatches = await getByCategory(categoryId, limit: 100);
    if (categoryMatches.isEmpty) return const [];

    if (amount == null || amount <= 0) {
      return categoryMatches.take(limit).toList();
    }

    final safeTolerance =
        tolerancePercentage.clamp(0.0, 500.0) / 100.0; // as fraction
    final minAmount = amount * (1.0 - safeTolerance);
    final maxAmount = amount * (1.0 + safeTolerance);

    final similar = categoryMatches.where((r) {
      return r.amount >= minAmount && r.amount <= maxAmount;
    }).toList();

    return similar.take(limit).toList();
  }

  /// Retrieves a specific decision by its unique [id].
  Future<DecisionMemoryRecord?> getById(String id) async {
    final box = await _box();
    final raw = box.get(id);
    if (raw is Map) {
      try {
        return DecisionMemoryRecord.fromMap(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Deletes a specific decision by its unique [id].
  Future<void> deleteDecision(String id) async {
    final box = await _box();
    await box.delete(id);
  }

  /// Clears all decision memory records.
  Future<void> clearAll() async {
    final box = await _box();
    await box.clear();
  }
}
