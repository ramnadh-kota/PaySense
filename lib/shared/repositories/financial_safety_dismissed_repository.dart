import 'package:hive/hive.dart';

import '../models/financial_safety_alert.dart';

/// FINANCIAL SAFETY 2.0 — persists the lifecycle state (dismissed/
/// snoozed/resolved) of each alert id (see `FinancialSafetyAlert.id`,
/// keyed by type), so a handled alert doesn't reappear every time the
/// deterministic engine recomputes it. Same box/key this repository has
/// always used (`financial_safety_dismissed_alerts` / `dismissedIds`) for
/// the legacy dismissed-id Set, PLUS a new `alertStates` key holding the
/// richer per-alert state this class now also tracks — both are kept in
/// sync by every mutating method here so existing callers (and
/// `AccountDeletionService.deleteEverythingLocally`, which only knows
/// about [clearAll]) keep working unchanged.
class FinancialSafetyDismissedRepository {
  FinancialSafetyDismissedRepository._();

  static final FinancialSafetyDismissedRepository instance = FinancialSafetyDismissedRepository._();

  static const _boxName = 'financial_safety_dismissed_alerts';
  static const _legacyKey = 'dismissedIds';
  static const _statesKey = 'alertStates';

  Future<Box> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  Future<Set<String>> getDismissedIds() async {
    final states = await getStates();
    return states.values
        .where((s) => s.status == FinancialSafetyAlertLifecycle.dismissed)
        .map((s) => s.alertId)
        .toSet();
  }

  /// All persisted per-alert lifecycle state, keyed by alert id.
  Future<Map<String, FinancialSafetyAlertState>> getStates() async {
    final box = await _box();
    final raw = box.get(_statesKey) as Map?;
    if (raw != null) {
      return {
        for (final entry in raw.entries)
          entry.key as String: FinancialSafetyAlertState.fromMap(entry.key as String, entry.value as Map),
      };
    }

    // One-time migration from the original dismiss-only Set<String>
    // format, so state recorded before FINANCIAL SAFETY 2.0 isn't lost.
    final legacy = (box.get(_legacyKey) as List?)?.cast<String>() ?? const [];
    if (legacy.isEmpty) return {};
    final now = DateTime.now();
    return {
      for (final id in legacy)
        id: FinancialSafetyAlertState(alertId: id, status: FinancialSafetyAlertLifecycle.dismissed, updatedAt: now),
    };
  }

  Future<void> _setState(String alertId, FinancialSafetyAlertLifecycle status, {DateTime? snoozedUntil}) async {
    final box = await _box();
    final states = await getStates();
    states[alertId] = FinancialSafetyAlertState(
      alertId: alertId,
      status: status,
      updatedAt: DateTime.now(),
      snoozedUntil: snoozedUntil,
    );
    await box.put(_statesKey, {for (final e in states.entries) e.key: e.value.toMap()});
    // Keep the legacy Set in sync too, purely for any code path that still
    // reads it directly — dismissed-only, matching its original meaning.
    await box.put(
      _legacyKey,
      states.values.where((s) => s.status == FinancialSafetyAlertLifecycle.dismissed).map((s) => s.alertId).toList(),
    );
  }

  Future<void> dismiss(String alertId) => _setState(alertId, FinancialSafetyAlertLifecycle.dismissed);

  /// Hides the alert until [until]. Once [until] has passed, the alert is
  /// treated as active again (see [FinancialSafetyAlertState.isSnoozeActive])
  /// — no separate "expire" step needed.
  Future<void> snooze(String alertId, DateTime until) =>
      _setState(alertId, FinancialSafetyAlertLifecycle.snoozed, snoozedUntil: until);

  Future<void> resolve(String alertId) => _setState(alertId, FinancialSafetyAlertLifecycle.resolved);

  /// Clears one alert's state, returning it to [FinancialSafetyAlertLifecycle.active].
  Future<void> reopen(String alertId) async {
    final box = await _box();
    final states = await getStates();
    states.remove(alertId);
    await box.put(_statesKey, {for (final e in states.entries) e.key: e.value.toMap()});
    await box.put(
      _legacyKey,
      states.values.where((s) => s.status == FinancialSafetyAlertLifecycle.dismissed).map((s) => s.alertId).toList(),
    );
  }

  /// Every non-active alert state — dismissed, snoozed, or resolved —
  /// newest first, for the alert history view.
  Future<List<FinancialSafetyAlertState>> getHistory() async {
    final states = (await getStates()).values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return states;
  }

  Future<void> clearAll() async {
    final box = await _box();
    await box.delete(_legacyKey);
    await box.delete(_statesKey);
  }
}
