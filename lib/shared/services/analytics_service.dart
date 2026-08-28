import 'package:flutter/foundation.dart';

/// CONSUMER MONETIZATION FOUNDATION — PHASE 10. The complete, agreed set
/// of activation/engagement/monetization events. Adding a new tracked
/// moment means adding one value here — never a bespoke ad-hoc event
/// string scattered through the app.
enum AnalyticsEvent {
  // Activation
  onboardingStarted,
  onboardingCompleted,
  firstWalletCreated,
  firstTransactionAdded,
  financialSnapshotViewed,
  ahaMomentViewed,

  // Engagement
  dashboardOpened,
  financialPlanningOpened,
  insightOpened,
  aiOpened,
  affordabilityUsed,
  taxPlannerUsed,
  whatIfUsed,
  timelineOpened,
  comparePeriodsUsed,
  bankConnectStarted,
  bankConnectCompleted,
  bankSyncNow,
  featureSearchOpened,
  featureSearchResultTapped,
  financialSearchResultTapped,
  recurringMoneyOpened,
  dataExportRequested,

  // Monetization
  premiumFeatureViewed,
  paywallViewed,
  pricingSelected,
  subscriptionStarted,
}

@immutable
class AnalyticsLogEntry {
  const AnalyticsLogEntry({required this.event, required this.metadata, required this.timestamp});

  final AnalyticsEvent event;
  final Map<String, Object?> metadata;
  final DateTime timestamp;
}

/// A pure, dependency-free event logger. No analytics SDK is installed in
/// this app today — this is deliberately a thin, isolated seam: every
/// call site logs through THIS class, so wiring a real vendor (Firebase
/// Analytics, Mixpanel, etc.) later is a one-file change inside [log],
/// never a rewrite of every call site.
///
/// PRIVACY: [log] asserts (debug builds only, via [_assertSafeMetadata])
/// that no metadata key/value looks like it could carry SMS bodies, phone
/// numbers, account/card numbers, OTPs, credentials, or raw transaction
/// descriptions — mirroring the exact forbidden-fragment list already
/// established for the AI context privacy tests elsewhere in this app.
/// Only event NAMES and small, safe metadata (counts, enum names, plan
/// ids) should ever be logged.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  static const List<String> _forbiddenKeyFragments = [
    'password', 'pin', 'biometric', 'token', 'secret', 'apikey', 'credential',
    'sms', 'phone', 'accountnumber', 'cardnumber', 'otp', 'description', 'note', 'body',
  ];

  final List<AnalyticsLogEntry> _log = [];

  void log(AnalyticsEvent event, {Map<String, Object?> metadata = const {}}) {
    assert(_isSafeMetadata(metadata), 'AnalyticsService.log: metadata for $event looks like it may contain sensitive data');
    _log.add(AnalyticsLogEntry(event: event, metadata: metadata, timestamp: DateTime.now()));
    // A real analytics SDK integration point: forward `event`/`metadata`
    // to it here once one is added. Deliberately not implemented yet —
    // this app has none installed.
  }

  bool _isSafeMetadata(Map<String, Object?> metadata) {
    for (final entry in metadata.entries) {
      final key = entry.key.toLowerCase().replaceAll('_', '').replaceAll('-', '');
      for (final fragment in _forbiddenKeyFragments) {
        if (key.contains(fragment)) return false;
      }
      final value = entry.value;
      if (value is String && value.length > 60) {
        // A long free-text string is far more likely to be a raw
        // description/note than safe metadata (counts, ids, enum names).
        return false;
      }
    }
    return true;
  }

  /// Read-only, for tests/debugging — never sent anywhere itself.
  List<AnalyticsLogEntry> get debugLog => List.unmodifiable(_log);

  @visibleForTesting
  void clearForTesting() => _log.clear();
}
