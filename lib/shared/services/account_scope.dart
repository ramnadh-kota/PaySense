import 'package:hive/hive.dart';

import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/fun_group_expense.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/tax_settings.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/models/wallet.dart';

/// Owns per-account namespacing of every local Hive box that holds
/// user-owned financial data, so Account A can never read or write Account
/// B's records on a shared device.
///
/// Design (see the account-isolation milestone for the full rationale):
///  * "Financial" boxes — transactions, wallets, budgets, goals, bills,
///    loans, recurring transactions, notifications, SMS review items, SMS
///    fingerprints, tax settings, and the user profile — are namespaced per
///    active account as `<baseName>__acct_<accountId>`, opened on demand
///    the moment an account becomes active (login/signup/session restore).
///  * `accounts` (the account registry) and `auth_session` (which account
///    is currently signed in) stay global by necessity — that's exactly
///    the bootstrap data needed to know which namespace to open.
///  * `app_settings` (theme, first-launch, App Lock PIN/method/timeout, SMS
///    automation toggle) also stays global/device-level: it's read at the
///    app root and by the pre-login App Lock re-entry gate, both of which
///    run before any account is known to be active. Scoping it per account
///    would either crash startup or defeat App Lock's purpose of guarding
///    the app before a user has chosen an account. This is a deliberate
///    trade-off, not an oversight.
///
/// [scopedBoxName] falls back to the bare, unscoped base name whenever no
/// account is active. In the shipped app that branch is never exercised —
/// every screen that touches financial data sits behind the auth gate, so
/// an account is always active by the time a repository is read. The
/// fallback exists purely so code that legitimately runs without a signed
/// -in user (and the large existing unit-test suite that exercises
/// repositories directly, without going through sign-in) keeps working
/// against a single implicit namespace, rather than throwing.
class AccountScope {
  AccountScope._();

  static final AccountScope instance = AccountScope._();

  static const String migrationBoxName = 'migration_state';
  static const String _legacyMigrationClaimKey =
      'legacyMigrationClaimedByAccountId';

  /// Base (unscoped) names of every Hive box that holds account-owned data.
  static const List<String> scopedBoxBaseNames = [
    'user_profile',
    'wallets',
    'transactions',
    'budgets',
    'goals',
    'recurring_transactions',
    'bills',
    'loans',
    'app_notifications',
    'sms_review_items',
    'sms_processed_fingerprints',
    'tax_settings',
    'fun_group_expenses',
  ];

  String? _activeAccountId;

  String? get activeAccountId => _activeAccountId;

  /// The Hive box name a repository for [baseName] should use right now.
  String scopedBoxName(String baseName) {
    final accountId = _activeAccountId;
    if (accountId == null) {
      return baseName;
    }
    return '${baseName}__acct_$accountId';
  }

  /// Opens every account-owned box for [accountId] (creating them if this
  /// is the first time this account has been active on this device),
  /// performs the one-time legacy-data migration if this is the very first
  /// account to activate since the isolation update, and makes [accountId]
  /// the active namespace. Safe to call repeatedly for the same account.
  Future<void> activate(String accountId) async {
    await Hive.openBox(migrationBoxName);
    await _openScopedBoxes(accountId);
    await _migrateLegacyDataIfFirstActivation(accountId);
    _activeAccountId = accountId;
  }

  /// Clears the active namespace (called on logout). Boxes already opened
  /// for the account stay open in memory — only the "which namespace is
  /// active" pointer is cleared, so nothing is written under the wrong
  /// account if a stray call happens after logout (it fails loudly against
  /// an unopened box rather than silently touching real data).
  void deactivate() {
    _activeAccountId = null;
  }

  /// Permanently deletes every scoped box belonging to [accountId] from
  /// disk. Never touches another account's boxes, and never touches the
  /// global `accounts`/`auth_session`/`app_settings` boxes.
  Future<void> purgeAccountData(String accountId) async {
    for (final baseName in scopedBoxBaseNames) {
      final name = '${baseName}__acct_$accountId';
      if (await Hive.boxExists(name)) {
        await Hive.deleteBoxFromDisk(name);
      }
    }
    if (_activeAccountId == accountId) {
      _activeAccountId = null;
    }
  }

