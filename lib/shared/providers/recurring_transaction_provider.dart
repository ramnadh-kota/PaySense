import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/core/services/notification_service.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/providers/notification_provider.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';
import 'package:paysense/shared/utils/wallet_account_resolver.dart';

final recurringTransactionRepositoryProvider =
    Provider<RecurringTransactionRepository>((ref) {
      return RecurringTransactionRepository.instance;
    });

final recurringTransactionsProvider =
    AsyncNotifierProvider<
      RecurringTransactionsNotifier,
      List<RecurringTransaction>
    >(RecurringTransactionsNotifier.new);

/// Active recurring items due within the next 7 days, soonest first.
final upcomingPaymentsProvider = Provider<List<RecurringTransaction>>((ref) {
  final all =
      ref.watch(recurringTransactionsProvider).value ??
      const <RecurringTransaction>[];
  final now = DateTime.now();
  final horizon = now.add(const Duration(days: 7));

  final upcoming =
      all.where((item) {
        if (!item.isActive || item.isExpired) {
          return false;
        }
        return !item.nextDueDate.isAfter(horizon);
      }).toList()
        ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
  return upcoming;
});

final recurringTotalsProvider = Provider<RecurringTotals>((ref) {
  final all =
      ref.watch(recurringTransactionsProvider).value ??
      const <RecurringTransaction>[];
  final active = all.where((item) => item.isActive && !item.isExpired).toList()
    ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

  double monthlyIncome = 0;
  double monthlyExpense = 0;
  for (final item in active) {
    final monthlyAmount = item.monthlyEquivalentAmount;
    if (item.transactionType.toLowerCase() == 'income') {
      monthlyIncome += monthlyAmount;
    } else {
      monthlyExpense += monthlyAmount;
    }
  }

  return RecurringTotals(
    totalActive: active.length,
    monthlyRecurringIncome: monthlyIncome,
    monthlyRecurringExpense: monthlyExpense,
    nextPaymentTitle: active.isEmpty ? '' : active.first.title,
    nextPaymentDate: active.isEmpty ? null : active.first.nextDueDate,
  );
});

class RecurringTotals {
  RecurringTotals({
    required this.totalActive,
    required this.monthlyRecurringIncome,
    required this.monthlyRecurringExpense,
    required this.nextPaymentTitle,
    required this.nextPaymentDate,
  });

  final int totalActive;
  final double monthlyRecurringIncome;
  final double monthlyRecurringExpense;
  final String nextPaymentTitle;
  final DateTime? nextPaymentDate;
}

