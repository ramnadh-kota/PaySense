// CloudSyncService's only bound implementation today is NoOpCloudSyncService
// (see its class doc — Milestone 2 is BLOCKED pending a real Firebase/
// Firestore project). These tests verify the one thing genuinely
// verifiable without a live backend: the app's local-first behavior when
// cloud sync is unavailable — it never claims availability and never
// pretends an operation succeeded. User-isolation / unauthorized-access
// tests are intentionally NOT included here: there is no real backend or
// security rules to test them against, and a test that can't fail
// against a real violation would prove nothing.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/services/cloud/cloud_sync_service.dart';

void main() {
  group('NoOpCloudSyncService — local-first default', () {
    const service = NoOpCloudSyncService();

    test('isAvailable is always false', () {
      expect(service.isAvailable, isFalse);
    });

    test('status is always disabled, never a fabricated synced/syncing state', () {
      expect(service.status, CloudSyncStatus.disabled);
    });

    test('syncUp completes without throwing and without claiming success', () async {
      await service.syncUp();
      expect(service.status, CloudSyncStatus.disabled);
    });

    test('syncDown completes without throwing and without claiming success', () async {
      await service.syncDown();
      expect(service.status, CloudSyncStatus.disabled);
    });
  });
}
