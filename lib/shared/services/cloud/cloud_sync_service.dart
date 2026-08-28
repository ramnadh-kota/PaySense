/// MILESTONE 2 — USER-SCOPED CLOUD DATA FOUNDATION.
///
/// STATUS: BLOCKED. This is the minimal, safe foundation possible
/// without a real cloud backend — an identity boundary and a sync
/// abstraction, NOT working bidirectional sync. Writing real
/// `cloud_firestore` read/write/merge code against security rules that
/// don't exist yet, which can't be verified against a live project in
/// this environment, is exactly the kind of "fabricated successful cloud
/// synchronization" this milestone explicitly forbids — so that code is
/// deliberately not written here. What IS real: the ownership model
/// below, the abstraction every screen would call through, and the
/// always-safe no-op default that keeps the app fully local-first.
///
/// INTENDED DATA OWNERSHIP MODEL (documented, not yet implemented):
/// ```
/// users/{userId}/
///   profile              — UserProfile (name, currency, income fields)
///   wallets/{walletId}
///   transactions/{transactionId}
///   budgets/{budgetId}
///   goals/{goalId}
///   loans/{loanId}
///   bills/{billId}
///   recurringTransactions/{id}
///   syncMetadata         — { lastSyncedAt, deviceId }
/// ```
/// Every document lives under the authenticated user's own `userId`
/// path segment — the ONLY way Firestore security rules can guarantee
/// isolation is `allow read, write: if request.auth.uid == userId;`
/// scoped to that exact path prefix, applied identically to every
/// collection above. No cross-user read is possible if every rule is
/// written this way; this is a security-rules decision to make and test
/// against the real project once one exists, not something the client
/// code alone can enforce.
///
/// SYNC POLICY (documented, not yet implemented): local Hive storage
/// remains the source of truth for reads at all times (this NEVER
/// changes — see the milestone's own "do not remove the existing
/// local-first architecture" rule). A future real implementation would
/// push local writes up opportunistically and pull remote changes down
/// on an explicit trigger (app foreground / manual "Sync now"), NEVER an
/// automatic destructive merge — any real conflict must be surfaced to
/// the user, never silently resolved by last-write-wins.
enum CloudSyncStatus { offline, disabled, syncing, synced, error }

abstract class CloudSyncService {
  bool get isAvailable;
  CloudSyncStatus get status;

  /// Pushes local changes to the cloud. A no-op (never throws, never
  /// pretends to succeed) when [isAvailable] is false.
  Future<void> syncUp();

  /// Pulls remote changes down. Same no-op guarantee as [syncUp].
  Future<void> syncDown();
}

/// The ONLY implementation bound today — matches [FirebaseAuthService]'s
/// "blocked until a real project exists" status exactly. Every method is
/// a genuine no-op, never a fabricated success.
class NoOpCloudSyncService implements CloudSyncService {
  const NoOpCloudSyncService();

  @override
  bool get isAvailable => false;

  @override
  CloudSyncStatus get status => CloudSyncStatus.disabled;

  @override
  Future<void> syncUp() async {}

  @override
  Future<void> syncDown() async {}
}