  Future<void> _openScopedBoxes(String accountId) async {
    String scoped(String base) => '${base}__acct_$accountId';

    await Hive.openBox<UserProfile>(scoped('user_profile'));
    await Hive.openBox<Wallet>(scoped('wallets'));
    await Hive.openBox<Transaction>(scoped('transactions'));
    await Hive.openBox<Budget>(scoped('budgets'));
    await Hive.openBox<Goal>(scoped('goals'));
    await Hive.openBox<RecurringTransaction>(scoped('recurring_transactions'));
    await Hive.openBox<Bill>(scoped('bills'));
    await Hive.openBox<Loan>(scoped('loans'));
    await Hive.openBox<AppNotification>(scoped('app_notifications'));
    await Hive.openBox<SmsReviewItem>(scoped('sms_review_items'));
    await Hive.openBox(scoped('sms_processed_fingerprints'));
    await Hive.openBox<TaxSettings>(scoped('tax_settings'));
    await Hive.openBox<FunGroupExpense>(scoped('fun_group_expenses'));
  }

  /// Runs at most once per install, ever: if no account has yet claimed the
  /// pre-isolation legacy (unscoped) data, copies it into [accountId]'s new
  /// namespace and permanently marks the migration claimed — so a second or
  /// third account created later never sees the first account's legacy
  /// data. Never overwrites data the account already has in its own
  /// namespace, and never deletes the legacy box (inert but preserved as a
  /// safety net).
  Future<void> _migrateLegacyDataIfFirstActivation(String accountId) async {
    final migrationBox = Hive.box(migrationBoxName);
    if (migrationBox.get(_legacyMigrationClaimKey) != null) {
      return;
    }

    await _migrateBox<UserProfile>('user_profile', accountId);
    await _migrateBox<Wallet>('wallets', accountId);
    await _migrateBox<Transaction>('transactions', accountId);
    await _migrateBox<Budget>('budgets', accountId);
    await _migrateBox<Goal>('goals', accountId);
    await _migrateBox<RecurringTransaction>('recurring_transactions', accountId);
    await _migrateBox<Bill>('bills', accountId);
    await _migrateBox<Loan>('loans', accountId);
    await _migrateBox<AppNotification>('app_notifications', accountId);
    await _migrateBox<SmsReviewItem>('sms_review_items', accountId);
    await _migrateUntypedBox('sms_processed_fingerprints', accountId);
    await _migrateBox<TaxSettings>('tax_settings', accountId);
    // fun_group_expenses never existed pre-isolation, so there is never
    // legacy data to migrate for it — included in the base-name list only
    // so activate()/purgeAccountData() manage its lifecycle uniformly.

    await migrationBox.put(_legacyMigrationClaimKey, accountId);
  }

  Future<void> _migrateBox<T>(String baseName, String accountId) async {
    if (!await Hive.boxExists(baseName)) {
      return;
    }
    final legacy = await Hive.openBox<T>(baseName);
    if (legacy.isEmpty) {
      return;
    }
    final target = Hive.box<T>('${baseName}__acct_$accountId');
    if (target.isNotEmpty) {
      return;
    }
    for (final key in legacy.keys) {
      await target.put(key, legacy.get(key) as T);
    }
  }

  Future<void> _migrateUntypedBox(String baseName, String accountId) async {
    if (!await Hive.boxExists(baseName)) {
      return;
    }
    final legacy = await Hive.openBox(baseName);
    if (legacy.isEmpty) {
      return;
    }
    final target = Hive.box('${baseName}__acct_$accountId');
    if (target.isNotEmpty) {
      return;
    }
    for (final key in legacy.keys) {
      await target.put(key, legacy.get(key));
    }
  }
}
