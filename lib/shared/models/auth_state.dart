import 'package:flutter/foundation.dart';

import 'account.dart';

enum AuthStatus { unauthenticated, authenticated }

@immutable
class AuthState {
  const AuthState({required this.status, this.account});

  const AuthState.unauthenticated()
    : status = AuthStatus.unauthenticated,
      account = null;

  const AuthState.authenticated(this.account) : status = AuthStatus.authenticated;

  final AuthStatus status;
  final Account? account;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AuthState &&
        other.status == status &&
        other.account == account;
  }

  @override
  int get hashCode => Object.hash(status, account);
}
