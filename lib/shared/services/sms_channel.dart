import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One SMS captured by the native Android `SmsReceiver` and persisted to
/// its pending-events store, exactly as handed back across the platform
/// channel — sender, body, and timestamp only, plus the native-assigned
/// [nativeId] used to acknowledge it once Dart is done with it.
@immutable
class RawSmsEvent {
  const RawSmsEvent({
    required this.nativeId,
    required this.sender,
    required this.body,
    required this.timestamp,
  });

  factory RawSmsEvent.fromMap(Map<Object?, Object?> map) {
    return RawSmsEvent(
      nativeId: map['nativeId'] as String,
      sender: map['sender'] as String,
      body: map['body'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestampMillis'] as int,
      ),
    );
  }

  final String nativeId;
  final String sender;
  final String body;
  final DateTime timestamp;
}

/// Thin wrapper over the `paysense/sms` platform channel — the only place
/// in the Flutter codebase that talks to the native SMS receiver. Kept
/// deliberately dumb (fetch/acknowledge only, no parsing or business
/// logic) so `SmsTransactionProcessor` stays the single place that logic
/// lives, and so it's trivial to substitute a fake in tests.
class SmsChannel {
  SmsChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('paysense/sms');

  final MethodChannel _channel;

  /// Fetches every SMS event the native receiver has queued up since it
  /// was last acknowledged. Never throws on a platform-channel failure
  /// (e.g. running on a non-Android platform, or the channel not yet wired
  /// up) — returns an empty list instead, since a missed automatic-import
  /// pass is far less harmful than crashing app startup.
  Future<List<RawSmsEvent>> fetchPending() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('getPendingEvents');
      if (result == null) {
        return const [];
      }
      return result
          .whereType<Map<Object?, Object?>>()
          .map(RawSmsEvent.fromMap)
          .toList();
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// Removes the given native events from the pending queue once
  /// [SmsTransactionProcessor] has finished acting on them (successfully
  /// or not — a permanently-unparseable SMS must not be retried forever).
  Future<void> acknowledge(List<String> nativeIds) async {
    if (nativeIds.isEmpty) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('acknowledgeEvents', <String, Object?>{
        'nativeIds': nativeIds,
      });
    } on MissingPluginException {
      // Nothing to acknowledge against on this platform.
    } on PlatformException {
      // Best-effort — if this fails, the same events are simply re-fetched
      // and re-processed next time; SmsFingerprintRepository still
      // prevents that from creating a duplicate transaction.
    }
  }
}
