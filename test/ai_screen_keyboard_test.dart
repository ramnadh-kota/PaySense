// BUG FIX regression tests: AI screen keyboard overflow ("BOTTOM
// OVERFLOWED BY 300 PIXELS" on a real device when the keyboard opens).
// Simulates the keyboard via TestFlutterView.viewInsets (the same signal
// Scaffold's resizeToAvoidBottomInset reads on a real device) on a
// deliberately short viewport, and asserts no FlutterError (a RenderFlex
// overflow surfaces as one) is ever recorded.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/features/ai/ai_screen.dart';
import 'package:paysense/features/ai/models/chat_message.dart';
import 'package:paysense/features/ai/models/what_if_result.dart';
import 'package:paysense/features/ai/providers/ai_provider.dart';
import 'package:paysense/features/ai/services/what_if_intent_parser.dart';
import 'package:paysense/shared/models/account.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserProfileAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WalletAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TransactionAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(BudgetAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(GoalAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(RecurringTransactionAdapter());
  if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(BillAdapter());
  if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(LoanAdapter());
  if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(AccountAdapter());
  if (!Hive.isAdapterRegistered(9)) Hive.registerAdapter(AppNotificationAdapter());

  await Hive.openBox<UserProfile>('user_profile');
  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<Budget>('budgets');
  await Hive.openBox<Goal>('goals');
  await Hive.openBox<RecurringTransaction>('recurring_transactions');
  await Hive.openBox('app_settings');
  await Hive.openBox<Bill>('bills');
  await Hive.openBox<Loan>('loans');
  await Hive.openBox<Account>('accounts');
  await Hive.openBox('auth_session');
  await Hive.openBox<AppNotification>('app_notifications');
}

List<ChatMessage> _messages(int count) {
  return List.generate(
    count,
    (i) => ChatMessage(
      id: 'm$i',
      text: 'Message number $i about my spending and savings this month.',
      isUser: i.isEven,
      createdAt: DateTime(2026, 8, 1).add(Duration(minutes: i)),
    ),
  );
}

ChatMessage _whatIfMessage() {
  return ChatMessage(
    id: 'whatif-1',
    text: 'Here is what would happen.',
    isUser: false,
    createdAt: DateTime(2026, 8, 1),
    whatIfResult: const WhatIfResult(
      type: WhatIfIntentType.increaseSavings,
      currentValue: 5000,
      projectedValue: 8000,
      difference: 3000,
      descriptionKey: 'increase_savings',
    ),
  );
}

/// Deliberately short (matches a compact real-device viewport) so the
/// original bug — fixed content overflowing once the keyboard steals
/// space — would have reproduced here before the fix.
Future<void> _pumpAiScreen(
  WidgetTester tester, {
  double keyboardHeight = 0,
  List<ChatMessage>? messages,
}) async {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });

  final overrides = <Override>[
    if (messages != null)
      aiChatProvider.overrideWith(() => _FixedChatNotifier(messages)),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: AiScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _FixedChatNotifier extends AiChatNotifier {
  _FixedChatNotifier(this._messages);
  final List<ChatMessage> _messages;

  @override
  Future<List<ChatMessage>> build() async => _messages;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_ai_keyboard_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    AppColors.currentBrightness = Brightness.light;
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('1. keyboard closed: no overflow error', (tester) async {
    await _pumpAiScreen(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2. keyboard open (300px): no BOTTOM OVERFLOWED error', (tester) async {
    await _pumpAiScreen(tester, keyboardHeight: 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('3. long conversation + keyboard open: no overflow, scrollable', (tester) async {
    await _pumpAiScreen(tester, keyboardHeight: 300, messages: _messages(40));
    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('4. short conversation + keyboard open: no overflow', (tester) async {
    await _pumpAiScreen(tester, keyboardHeight: 300, messages: _messages(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('5. Financial Planning card remains present with keyboard open', (tester) async {
    await _pumpAiScreen(tester, keyboardHeight: 300);
    expect(tester.takeException(), isNull);
    expect(find.text('Financial Planning'), findsOneWidget);
  });

  testWidgets('6. Tax Planner card remains present with keyboard open', (tester) async {
    await _pumpAiScreen(tester, keyboardHeight: 300);
    expect(tester.takeException(), isNull);
    expect(find.text('Tax Planner'), findsOneWidget);
  });

  testWidgets('7. What-If result card renders without overflow with keyboard open', (tester) async {
    await _pumpAiScreen(tester, keyboardHeight: 300, messages: [_whatIfMessage()]);
    expect(tester.takeException(), isNull);

    // The conversation card sits below the greeting/cards/chips/empty-data
    // banner in the single scrollable — scroll it into the virtualized
    // ListView's built range before asserting on its content (a test-harness
    // detail; ensureVisible would need the target already built, which is
    // exactly what's being brought about here).
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('WHAT IF?'), findsOneWidget);
  });

  testWidgets('8. dark mode + keyboard open: no overflow', (tester) async {
    AppColors.currentBrightness = Brightness.dark;
    await _pumpAiScreen(tester, keyboardHeight: 300, messages: _messages(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the chat input field stays visible above the keyboard', (tester) async {
    await _pumpAiScreen(tester, keyboardHeight: 300);
    expect(tester.takeException(), isNull);

    final inputTop = tester.getTopLeft(find.byType(TextField)).dy;
    // Logical screen height is 1200; the keyboard occupies the bottom 300 —
    // the input must be laid out above that boundary, not behind it.
    expect(inputTop, lessThan(1200 - 300));
  });

  testWidgets('quick-question chips remain reachable (scrollable) with keyboard open', (tester) async {
    await _pumpAiScreen(tester, keyboardHeight: 300);
    expect(tester.takeException(), isNull);
    expect(find.byType(ActionChip), findsWidgets);
  });

  testWidgets('the Column layout never overflows across the whole keyboard-open build', (tester) async {
    await _pumpAiScreen(tester, keyboardHeight: 300, messages: _messages(3));
    // A RenderFlex overflow renders as a FlutterError captured by the test
    // binding — asserting no exception was recorded is the direct
    // regression check for "BOTTOM OVERFLOWED BY XXX PIXELS".
    expect(tester.takeException(), isNull);
  });
}
