import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:paysense/core/services/notification_service.dart';
import 'package:paysense/shared/models/bill.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/bill_repository.dart';

final billRepositoryProvider = Provider<BillRepository>((ref) {
  return BillRepository.instance;
});

final billsProvider = AsyncNotifierProvider<BillsNotifier, List<Bill>>(
  BillsNotifier.new,
);

/// Unpaid bills that are overdue or due within 7 days, overdue first then
/// soonest due date.
final upcomingBillsProvider = Provider<List<Bill>>((ref) {
  final all = ref.watch(billsProvider).value ?? const <Bill>[];
  final now = DateTime.now();

  final relevant =
      all.where((bill) => bill.isOverdue(now) || bill.isUpcoming(now)).toList()
        ..sort((a, b) {
          final aOverdue = a.isOverdue(now);
          final bOverdue = b.isOverdue(now);
          if (aOverdue != bOverdue) {
            return aOverdue ? -1 : 1;
          }
          return a.dueDate.compareTo(b.dueDate);
        });
  return relevant;
});

final overdueBillsProvider = Provider<List<Bill>>((ref) {
  final all = ref.watch(billsProvider).value ?? const <Bill>[];
  final now = DateTime.now();
  return all.where((bill) => bill.isOverdue(now)).toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
});

final billTotalsProvider = Provider<BillTotals>((ref) {
  final all = ref.watch(billsProvider).value ?? const <Bill>[];
  final now = DateTime.now();
  final unpaid = all.where((bill) => !bill.isPaid).toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  final overdue = unpaid.where((bill) => bill.isOverdue(now)).length;
  final totalUnpaidAmount = unpaid.fold<double>(
    0,
    (sum, bill) => sum + bill.amount,
  );

  return BillTotals(
    totalBills: all.length,
    unpaidBills: unpaid.length,
    overdueBills: overdue,
    totalUnpaidAmount: totalUnpaidAmount,
    nextBillTitle: unpaid.isEmpty ? '' : unpaid.first.title,
    nextBillDueDate: unpaid.isEmpty ? null : unpaid.first.dueDate,
  );
});

class BillTotals {
  BillTotals({
    required this.totalBills,
    required this.unpaidBills,
    required this.overdueBills,
    required this.totalUnpaidAmount,
    required this.nextBillTitle,
    required this.nextBillDueDate,
  });

  final int totalBills;
  final int unpaidBills;
  final int overdueBills;
  final double totalUnpaidAmount;
  final String nextBillTitle;
  final DateTime? nextBillDueDate;
}

class BillsNotifier extends AsyncNotifier<List<Bill>> {
  @override
  Future<List<Bill>> build() async {
    final repository = ref.watch(billRepositoryProvider);
    final bills = await repository.getAll();
    await _rescheduleReminders(bills);
    return bills;
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Bill>>(() async {
      final repository = ref.read(billRepositoryProvider);
      final bills = await repository.getAll();
      await _rescheduleReminders(bills);
      return bills;
    });
  }

  Future<void> addBill(Bill bill) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Bill>>(() async {
      final repository = ref.read(billRepositoryProvider);
      await repository.add(bill);
      final bills = await repository.getAll();
      await _rescheduleReminders(bills);
      return bills;
    });
  }

  Future<void> updateBill(Bill bill) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Bill>>(() async {
      final repository = ref.read(billRepositoryProvider);
      await repository.update(bill);
      final bills = await repository.getAll();
      await _rescheduleReminders(bills);
      return bills;
    });
  }

  Future<bool> deleteBill(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard<bool>(() async {
      final repository = ref.read(billRepositoryProvider);
      final success = await repository.delete(id);
      await NotificationService.instance.cancelReminder(id);
      final bills = await repository.getAll();
      await _rescheduleReminders(bills);
      state = AsyncData(bills);
      return success;
    });
    return result.value ?? false;
  }

  /// Marks a bill paid: records a real expense [Transaction], deducts the
  /// paying wallet, and (for recurring bills) rolls the bill forward to its
  /// next due date and reopens it as unpaid.
  Future<void> markPaid(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Bill>>(() async {
      final repository = ref.read(billRepositoryProvider);
      final bill = await repository.getById(id);
      if (bill == null) {
        return repository.getAll();
      }

      final now = DateTime.now();
      final transactionRepository = ref.read(transactionRepositoryProvider);
      final walletRepository = ref.read(walletRepositoryProvider);

      await transactionRepository.add(
        Transaction(
          id: const Uuid().v4(),
          title: bill.title,
          amount: bill.amount,
          categoryId: bill.categoryId,
          accountId: bill.accountId,
          transactionType: 'expense',
          paymentMethod: 'bill',
          note: bill.note,
          createdAt: now,
        ),
      );

      final walletId = resolveBillWalletId(bill.accountId);
      await walletRepository.decreaseBalance(walletId, bill.amount);

      final updated = bill.markPaid(now);
      await repository.update(updated);

      ref.invalidate(transactionsProvider);
      ref.invalidate(walletsProvider);

      final bills = await repository.getAll();
      await _rescheduleReminders(bills);
      return bills;
    });
  }

  Future<void> markUnpaid(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Bill>>(() async {
      final repository = ref.read(billRepositoryProvider);
      final bill = await repository.getById(id);
      if (bill == null) {
        return repository.getAll();
      }

      await repository.update(bill.markUnpaid());
      final bills = await repository.getAll();
      await _rescheduleReminders(bills);
      return bills;
    });
  }

  Future<void> _rescheduleReminders(List<Bill> bills) async {
    final remindersEnabled = AppSettingsRepository.instance.billRemindersEnabled();
    for (final bill in bills) {
      if (bill.isPaid || !remindersEnabled) {
        await NotificationService.instance.cancelReminder(bill.id);
        continue;
      }
      await NotificationService.instance.scheduleReminder(
        id: bill.id,
        title: 'Bill due soon: ${bill.title}',
        body: '₹${bill.amount.toStringAsFixed(0)} due ${_formatDate(bill.dueDate)}',
        scheduledDate: bill.reminderDate,
      );
    }
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

/// Maps a display account name to the wallet id used for balance updates,
/// mirroring the mapping used by the manual add expense screen and by
/// recurring transaction generation.
String resolveBillWalletId(String? account) {
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
