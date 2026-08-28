import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth/auth_service.dart';
import '../services/auth/firebase_auth_service.dart';

/// MILESTONE — exposes the (currently dormant) cloud [AuthService] to the
/// UI layer, so screens that need capabilities local auth genuinely can't
/// provide (real password-reset email, real email verification) can
/// check [AuthService.isConfigured] and degrade honestly — see
/// `FirebaseAuthService`'s own class doc for exactly why it isn't active.
/// This does NOT replace or duplicate the app's live local auth
/// (`authProvider`/`AuthNotifier`), which remains the only path that
/// actually signs a user in today.
final authServiceProvider = Provider<AuthService>((ref) => FirebaseAuthService());
