import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/providers/notification_provider.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/sms_review_repository.dart';

final smsReviewRepositoryProvider = Provider<SmsReviewRepository>((ref) {
  return SmsReviewRepository.instance;
});

/// All pending (not yet accepted/ignored) SMS-detected transactions
/// awaiting user confirmation.
final smsReviewItemsProvider =
    AsyncNotifierProvider<SmsReviewNotifier, List<SmsReviewItem>>(
      SmsReviewNotifier.new,
    );

class SmsReviewNotifier extends AsyncNotifier<List<SmsReviewItem>> {
  /// Review item ids with an `acceptItem` call currently in flight. Guards
  /// against a duplicate transaction + double wallet balance mutation if
  /// Accept is tapped again (e.g. a rapid double-tap) before the first
  /// call's `SmsReviewStatus.accepted` write lands — the `item.status !=
  /// pending` check alone isn't enough, since that's read at the START of
  /// the method, before the transaction/balance mutation, and only
  /// overwritten at the END. Mirrors the existing `_pendingMarkPaid`/
  /// `_pendingEmiPayments` guards used for the same class of risk in
  /// bill_provider.dart/loan_provider.dart.
  final Set<String> _pendingAccepts = {};

  @override
  Future<List<SmsReviewItem>> build() async {
    final repository = ref.watch(smsReviewRepositoryProvider);
    return repository.getPending();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    final repository = ref.read(smsReviewRepositoryProvider);
    state = await AsyncValue.guard(() => repository.getPending());
  }

  /// Confirms a review item: creates the real [Transaction] (accountId is
  /// always a real [Wallet.id], never a display label), mutates the
  /// chosen wallet's balance exactly once, marks the item accepted, and
  /// notifies — mirroring exactly what an auto-added high-confidence SMS
  /// transaction does, just with the user picking (or confirming) the
  /// wallet first instead of it being inferred.
  Future<void> acceptItem(String id, {required String walletId}) async {
    if (!_pendingAccepts.add(id)) {
      // Already processing this item's acceptance — ignore the duplicate
      // trigger instead of creating a second transaction/balance mutation.
      return;
    }
    try {
      final repository = ref.read(smsReviewRepositoryProvider);
      final item = await repository.getById(id);
      if (item == null || item.status != SmsReviewStatus.pending) {
        return;
      }

      final walletRepository = ref.read(walletRepositoryProvider);
      final wallet = await walletRepository.getById(walletId);
      if (wallet == null) {
        return;
      }

      final transactionRepository = ref.read(transactionRepositoryProvider);
      final isExpense = item.direction == SmsReviewDirection.debit;
      final title = item.merchant ?? (isExpense ? 'Card/UPI payment' : 'Bank credit');

      await transactionRepository.add(
        Transaction(
          id: const Uuid().v4(),
          title: title,
          amount: item.amount,
          categoryId: isExpense ? 'Uncategorized' : 'Income',
          accountId: wallet.id,
          transactionType: isExpense ? 'expense' : 'income',
          paymentMethod: 'sms',
          note: '',
          createdAt: item.timestamp,
        ),
      );

      if (isExpense) {
        await walletRepository.decreaseBalance(wallet.id, item.amount);
      } else {
        await walletRepository.increaseBalance(wallet.id, item.amount);
      }

      await repository.update(
        item.copyWith(status: SmsReviewStatus.accepted, suggestedWalletId: wallet.id),
      );

      ref.invalidate(transactionsProvider);
      ref.invalidate(walletsProvider);

      await ref.read(notificationsProvider.notifier).addIfNotExists(
        AppNotification(
          id: 'sms-accepted:${item.id}',
          title: 'Transaction added',
          message: isExpense
              ? '₹${item.amount.toStringAsFixed(0)} spent'
                  '${item.merchant != null ? ' at ${item.merchant}' : ''} — ${wallet.name}'
              : '₹${item.amount.toStringAsFixed(0)} received — ${wallet.name}',
          type: NotificationType.smsTransaction.name,
          createdAt: DateTime.now(),
          relatedRoute: AppRoutes.transactions,
        ),
      );

      await reload();
    } finally {
      _pendingAccepts.remove(id);
    }
  }

  /// Dismisses a review item without ever creating a transaction or
  /// touching any wallet balance.
  Future<void> ignoreItem(String id) async {
    final repository = ref.read(smsReviewRepositoryProvider);
    final item = await repository.getById(id);
    if (item == null || item.status != SmsReviewStatus.pending) {
      return;
    }
    await repository.update(item.copyWith(status: SmsReviewStatus.ignored));
    await reload();
  }
}
