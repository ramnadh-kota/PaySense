import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../models/auth_state.dart';
import '../models/user_profile.dart';
import '../repositories/account_repository.dart';
import '../repositories/auth_session_repository.dart';
import '../services/account_scope.dart';
import '../utils/password_hasher.dart';
import '../utils/transaction_account_migration.dart';
import 'user_profile_provider.dart';

/// Thrown for user-facing authentication failures (invalid credentials,
/// duplicate account, etc.) so screens can show a message without treating
/// it as an unexpected error.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository.instance;
});

final authSessionRepositoryProvider = Provider<AuthSessionRepository>((ref) {
  return AuthSessionRepository.instance;
});

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final sessionRepo = ref.read(authSessionRepositoryProvider);
    final email = sessionRepo.currentEmail();
    if (email == null) {
      return const AuthState.unauthenticated();
    }

    final account = await ref.read(accountRepositoryProvider).getByEmail(email);
    if (account == null) {
      await sessionRepo.clearSession();
      return const AuthState.unauthenticated();
    }

    await _activateAccountData(account.id);
    return AuthState.authenticated(account);
  }

  /// Opens (and, on the very first activation ever, migrates legacy
  /// pre-isolation data into) [accountId]'s own namespace, then runs the
  /// existing per-account transaction/wallet-id cleanup against it. Must
  /// happen before any screen for this account can read financial data.
  Future<void> _activateAccountData(String accountId) async {
    await AccountScope.instance.activate(accountId);
    await TransactionAccountMigrationRunner.runIfNeeded(accountId: accountId);
  }

  /// Creates a new local account and signs the user in. Also eagerly creates
  /// the shared [UserProfile] record (if one doesn't already exist) so the
  /// account is connected to the existing profile system rather than
  /// introducing a second one.
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final accountRepo = ref.read(accountRepositoryProvider);
    final normalizedEmail = AccountRepository.normalizeEmail(email);

    if (await accountRepo.exists(normalizedEmail)) {
      throw AuthException('An account with this email already exists.');
    }

    state = const AsyncValue.loading();

    final now = DateTime.now();
    final salt = PasswordHasher.generateSalt();
    final account = Account(
      id: const Uuid().v4(),
      email: normalizedEmail,
      fullName: fullName.trim(),
      passwordHash: PasswordHasher.hash(password, salt),
      passwordSalt: salt,
      createdAt: now,
      updatedAt: now,
    );
    await accountRepo.add(account);
    await _activateAccountData(account.id);

    final profileRepo = ref.read(userProfileRepositoryProvider);
    final existingProfile = await profileRepo.getProfile();
    if (existingProfile == null) {
      await profileRepo.saveProfile(
        UserProfile(
          id: 'profile',
          fullName: fullName.trim(),
          email: normalizedEmail,
          createdAt: now,
          updatedAt: now,
        ),
      );
      ref.invalidate(userProfileProvider);
    }

    await ref.read(authSessionRepositoryProvider).setSession(normalizedEmail);
    state = AsyncValue.data(AuthState.authenticated(account));
  }

  Future<void> login({required String email, required String password}) async {
    final normalizedEmail = AccountRepository.normalizeEmail(email);
    state = const AsyncValue.loading();

    final account = await ref
        .read(accountRepositoryProvider)
        .getByEmail(normalizedEmail);
    final valid =
        account != null &&
        PasswordHasher.verify(password, account.passwordSalt, account.passwordHash);

    if (!valid) {
      state = const AsyncValue.data(AuthState.unauthenticated());
      throw AuthException('Invalid email or password.');
    }

    await _activateAccountData(account.id);
    await ref.read(authSessionRepositoryProvider).setSession(normalizedEmail);
    state = AsyncValue.data(AuthState.authenticated(account));
  }

  /// Changes the password for the currently authenticated account. Verifies
  /// [currentPassword] against the stored hash before writing a new
  /// salted hash — never handles or stores plaintext.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentAccount = state.value?.account;
    if (currentAccount == null) {
      throw AuthException('You must be logged in to change your password.');
    }

    final isCurrentValid = PasswordHasher.verify(
      currentPassword,
      currentAccount.passwordSalt,
      currentAccount.passwordHash,
    );
    if (!isCurrentValid) {
      throw AuthException('Current password is incorrect.');
    }

    final salt = PasswordHasher.generateSalt();
    final updatedAccount = currentAccount.copyWith(
      passwordHash: PasswordHasher.hash(newPassword, salt),
      passwordSalt: salt,
      updatedAt: DateTime.now(),
    );

    await ref.read(accountRepositoryProvider).update(updatedAccount);
    state = AsyncValue.data(AuthState.authenticated(updatedAccount));
  }

  /// Clears only the authenticated session. Financial data (profile, wallet,
  /// transactions, etc.) is never touched.
  Future<void> logout() async {
    await ref.read(authSessionRepositoryProvider).clearSession();
    AccountScope.instance.deactivate();
    state = const AsyncValue.data(AuthState.unauthenticated());
  }

  /// Permanently deletes the currently authenticated account: verifies
  /// [password], then purges only that account's own namespaced data
  /// (transactions, wallets, budgets, goals, bills, loans, recurring
  /// transactions, notifications, SMS review/fingerprint data, tax
  /// settings, profile) and removes the account itself. Every other
  /// account's data on this device is untouched — [AccountScope] only ever
  /// deletes boxes namespaced to this specific account id.
  Future<void> deleteAccount({required String password}) async {
    final currentAccount = state.value?.account;
    if (currentAccount == null) {
      throw AuthException('You must be logged in to delete your account.');
    }

    final isValid = PasswordHasher.verify(
      password,
      currentAccount.passwordSalt,
      currentAccount.passwordHash,
    );
    if (!isValid) {
      throw AuthException('Incorrect password.');
    }

    await AccountScope.instance.purgeAccountData(currentAccount.id);
    await ref.read(accountRepositoryProvider).delete(currentAccount.email);
    await ref.read(authSessionRepositoryProvider).clearSession();

    state = const AsyncValue.data(AuthState.unauthenticated());
  }
}
