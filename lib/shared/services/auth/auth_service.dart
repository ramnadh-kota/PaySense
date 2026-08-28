/// MILESTONE 1 — REAL USER AUTHENTICATION. The contract a production
/// cloud-backed identity provider must satisfy — mirrors the same
/// interface/implementation pattern already established in this codebase
/// for `AccountAggregatorProvider` and `BillingService` (an abstract
/// contract + a concrete implementation, swapped via one provider
/// binding, never scattered through call sites).
///
/// PaySense's EXISTING local authentication (`AuthNotifier` +
/// `AccountRepository` + `AuthSessionRepository` + `PasswordHasher`, see
/// `lib/shared/providers/auth_provider.dart`) is NOT rebuilt or wrapped
/// by this interface — it already works, is fully tested, and remains
/// the app's live sign-up/login/logout path. This interface exists
/// specifically for the capabilities local storage genuinely cannot
/// provide (real email verification, real password-reset email
/// delivery) — see [FirebaseAuthService] for the one concrete
/// implementation, and its own class doc for exactly why it is not
/// wired into the running app yet.
abstract class AuthService {
  /// Creates a new account with [email]/[password] and sends a
  /// verification email. Throws on a duplicate account or invalid input.
  Future<void> signUp({required String email, required String password});

  /// Signs in with [email]/[password]. Throws on invalid credentials.
  Future<void> login({required String email, required String password});

  Future<void> logout();

  /// Sends a password-reset email to [email]. Never reveals whether the
  /// address has an account (that check happens, if at all, only on the
  /// provider's own server) — the UI must show the same success message
  /// regardless.
  Future<void> sendPasswordResetEmail(String email);

  /// Sends (or re-sends) a verification email to the currently signed-in
  /// user.
  Future<void> sendEmailVerification();

  /// Re-fetches the current user's state from the identity provider so
  /// [isEmailVerified] reflects a just-completed verification.
  Future<void> reloadCurrentUser();

  /// Null when signed out.
  String? get currentUserEmail;

  bool get isEmailVerified;

  /// True once this backend is genuinely configured with real
  /// credentials (never true for a placeholder/unconfigured backend) —
  /// callers use this to decide whether to offer cloud sign-in at all,
  /// per the "never fabricate a working integration" rule.
  bool get isConfigured;
}
