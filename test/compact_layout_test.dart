// Focused regression tests for P0 Issue 3 (excessive empty space) on
// Wallet, Settings, and AI. "Compactness" isn't meaningfully unit-testable
// as a rendered property without brittle golden-image comparisons, so these
// lock in the specific spacing constants that were intentionally reduced —
// catching an accidental revert back to the old, looser values rather than
// asserting a pixel-perfect layout. Patterns are whitespace-tolerant
// (`\s+`) so reformatting alone doesn't break them; only reverting the
// actual numbers would.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('28a. Wallet: the Total Wallet Balance card padding was tightened from 24 to 20', () async {
    final source = await File('lib/features/wallet/wallet_screen.dart').readAsString();
    final match = RegExp(
      r'padding:\s*const\s*EdgeInsets\.all\((\d+)\),\s*color:\s*AppColors\.primary,',
    ).firstMatch(source);
    expect(match, isNotNull, reason: 'balance card AppCard not found in expected shape');
    expect(int.parse(match!.group(1)!), lessThanOrEqualTo(20));
  });

  test('28b. Wallet: the gap before "All Wallets" was tightened from 24', () async {
    final source = await File('lib/features/wallet/wallet_screen.dart').readAsString();
    final match = RegExp(
      r"SizedBox\(height:\s*(\d+)\),\s*Text\(\s*'All Wallets',",
    ).firstMatch(source);
    expect(match, isNotNull);
    expect(int.parse(match!.group(1)!), lessThan(24));
  });

  test('29. Settings: the gap before each section label was tightened from 24', () async {
    final source = await File(
      'lib/features/settings/presentation/settings_screen.dart',
    ).readAsString();
    final gaps = RegExp(r'SizedBox\(height:\s*(\d+)\),\s*_SectionLabel\(')
        .allMatches(source)
        .map((m) => int.parse(m.group(1)!))
        .toList();
    expect(gaps, isNotEmpty);
    expect(gaps.every((gap) => gap < 24), isTrue, reason: 'gaps found: $gaps');
  });

  test('30. AI: the redundant fixed gap before the greeting text was removed', () async {
    final source = await File('lib/features/ai/ai_screen.dart').readAsString();
    final hasGapBeforeGreeting = RegExp(
      r"SizedBox\(height:\s*\d+\),\s*Text\(\s*'Hello,",
    ).hasMatch(source);
    expect(hasGapBeforeGreeting, isFalse);
  });
}
