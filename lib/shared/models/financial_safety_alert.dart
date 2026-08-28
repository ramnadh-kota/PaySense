import 'package:flutter/foundation.dart';

/// FINANCIAL SAFETY ENGINE — deterministic alert types. Every type maps
/// to ONE detection rule in `FinancialSafetyEngine` — no AI-generated
/// figures, no invented numbers.
enum FinancialSafetyAlertType {
  spendingSpike,
  lowBalanceRisk,
  upcomingEmiPressure,
  recurringPaymentPressure,
  salaryIrregularity,
  largeUnusualTransaction,
  cashFlowDeficit,
  multipleLargeTransactionsCluster,
}

enum FinancialSafetyAlertSeverity { info, attention, high }

/// FINANCIAL SAFETY 2.0 — the lifecycle a single alert id (see
/// [FinancialSafetyAlert.id]) moves through. [active] is the implicit
/// default (no stored state at all) — only a user ACTION persists a
/// state here, exactly like the original dismiss-only mechanism this
/// replaces.
enum FinancialSafetyAlertLifecycle { active, dismissed, snoozed, resolved }

/// Persisted per-alert lifecycle state. [snoozedUntil] is only meaningful
/// when [status] is [FinancialSafetyAlertLifecycle.snoozed] — once it's in
/// the past, the alert is treated as active again by the notifier (see
/// `FinancialSafetyAlertsNotifier`), without needing to mutate storage.
@immutable
class FinancialSafetyAlertState {
  const FinancialSafetyAlertState({
    required this.alertId,
    required this.status,
    required this.updatedAt,
    this.snoozedUntil,
  });

  final String alertId;
  final FinancialSafetyAlertLifecycle status;
  final DateTime updatedAt;
  final DateTime? snoozedUntil;

  bool isSnoozeActive(DateTime now) =>
      status == FinancialSafetyAlertLifecycle.snoozed &&
      snoozedUntil != null &&
      snoozedUntil!.isAfter(now);

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'snoozedUntil': snoozedUntil?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FinancialSafetyAlertState.fromMap(String alertId, Map<dynamic, dynamic> map) {
    return FinancialSafetyAlertState(
      alertId: alertId,
      status: FinancialSafetyAlertLifecycle.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => FinancialSafetyAlertLifecycle.active,
      ),
      snoozedUntil: map['snoozedUntil'] == null ? null : DateTime.parse(map['snoozedUntil'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

/// One deterministic, non-dismissible-by-default safety observation.
/// Deliberately worded as "PaySense insight" language — never fear-based,
/// never framed as financial advice (see `FinancialSafetyEngine`'s own
/// doc comment).
@immutable
class FinancialSafetyAlert {
  const FinancialSafetyAlert({
    required this.type,
    required this.severity,
    required this.title,
    required this.explanation,
    required this.recommendedAction,
    required this.createdAt,
    this.amount,
    this.date,
    this.isDismissed = false,
  });

  final FinancialSafetyAlertType type;
  final FinancialSafetyAlertSeverity severity;
  final String title;
  final String explanation;
  final String recommendedAction;
  final double? amount;
  final DateTime? date;
  final DateTime createdAt;
  final bool isDismissed;

  /// A stable id for dismiss/read-state tracking, keyed by type only (one
  /// active alert per type at a time — matches how `FinancialActionEngine`/
  /// `FinancialInsightEngine` already dedupe by type elsewhere in this app).
  String get id => type.name;

  FinancialSafetyAlert copyWith({bool? isDismissed}) {
    return FinancialSafetyAlert(
      type: type,
      severity: severity,
      title: title,
      explanation: explanation,
      recommendedAction: recommendedAction,
      amount: amount,
      date: date,
      createdAt: createdAt,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}
