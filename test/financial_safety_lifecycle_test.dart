import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/financial_safety_alert.dart';
import 'package:paysense/shared/repositories/financial_safety_dismissed_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_safety_lifecycle_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FinancialSafetyDismissedRepository — lifecycle', () {
    test('a fresh alert id has no state (implicitly active)', () async {
      final states = await FinancialSafetyDismissedRepository.instance.getStates();
      expect(states['spendingSpike'], isNull);
    });

    test('dismiss() persists FinancialSafetyAlertLifecycle.dismissed', () async {
      await FinancialSafetyDismissedRepository.instance.dismiss('spendingSpike');
      final states = await FinancialSafetyDismissedRepository.instance.getStates();
      expect(states['spendingSpike']!.status, FinancialSafetyAlertLifecycle.dismissed);
      expect(await FinancialSafetyDismissedRepository.instance.getDismissedIds(), contains('spendingSpike'));
    });

    test('snooze() persists a future snoozedUntil and isSnoozeActive is true before it passes', () async {
      final until = DateTime.now().add(const Duration(days: 3));
      await FinancialSafetyDismissedRepository.instance.snooze('lowBalanceRisk', until);
      final states = await FinancialSafetyDismissedRepository.instance.getStates();
      final state = states['lowBalanceRisk']!;
      expect(state.status, FinancialSafetyAlertLifecycle.snoozed);
      expect(state.isSnoozeActive(DateTime.now()), isTrue);
      expect(state.isSnoozeActive(until.add(const Duration(days: 1))), isFalse);
    });

    test('resolve() persists FinancialSafetyAlertLifecycle.resolved', () async {
      await FinancialSafetyDismissedRepository.instance.resolve('cashFlowDeficit');
      final states = await FinancialSafetyDismissedRepository.instance.getStates();
      expect(states['cashFlowDeficit']!.status, FinancialSafetyAlertLifecycle.resolved);
    });

    test('reopen() removes the persisted state entirely — back to implicitly active', () async {
      await FinancialSafetyDismissedRepository.instance.dismiss('spendingSpike');
      await FinancialSafetyDismissedRepository.instance.reopen('spendingSpike');
      final states = await FinancialSafetyDismissedRepository.instance.getStates();
      expect(states['spendingSpike'], isNull);
    });

    test('getHistory() returns dismissed/snoozed/resolved alerts, newest updatedAt first', () async {
      await FinancialSafetyDismissedRepository.instance.dismiss('spendingSpike');
      await Future.delayed(const Duration(milliseconds: 5));
      await FinancialSafetyDismissedRepository.instance.resolve('cashFlowDeficit');

      final history = await FinancialSafetyDismissedRepository.instance.getHistory();
      expect(history.length, 2);
      expect(history.first.alertId, 'cashFlowDeficit');
    });

    test('clearAll() removes every persisted state, including legacy dismissed ids', () async {
      await FinancialSafetyDismissedRepository.instance.dismiss('spendingSpike');
      await FinancialSafetyDismissedRepository.instance.snooze('lowBalanceRisk', DateTime.now().add(const Duration(days: 1)));

      await FinancialSafetyDismissedRepository.instance.clearAll();

      expect(await FinancialSafetyDismissedRepository.instance.getDismissedIds(), isEmpty);
      expect(await FinancialSafetyDismissedRepository.instance.getHistory(), isEmpty);
    });

    test('a legacy dismissed-id Set (pre-2.0 format) migrates into dismissed states on read', () async {
      final box = await Hive.openBox('financial_safety_dismissed_alerts');
      await box.put('dismissedIds', ['spendingSpike', 'cashFlowDeficit']);

      final states = await FinancialSafetyDismissedRepository.instance.getStates();
      expect(states['spendingSpike']!.status, FinancialSafetyAlertLifecycle.dismissed);
      expect(states['cashFlowDeficit']!.status, FinancialSafetyAlertLifecycle.dismissed);
    });
  });
}
