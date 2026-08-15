import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/services/sms_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'paysense/sms';
  const channel = MethodChannel(channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('SmsChannel (Dart-side contract with the native receiver)', () {
    test(
      '26. decodes sender, body, and timestamp for each event the native '
      'side reports pending',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'getPendingEvents');
              return [
                {
                  'nativeId': 'evt-1',
                  'sender': 'HDFCBK',
                  'body': 'Rs. 500 debited from A/c XX1234',
                  'timestampMillis': DateTime(2026, 8, 12, 10, 30).millisecondsSinceEpoch,
                },
              ];
            });

        final sms = SmsChannel(channel: channel);
        final events = await sms.fetchPending();

        expect(events, hasLength(1));
        expect(events.single.sender, 'HDFCBK');
        expect(events.single.body, 'Rs. 500 debited from A/c XX1234');
        expect(events.single.timestamp, DateTime(2026, 8, 12, 10, 30));
        expect(events.single.nativeId, 'evt-1');
      },
    );

    test(
      '27. multiple queued events (as the native receiver would report '
      'after several SMS, including reconstructed multi-part messages) are '
      'each decoded independently and in order',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              return [
                {
                  'nativeId': 'evt-1',
                  'sender': 'HDFCBK',
                  'body': 'Rs. 500 debited',
                  'timestampMillis': 1000,
                },
                {
                  'nativeId': 'evt-2',
                  'sender': 'ICICIB',
                  // Simulates a multi-part SMS the native receiver already
                  // reconstructed into one body before persisting it —
                  // reconstruction itself happens in SmsReceiver.kt
                  // (joinToString over Telephony's SmsMessage parts) and
                  // isn't something this Dart-side test can exercise
                  // directly; this confirms the Dart side treats a long
                  // reconstructed body as one opaque event either way.
                  'body': 'Rs. 50,000 credited to your account after a long '
                      'multi-part confirmation message continues here',
                  'timestampMillis': 2000,
                },
              ];
            });

        final sms = SmsChannel(channel: channel);
        final events = await sms.fetchPending();

        expect(events, hasLength(2));
        expect(events[0].nativeId, 'evt-1');
        expect(events[1].nativeId, 'evt-2');
        expect(events[1].body, contains('multi-part'));
      },
    );

    test(
      '28. a missing/unavailable platform channel (e.g. native side not '
      'wired up, or running where SMS is unsupported) fails safely — '
      'returns an empty list rather than throwing',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) {
              throw MissingPluginException();
            });

        final sms = SmsChannel(channel: channel);
        final events = await sms.fetchPending();

        expect(events, isEmpty);
      },
    );

    test('acknowledge() is a no-op (never throws) when the channel is unavailable', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) {
            throw MissingPluginException();
          });

      final sms = SmsChannel(channel: channel);
      await sms.acknowledge(['evt-1']); // must not throw
    });

    test('acknowledge() sends the given nativeIds to the native side', () async {
      List<Object?>? sentIds;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'acknowledgeEvents');
            sentIds = (call.arguments as Map)['nativeIds'] as List<Object?>;
            return null;
          });

      final sms = SmsChannel(channel: channel);
      await sms.acknowledge(['evt-1', 'evt-2']);

      expect(sentIds, ['evt-1', 'evt-2']);
    });
  });
}
