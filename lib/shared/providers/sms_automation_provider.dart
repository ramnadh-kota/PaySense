import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/shared/services/sms_channel.dart';
import 'package:paysense/shared/services/sms_transaction_processor.dart';

final smsChannelProvider = Provider<SmsChannel>((ref) {
  return SmsChannel();
});

/// The single centralized SMS-to-transaction orchestrator — see
/// [SmsTransactionProcessor] for the full pipeline. Exposed as a plain
/// `Provider` (not a Notifier) since it holds no state of its own beyond
/// its dependencies; call sites just invoke `processPending()`/
/// `processEvents()` on it directly.
final smsTransactionProcessorProvider = Provider<SmsTransactionProcessor>((ref) {
  return SmsTransactionProcessor(ref, channel: ref.watch(smsChannelProvider));
});
