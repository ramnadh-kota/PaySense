// Focused regression test for P0 Issue 4: Dashboard previously had two
// "Add Income" / "Add Expense" / "Budget" quick-action rows — a top row and
// a duplicate bottom "Quick Actions" section. The bottom section (which
// also carried the only "Quick Actions" heading) has been removed; the top
// row (unlabelled, directly under the balance card) is the sole surviving
// entry point.
//
// This asserts the fix at the source level rather than by fully mounting
// DashboardScreen: the screen reads from a dozen+ providers (budgets,
// transactions, wallets, financial health, cash flow, safe-to-spend,
// subscriptions, notifications...), so a full widget-tree mount would need
// to fake all of them just to prove a static layout fact. Counting each
// label's occurrence in the built widget tree's source is a direct,
// low-cost way to lock in "no duplicate" as a regression guard for this
// specific fix.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() async {
    source = await File(
      'lib/features/dashboard/dashboard_screen.dart',
    ).readAsString();
  });

  test('27a. "Add Income" quick action appears exactly once on Dashboard', () {
    final matches = RegExp(r"label:\s*'Add Income'").allMatches(source).length;
    expect(matches, 1);
  });

  test('27b. "Add Expense" quick action appears exactly once on Dashboard', () {
    final matches = RegExp(r"label:\s*'Add Expense'").allMatches(source).length;
    expect(matches, 1);
  });

  test('27c. "Budget" quick action appears exactly once on Dashboard', () {
    final matches = RegExp(r"label:\s*'Budget'").allMatches(source).length;
    expect(matches, 1);
  });

  test('27d. the duplicate second "Quick Actions" section header is gone', () {
    expect(source.contains("'Quick Actions'"), isFalse);
  });

  test('27e. exactly one QuickActionButton row remains (three buttons, not seven)', () {
    final quickActionButtonCount = RegExp(r'QuickActionButton\(').allMatches(source).length;
    expect(quickActionButtonCount, 3);
  });
}
