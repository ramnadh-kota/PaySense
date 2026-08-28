import '../models/entitlement.dart';
import '../repositories/account_aggregator_connection_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/app_settings_repository.dart';
import '../repositories/auth_session_repository.dart';
import '../repositories/bill_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/entitlement_repository.dart';
import '../repositories/financial_safety_dismissed_repository.dart';
import '../repositories/goal_repository.dart';
import '../repositories/loan_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/recent_search_repository.dart';
import '../repositories/recurring_transaction_repository.dart';
import '../repositories/sms_fingerprint_repository.dart';
import '../repositories/sms_review_repository.dart';
import '../repositories/tax_settings_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../repositories/wallet_repository.dart';
import '../../core/services/notification_service.dart';

/// ACCOUNT DELETION — PHASE N. Deletes EVERY local trace of the user's
/// data: financial records (mirroring `SettingsNotifier.clearFinancialData`'s
/// exact box-clearing pattern), the Account Aggregator connection
/// metadata, the local login credential, the auth session, the cached
/// (mock) entitlement, any dismissed-alert state, notification history,
/// search history, SMS-derived review items/fingerprints, tax settings,
/// and the app-lock PIN hash. Every Hive-backed repository that can hold
/// user-identifiable data must have a line here — this list was audited
/// against the full `lib/shared/repositories/` directory on 2026-08-27 to
/// close gaps where "delete my account" silently left data behind.
///
/// BACKEND NOTE: PaySense has no server-side account system (confirmed
/// during the Account Aggregator audit — auth is fully local/on-device).
/// There is therefore no backend deletion request to send today. If a
/// server-side identity is ever introduced, the hook point is
/// [deleteEverythingLocally]'s caller — send the backend deletion request
/// BEFORE calling this (so a failed backend call doesn't leave the user
/// locked out of an account that still exists server-side with no local
/// record of it), then call this to guarantee no financial data is left
/// behind locally regardless of backend outcome.
class AccountDeletionService {
  AccountDeletionService._();

  static Future<void> deleteEverythingLocally(String email) async {
    await _clearAll(TransactionRepository.instance.getAll, TransactionRepository.instance.delete);
    await _clearAll(WalletRepository.instance.getAll, WalletRepository.instance.delete);
    await _clearAll(BudgetRepository.instance.getAll, BudgetRepository.instance.delete);
    await _clearAll(GoalRepository.instance.getAll, GoalRepository.instance.delete);
    await _clearAll(RecurringTransactionRepository.instance.getAll, RecurringTransactionRepository.instance.delete);
    await _clearAll(BillRepository.instance.getAll, BillRepository.instance.delete);
    await _clearAll(LoanRepository.instance.getAll, LoanRepository.instance.delete);

    final connections = await AccountAggregatorConnectionRepository.instance.getAll();
    for (final connection in connections) {
      await AccountAggregatorConnectionRepository.instance.delete(connection.connectionId);
    }

    await FinancialSafetyDismissedRepository.instance.clearAll();
    await UserProfileRepository.instance.clearProfile();

    // Reset the local mock entitlement rather than deleting the box
    // outright (it's shared with app_settings) — functionally equivalent
    // to "no entitlement remains" for this account.
    await EntitlementRepository.instance.setPlanTier(PlanTier.free);
    await EntitlementRepository.instance.setFoundingUser(false);

    await NotificationService.instance.cancelAll();
    await NotificationRepository.instance.clearAll();
    await RecentSearchRepository.instance.clear();
    await SmsReviewRepository.instance.clearAll();
    await SmsFingerprintRepository.instance.clearAll();
    await TaxSettingsRepository.instance.clear();
    await AppSettingsRepository.instance.clearPin();

    await AuthSessionRepository.instance.clearSession();
    await AccountRepository.instance.delete(email);
  }

  static Future<void> _clearAll<T>(
    Future<List<T>> Function() getAll,
    Future<dynamic> Function(String id) delete,
  ) async {
    final items = await getAll();
    for (final item in items) {
      final id = (item as dynamic).id as String;
      await delete(id);
    }
  }
}
