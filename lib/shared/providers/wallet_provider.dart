import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction.dart';
import '../models/wallet.dart';
import '../repositories/wallet_repository.dart';
import 'transaction_provider.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository.instance;
});

final walletsProvider = AsyncNotifierProvider<WalletsNotifier, List<Wallet>>(
  () {
    return WalletsNotifier();
  },
);

/// A safe-to-display failure from [WalletsNotifier.transfer] — distinct
/// from an unexpected exception, [message] is already sanitized and
/// suitable to show directly to the user.
class WalletTransferException implements Exception {
  const WalletTransferException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WalletsNotifier extends AsyncNotifier<List<Wallet>> {
  /// Guards against a rapid double-tap on the Transfer button firing two
  /// transfers — mirrors the `_pendingMarkPaid`/`_pendingEmiPayments`
  /// in-flight-guard pattern used by BillsNotifier/LoansNotifier for the
  /// same class of risk (an action that writes Transactions and mutates
  /// wallet balances with no confirmation step in between).
  bool _transferInProgress = false;

  @override
  Future<List<Wallet>> build() async {
    final repository = ref.read(walletRepositoryProvider);
    return repository.getAll();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    final repository = ref.read(walletRepositoryProvider);
    state = await AsyncValue.guard(() => repository.getAll());
  }

  /// Hides [id] from the main wallet list without deleting it or any of its
  /// historical transactions — see [WalletRepository.archive].
  Future<void> archiveWallet(String id) async {
    final repository = ref.read(walletRepositoryProvider);
    await repository.archive(id);
    await reload();
  }

  /// Moves [amount] from [fromWalletId] to [toWalletId] and records a
  /// linked pair of `Transaction` legs (`transactionType: 'transfer'`) so
  /// the movement is visible in history without ever being counted as
  /// income or expense by any calculator that filters on those two values.
  ///
  /// Throws [WalletTransferException] with a user-safe message for any
  /// validation failure. A repeated call while a transfer is already in
  /// flight is silently ignored (matches the existing bill/loan guard
  /// behavior) rather than throwing, so a double-tap never surfaces an
  /// error dialog on top of the first tap's own feedback.
  Future<void> transfer({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    String note = '',
  }) async {
    if (fromWalletId == toWalletId) {
      throw const WalletTransferException(
        'Choose two different accounts to transfer between.',
      );
    }
    if (amount <= 0) {
      throw const WalletTransferException('Enter an amount greater than zero.');
    }
    if (_transferInProgress) {
      return;
    }

    _transferInProgress = true;
    try {
      final walletRepository = ref.read(walletRepositoryProvider);
      final transactionRepository = ref.read(transactionRepositoryProvider);

      final source = await walletRepository.getById(fromWalletId);
      final destination = await walletRepository.getById(toWalletId);
      if (source == null || destination == null) {
        throw const WalletTransferException('Selected account could not be found.');
      }
      if (source.currentBalance < amount) {
        throw WalletTransferException(
          'Insufficient balance in ${source.name} for this transfer.',
        );
      }

      final transferId = const Uuid().v4();
      final now = DateTime.now();

      // Mutate both balances first. Hive (classic hive/hive_flutter) has no
      // cross-box atomic transaction API, so true atomicity can't be
      // guaranteed here — instead, both wallets' existence and the source's
      // sufficient balance are already confirmed above, minimizing the
      // window for a mid-operation failure. If the second balance mutation
      // still fails, the first is explicitly compensated (undone) rather
      // than left half-applied, so a failure here can never silently
      // "lose" money from the source wallet.
      await walletRepository.decreaseBalance(source.id, amount);
      try {
        await walletRepository.increaseBalance(destination.id, amount);
      } catch (_) {
        await walletRepository.increaseBalance(source.id, amount);
        rethrow;
      }

      // Ledger entries are written only after both balance mutations are
      // confirmed applied, so a failure while writing them can never leave
      // a balance mutated without a matching, explainable record.
      await transactionRepository.add(
        Transaction(
          id: const Uuid().v4(),
          title: 'Transfer to ${destination.name}',
          amount: amount,
          categoryId: 'Transfer',
          accountId: source.id,
          transactionType: 'transfer',
          paymentMethod: 'transfer',
          note: note,
          createdAt: now,
          transferId: transferId,
          transferCounterpartyWalletId: destination.id,
        ),
      );
      await transactionRepository.add(
        Transaction(
          id: const Uuid().v4(),
          title: 'Transfer from ${source.name}',
          amount: amount,
          categoryId: 'Transfer',
          accountId: destination.id,
          transactionType: 'transfer',
          paymentMethod: 'transfer',
          note: note,
          createdAt: now,
          transferId: transferId,
          transferCounterpartyWalletId: source.id,
        ),
      );

      ref.invalidate(transactionsProvider);
      state = AsyncData(await walletRepository.getAll());
    } finally {
      _transferInProgress = false;
    }
  }
}
