import 'package:hive/hive.dart';
import 'package:paysense/shared/models/account.dart';

class AccountRepository {
  AccountRepository._();

  static final AccountRepository instance = AccountRepository._();

  static const String _boxName = 'accounts';

  Box<Account> get _box => Hive.box<Account>(_boxName);

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  Future<Account?> getByEmail(String email) async {
    return _box.get(normalizeEmail(email));
  }

  Future<bool> exists(String email) async {
    return _box.containsKey(normalizeEmail(email));
  }

  Future<void> add(Account account) async {
    await _box.put(account.email, account);
  }

  Future<void> update(Account account) async {
    if (_box.containsKey(account.email)) {
      await _box.put(account.email, account);
    }
  }

  /// ACCOUNT DELETION — removes the local login credential record
  /// entirely. Never used for anything short of a full account deletion;
  /// logging out uses [AuthSessionRepository.clearSession] instead, which
  /// leaves this record intact so the user can log back in.
  Future<void> delete(String email) async {
    await _box.delete(normalizeEmail(email));
  }
}
