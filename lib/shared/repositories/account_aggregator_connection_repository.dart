import 'package:hive/hive.dart';

import '../services/account_aggregator/account_aggregator_models.dart';

/// ACCOUNT AGGREGATOR — PHASE 4. Persists [AccountAggregatorConnection]s
/// (including their nested [AccountAggregatorAccount]s, wallet mappings,
/// and last-synced timestamps) across app restarts.
///
/// Uses an UNTYPED Hive box (`Box`, not `Box<AccountAggregatorConnection>`)
/// storing each connection's own `toMap()`/`fromMap()` JSON-shaped
/// representation — deliberately avoiding a new `@HiveType` class. Every
/// value in that map is a String/num/bool/List/Map/null (dates are
/// ISO-8601 strings), all natively supported by Hive without a
/// `TypeAdapter`, so this box can be opened lazily on first use with no
/// change to the app's Hive bootstrap/adapter-registration sequence.
///
/// PRIVACY: only ever stores what [AccountAggregatorConnection.toMap]
/// produces — no field for a password/PIN/OTP/CVV/card number/credential
/// exists in that model (see account_aggregator_models.dart), so nothing
/// here can accidentally persist one either.
class AccountAggregatorConnectionRepository {
  AccountAggregatorConnectionRepository._();

  static final AccountAggregatorConnectionRepository instance = AccountAggregatorConnectionRepository._();

  static const String boxName = 'account_aggregator_connections';

  Future<Box> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return Hive.openBox(boxName);
  }

  Future<List<AccountAggregatorConnection>> getAll() async {
    final box = await _box();
    return box.values
        .map((raw) => AccountAggregatorConnection.fromMap(Map<String, dynamic>.from(raw as Map)))
        .toList();
  }

  Future<AccountAggregatorConnection?> getById(String connectionId) async {
    final box = await _box();
    final raw = box.get(connectionId);
    if (raw == null) return null;
    return AccountAggregatorConnection.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> upsert(AccountAggregatorConnection connection) async {
    final box = await _box();
    await box.put(connection.connectionId, connection.toMap());
  }

  /// Removes the connection record entirely (a full "Disconnect", not a
  /// revoke — see PHASE 15's rule: revoking consent must never delete
  /// already-ingested historical `Transaction`s, which this method
  /// doesn't touch at all; it only removes the connection metadata
  /// itself).
  Future<void> delete(String connectionId) async {
    final box = await _box();
    await box.delete(connectionId);
  }
}
