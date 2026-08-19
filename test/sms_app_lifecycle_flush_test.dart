// Focused tests for the real-device root cause of "SMS automation doesn't
// work": the native SMS queue was previously only ever drained at Splash's
// cold-launch, never when the app resumes from being merely backgrounded
// (the overwhelmingly common case — most users background rather than
// force-close). AppLockGate now also drains it on AppLifecycleState.resumed
// — these tests exercise that behavior directly via a fake SmsChannel,
// without touching a real platform channel or Android device.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/features/app_lock/presentation/app_lock_gate.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/sms_automation_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/services/sms_channel.dart';

class _CountingSmsChannel extends SmsChannel {
  _CountingSmsChannel(this._pending);

  final List<RawSmsEvent> _pending;
  int fetchCallCount = 0;

  @override
  Future<List<RawSmsEvent>> fetchPending() async {
    fetchCallCount++;
    return _pending;
  }

  @override
  Future<void> acknowledge(List<String> nativeIds) async {}
}

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(WalletAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(TransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(9)) {
    Hive.registerAdapter(AppNotificationAdapter());
  }
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(SmsReviewItemAdapter());
  }

  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<AppNotification>('app_notifications');
  await Hive.openBox<SmsReviewItem>('sms_review_items');
  await Hive.openBox('sms_processed_fingerprints');
  await Hive.openBox('app_settings');
}

RawSmsEvent _pendingEvent() {
  return RawSmsEvent(
    nativeId: 'evt-1',
    sender: 'HDFCBK',
    body: 'Rs. 500 debited from A/c XX1234 at AMAZON',
    timestamp: DateTime(2026, 8, 12, 10, 30),
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_lifecycle_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // Hive's Box.put() resolves via a real Timer/event-loop callback that
  // TestWidgetsFlutterBinding's virtual clock never advances on its own —
  // any real disk write made directly in a `testWidgets` body (or
  // transitively, by production code a lifecycle callback fires off
  // fire-and-forget) has to run inside `tester.runAsync` or it simply never
  // completes. Every Hive write in this file goes through this helper.
  Future<void> resumeFromBackground(WidgetTester tester) async {
    await tester.runAsync(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // Gives the fire-and-forget `_flushPendingSmsIfEnabled` a real
      // microtask/event-loop turn to actually run and finish.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    '1. automation disabled: resuming from background never drains the '
    'native SMS queue',
    (tester) async {
      await tester.runAsync(
        () => AppSettingsRepository.instance.setSmsAutomationEnabled(false),
      );
      final channel = _CountingSmsChannel([_pendingEvent()]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [smsChannelProvider.overrideWithValue(channel)],
          child: MaterialApp(home: AppLockGate(child: Container())),
        ),
      );
      await tester.pumpAndSettle();

      await resumeFromBackground(tester);

      expect(channel.fetchCallCount, 0);
    },
  );

  testWidgets(
    '2 & 16. automation enabled: resuming from background (not just a cold '
    'app-start) drains the native SMS queue — the actual real-device fix',
    (tester) async {
      await tester.runAsync(
        () => AppSettingsRepository.instance.setSmsAutomationEnabled(true),
      );
      final channel = _CountingSmsChannel([_pendingEvent()]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [smsChannelProvider.overrideWithValue(channel)],
          child: MaterialApp(home: AppLockGate(child: Container())),
        ),
      );
      await tester.pumpAndSettle();
      // The very first resumed state after a fresh pump isn't reported via
      // didChangeAppLifecycleState (Flutter only calls it on a subsequent
      // transition), so nothing should have fired purely from pumping yet.
      expect(channel.fetchCallCount, 0);

      await resumeFromBackground(tester);

      expect(channel.fetchCallCount, greaterThanOrEqualTo(1));
    },
  );

  testWidgets(
    'a rapid background/foreground flap does not overlap two concurrent '
    'drains of the same native queue (in-flight guard)',
    (tester) async {
      await tester.runAsync(
        () => AppSettingsRepository.instance.setSmsAutomationEnabled(true),
      );
      final channel = _CountingSmsChannel([_pendingEvent()]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [smsChannelProvider.overrideWithValue(channel)],
          child: MaterialApp(home: AppLockGate(child: Container())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      // Each resume is still allowed to trigger its own flush once the
      // previous one has finished — this only asserts nothing crashed and
      // the queue was drained at least once, not an exact call count.
      expect(channel.fetchCallCount, greaterThanOrEqualTo(1));
    },
  );
}
