import 'package:hive/hive.dart';

import '../models/financial_account.dart';

/// Phase 7A — Financial Account Repository
///
/// Local, deterministic persistence for user financial accounts (manual wallets,
/// bank accounts, credit cards, UPI, and future account-aggregator streams).
/// Uses Hive storage with toMap/fromMap serialization.
/// Purely on-device, zero network or external dependencies.
class FinancialAccountRepository {
  FinancialAccountRepository._();

  static final FinancialAccountRepository instance =
      FinancialAccountRepository._();

  static const String boxName = 'financial_accounts';

  Future<Box> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return Hive.openBox(boxName);
  }

  /// Initializes the repository and ensures the Hive box is open.
  Future<void> init() async {
    await _box();
  }

  /// Saves or updates a financial account record.
  Future<void> saveAccount(FinancialAccount account) async {
    final box = await _box();
    await box.put(account.id, account.toMap());
  }

  /// Alias for [saveAccount] to match recording terminology used in domain engines.
  Future<void> recordAccount(FinancialAccount account) async {
    await saveAccount(account);
  }

  /// Retrieves all financial accounts sorted deterministically by updatedAt (newest first).
  Future<List<FinancialAccount>> getAll() async {
    final box = await _box();
    if (box.isEmpty) return const [];

    final accounts = <FinancialAccount>[];
    for (final raw in box.values) {
      if (raw is Map) {
        try {
          accounts.add(FinancialAccount.fromMap(raw));
        } catch (_) {
          // Gracefully skip malformed entries
        }
      }
    }

    accounts.sort((a, b) {
      final cmp = b.updatedAt.compareTo(a.updatedAt);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    return List<FinancialAccount>.unmodifiable(accounts);
  }

  /// Retrieves all currently active financial accounts (isActive == true).
  Future<List<FinancialAccount>> getActiveAccounts() async {
    final all = await getAll();
    return List<FinancialAccount>.unmodifiable(
      all.where((acc) => acc.isActive).toList(),
    );
  }

  /// Retrieves a specific account by its unique [id].
  Future<FinancialAccount?> getById(String id) async {
    final box = await _box();
    final raw = box.get(id);
    if (raw is Map) {
      try {
        return FinancialAccount.fromMap(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Retrieves all accounts matching a specific [FinancialAccountType].
  Future<List<FinancialAccount>> getByType(FinancialAccountType type) async {
    final all = await getAll();
    return List<FinancialAccount>.unmodifiable(
      all.where((acc) => acc.type == type).toList(),
    );
  }

  /// Retrieves all accounts matching a specific [FinancialAccountSource].
  Future<List<FinancialAccount>> getBySource(FinancialAccountSource source) async {
    final all = await getAll();
    return List<FinancialAccount>.unmodifiable(
      all.where((acc) => acc.source == source).toList(),
    );
  }

  /// Deactivates an account without deleting historical balance and configuration data.
  Future<void> deactivateAccount(String id) async {
    final existing = await getById(id);
    if (existing == null) return;

    final updated = existing.copyWith(
      isActive: false,
      updatedAt: DateTime.now(),
    );
    await saveAccount(updated);
  }

  /// Permanently deletes an account by its unique [id].
  Future<void> deleteAccount(String id) async {
    final box = await _box();
    await box.delete(id);
  }

  /// Clears all stored financial accounts.
  Future<void> clearAll() async {
    final box = await _box();
    await box.clear();
  }
}