class RecurringTransactionsNotifier
    extends AsyncNotifier<List<RecurringTransaction>> {
  /// Guards [_generateDueTransactions] against concurrent execution.
  /// `build`/`reload`/`addRecurringTransaction`/`updateRecurringTransaction`/
  /// `deleteRecurringTransaction`/`setActive` (e.g. two rapid taps on the
  /// "Active" switch while an item happens to be due) can all trigger it;
  /// without this, two overlapping calls could each see the same
  /// not-yet-advanced due occurrence and each create a real Transaction and
  /// mutate a wallet balance for it — mirrors the existing
  /// `_pendingMarkPaid`/`_pendingEmiPayments`/`_transferInProgress` guards
  /// used for the same class of risk elsewhere in this app.
  bool _generating = false;

  @override
  Future<List<RecurringTransaction>> build() async {
    final repository = ref.watch(recurringTransactionRepositoryProvider);
    final items = await _generateDueTransactions(repository);
    await _rescheduleReminders(items);
    return items;
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<RecurringTransaction>>(() async {
      final repository = ref.read(recurringTransactionRepositoryProvider);
      final items = await _generateDueTransactions(repository);
      await _rescheduleReminders(items);
      return items;
    });
  }

  Future<void> addRecurringTransaction(RecurringTransaction item) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<RecurringTransaction>>(() async {
      final repository = ref.read(recurringTransactionRepositoryProvider);
      await repository.add(item);
      final items = await _generateDueTransactions(repository);
      await _rescheduleReminders(items);
      return items;
    });
  }

  Future<void> updateRecurringTransaction(RecurringTransaction item) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<RecurringTransaction>>(() async {
      final repository = ref.read(recurringTransactionRepositoryProvider);
      await repository.update(item);
      final items = await _generateDueTransactions(repository);
      await _rescheduleReminders(items);
      return items;
    });
  }

  Future<bool> deleteRecurringTransaction(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard<bool>(() async {
      final repository = ref.read(recurringTransactionRepositoryProvider);
      final success = await repository.delete(id);
      await NotificationService.instance.cancelReminder(id);
      final items = await _generateDueTransactions(repository);
      await _rescheduleReminders(items);
      state = AsyncData(items);
      return success;
    });
    return result.value ?? false;
  }

  Future<void> setActive(String id, bool isActive) async {
    final repository = ref.read(recurringTransactionRepositoryProvider);
    final current = await repository.getById(id);
    if (current == null) {
      return;
    }
    await updateRecurringTransaction(
      current.copyWith(isActive: isActive, updatedAt: DateTime.now()),
    );
  }

  /// Generates real [Transaction] entries (and adjusts wallet balances) for
  /// every recurring definition with one or more occurrences due, advancing
  /// each definition to its next occurrence as it goes. Returns the
  /// refreshed list of recurring transactions read back from storage.
  Future<List<RecurringTransaction>> _generateDueTransactions(
    RecurringTransactionRepository repository,
  ) async {
    if (_generating) {
      // Another call is already generating due transactions right now.
      // Running the loop again here could see the same not-yet-advanced
      // due occurrence and create a second Transaction + balance mutation
      // for it, so this returns the current persisted state untouched
      // instead — the in-flight call is the one source of truth for this
      // pass, and its own return value is what the caller that "loses"
      // the race would have gotten anyway once both finish.
      return repository.getAll();
    }

    _generating = true;
    try {
      final now = DateTime.now();
      final items = await repository.getAll();
      final transactionRepository = ref.read(transactionRepositoryProvider);
      final walletRepository = ref.read(walletRepositoryProvider);
      // Fetched once — the set of real wallets doesn't change across this
      // method's iterations, only their balances do.
      final wallets = await walletRepository.getAll();
      var didGenerate = false;

      for (final item in items) {
        var current = item;
        var iterations = 0;
        // Cap iterations so a long-neglected recurring definition can't
        // spin forever generating history; it catches up to "now" instead.
        while (current.isDue(now) && iterations < 366) {
          // Resolve to a real Wallet.id — never store current.accountId's
          // raw display label on the ledger record. Falls back to the
          // legacy synthetic mapping only for old recurring items whose
          // accountId can't be matched to any real wallet.
          final walletId =
              resolveWalletIdForAccount(current.accountId, wallets) ??
              resolveRecurringWalletId(current.accountId);

          await transactionRepository.add(
            Transaction(
              id: const Uuid().v4(),
              title: current.title,
              amount: current.amount,
              categoryId: current.categoryId,
              accountId: walletId,
              transactionType: current.transactionType,
              paymentMethod: 'recurring',
              note: current.note,
              createdAt: current.nextDueDate,
            ),
          );

          if (current.transactionType.toLowerCase() == 'income') {
            await walletRepository.increaseBalance(walletId, current.amount);
          } else {
            await walletRepository.decreaseBalance(walletId, current.amount);
          }

          current = current.advance(now);
          didGenerate = true;
          iterations++;
        }

        if (!identical(current, item)) {
          await repository.update(current);
        }
      }

      if (didGenerate) {
        ref.invalidate(transactionsProvider);
        ref.invalidate(walletsProvider);
      }

      return repository.getAll();
    } finally {
      // Always released — including on an exception — so a single failed
      // generation attempt can never permanently lock out every future
      // one.
      _generating = false;
    }
  }

  Future<void> _rescheduleReminders(List<RecurringTransaction> items) async {
    final remindersEnabled =
        AppSettingsRepository.instance.recurringRemindersEnabled();
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 7));
    for (final item in items) {
      if (!item.isActive || item.isExpired || !remindersEnabled) {
        await NotificationService.instance.cancelReminder(item.id);
        continue;
      }
      final isIncome = item.transactionType.toLowerCase() == 'income';
      await NotificationService.instance.scheduleReminder(
        id: item.id,
        title: 'Upcoming ${isIncome ? 'income' : 'payment'}: ${item.title}',
        body:
            '₹${item.amount.toStringAsFixed(0)} due ${_formatDate(item.nextDueDate)}',
        scheduledDate: item.reminderDate,
      );

      if (!item.nextDueDate.isAfter(horizon)) {
        await ref.read(notificationsProvider.notifier).addIfNotExists(
          AppNotification(
            id: 'recurring:${item.id}:${item.nextDueDate.toIso8601String()}',
            title: item.title,
            message:
                '₹${item.amount.toStringAsFixed(0)} ${isIncome ? 'expected' : 'due'} ${_formatDate(item.nextDueDate)}',
            type: NotificationType.recurringPayment.name,
            createdAt: now,
            relatedRoute: AppRoutes.recurring,
          ),
        );
      }
    }
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

/// Maps a display account name to the wallet id used for balance updates,
/// mirroring the mapping used by the manual add income/expense screens.
String resolveRecurringWalletId(String? account) {
  switch (account) {
    case 'Cash':
      return 'wallet-cash';
    case 'Checking':
    case 'Savings':
    case 'Credit Card':
    default:
      return 'wallet-hdfc-salary';
  }
}
