import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:paysense/core/services/notification_service.dart';
import 'package:paysense/shared/models/recurring_transaction.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';

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
    final monthlyAmount = _monthlyEquivalent(item.amount, item.frequency);
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

double _monthlyEquivalent(double amount, String frequency) {
  switch (frequency) {
    case 'Daily':
      return amount * 30;
    case 'Weekly':
      return amount * (30 / 7);
    case 'Yearly':
      return amount / 12;
    case 'Monthly':
    default:
      return amount;
  }
}

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
    final now = DateTime.now();
    final items = await repository.getAll();
    final transactionRepository = ref.read(transactionRepositoryProvider);
    final walletRepository = ref.read(walletRepositoryProvider);
    var didGenerate = false;

    for (final item in items) {
      var current = item;
      var iterations = 0;
      // Cap iterations so a long-neglected recurring definition can't spin
      // forever generating history; it catches up to "now" instead.
      while (current.isDue(now) && iterations < 366) {
        await transactionRepository.add(
          Transaction(
            id: const Uuid().v4(),
            title: current.title,
            amount: current.amount,
            categoryId: current.categoryId,
            accountId: current.accountId,
            transactionType: current.transactionType,
            paymentMethod: 'recurring',
            note: current.note,
            createdAt: current.nextDueDate,
          ),
        );

        final walletId = resolveRecurringWalletId(current.accountId);
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
  }

  Future<void> _rescheduleReminders(List<RecurringTransaction> items) async {
    final remindersEnabled =
        AppSettingsRepository.instance.recurringRemindersEnabled();
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
