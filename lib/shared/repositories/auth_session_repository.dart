import 'package:hive/hive.dart';

class AuthSessionRepository {
  AuthSessionRepository._();

  static final AuthSessionRepository instance = AuthSessionRepository._();

  static const String _boxName = 'auth_session';
  static const String _emailKey = 'authenticatedEmail';

  Box get _box => Hive.box(_boxName);

  Future<bool> isAuthenticated() async => currentEmail() != null;

  String? currentEmail() => _box.get(_emailKey) as String?;

  Future<void> setSession(String email) async {
    await _box.put(_emailKey, email);
  }

  Future<void> clearSession() async {
    await _box.delete(_emailKey);
  }
}
