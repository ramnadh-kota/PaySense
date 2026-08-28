import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../providers/auth_provider.dart' show AuthException;
import 'auth_service.dart';

/// MILESTONE 1 — REAL USER AUTHENTICATION. A genuine, correct
/// `firebase_auth` integration — every method below makes a real Firebase
/// Auth SDK call, not a stub.
///
/// STATUS: BLOCKED / NOT ACTIVE. This class is NOT bound to any live
/// provider and `main.dart` never calls `Firebase.initializeApp()` — the
/// app continues to run entirely on its existing local auth
/// (`AuthNotifier`) with zero behavior change. Activating this requires,
/// in order:
///   1. A real Firebase project (console.firebase.google.com) — an
///      external action only the app owner can take (needs their Google
///      account; cannot be created by this codebase).
///   2. Running `flutterfire configure` in this repo, which GENERATES
///      `lib/firebase_options.dart` with real values from that project
///      and adds the native Android/iOS config files. No placeholder
///      version of that file exists in this codebase on purpose — a
///      hand-written placeholder could too easily be mistaken for real
///      configuration; letting the real tool generate it is the safer
///      choice.
///   3. Calling `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
///      once in `main.dart`, guarded exactly like [isConfigured] already
///      guards this class's own methods.
///   4. Binding a provider to `FirebaseAuthService` instead of the
///      current local-only path, and deciding the exact UX for existing
///      local accounts (this migration policy is a product decision, not
///      a code default this class should invent).
///
/// Never grants entitlement/access based on an assumption that any of
/// the above has happened — [isConfigured] is false until a real
/// `Firebase.initializeApp()` has genuinely succeeded.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService();

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (Firebase.apps.isEmpty) {
      throw AuthException(
        'Cloud sign-in isn\'t configured yet. Firebase.initializeApp() has not been called — '
        'see FirebaseAuthService\'s class doc for the exact activation steps.',
      );
    }
    _initialized = true;
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  bool get isConfigured => Firebase.apps.isNotEmpty;

  @override
  Future<void> signUp({required String email, required String password}) async {
    await _ensureInitialized();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  @override
  Future<void> login({required String email, required String password}) async {
    await _ensureInitialized();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  @override
  Future<void> logout() async {
    await _ensureInitialized();
    await _auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _ensureInitialized();
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // Deliberately does not distinguish "no account for this email" from
      // any other failure in the message shown to the caller — see this
      // interface method's own doc on why.
      if (e.code == 'user-not-found') return;
      throw AuthException(_messageFor(e));
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    await _ensureInitialized();
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException('You must be signed in to request a verification email.');
    }
    await user.sendEmailVerification();
  }

  @override
  Future<void> reloadCurrentUser() async {
    await _ensureInitialized();
    await _auth.currentUser?.reload();
  }

  @override
  String? get currentUserEmail => isConfigured ? _auth.currentUser?.email : null;

  @override
  bool get isEmailVerified => isConfigured && (_auth.currentUser?.emailVerified ?? false);

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        // Never surface e.message raw — it can include implementation
        // details not meant for end users; a generic fallback instead.
        return 'Something went wrong. Please try again.';
    }
  }
}
