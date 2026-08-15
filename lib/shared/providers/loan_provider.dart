import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/core/services/notification_service.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/providers/notification_provider.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/loan_repository.dart';
import 'package:paysense/shared/utils/wallet_account_resolver.dart';

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  return LoanRepository.instance;
});

final loansProvider = AsyncNotifierProvider<LoansNotifier, List<Loan>>(
  LoansNotifier.new,
);

/// Active loans that are overdue or due within 7 days, overdue first then
/// soonest due date — mirrors [upcomingBillsProvider].
final upcomingLoanPaymentsProvider = Provider<List<Loan>>((ref) {
  final all = ref.watch(loansProvider).value ?? const <Loan>[];
  final now = DateTime.now();

  final relevant =
      all.where((loan) => loan.isOverdue(now) || loan.isUpcoming(now)).toList()
        ..sort((a, b) {
          final aOverdue = a.isOverdue(now);
          final bOverdue = b.isOverdue(now);
          if (aOverdue != bOverdue) {
            return aOverdue ? -1 : 1;
          }
          return a.nextDueDate.compareTo(b.nextDueDate);
        });
  return relevant;
});

final loanSummaryProvider = Provider<LoanSummary>((ref) {
  final all = ref.watch(loansProvider).value ?? const <Loan>[];
  final active = all.where((loan) => loan.isActive).toList()
    ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
  final closed = all.where((loan) => loan.isClosed).length;

  final outstandingBalance = active.fold<double>(
    0,
    (sum, loan) => sum + loan.outstandingAmount,
  );
  final totalEmiPerMonth = active.fold<double>(
    0,
    (sum, loan) => sum + loan.emiAmount,
  );
  final totalInterest = all.fold<double>(
    0,
    (sum, loan) => sum + loan.totalInterest,
  );

  final nextLoan = active.isEmpty ? null : active.first;

  return LoanSummary(
    totalLoans: all.length,
    activeLoans: active.length,
    closedLoans: closed,
    outstandingBalance: outstandingBalance,
    totalEmiPerMonth: totalEmiPerMonth,
    totalInterest: totalInterest,
    nextEmiLoanName: nextLoan?.loanName ?? '',
    nextEmiAmount: nextLoan?.emiAmount ?? 0.0,
    nextEmiDate: nextLoan?.nextDueDate,
  );
});

class LoanSummary {
  LoanSummary({
    required this.totalLoans,
    required this.activeLoans,
    required this.closedLoans,
    required this.outstandingBalance,
    required this.totalEmiPerMonth,
    required this.totalInterest,
    required this.nextEmiLoanName,
    required this.nextEmiAmount,
    required this.nextEmiDate,
  });

  final int totalLoans;
  final int activeLoans;
  final int closedLoans;
  final double outstandingBalance;
  final double totalEmiPerMonth;
  final double totalInterest;
  final String nextEmiLoanName;
  final double nextEmiAmount;
  final DateTime? nextEmiDate;
}

class LoansNotifier extends AsyncNotifier<List<Loan>> {
  /// Loan ids with a `markEmiPaid` call currently in flight. Guards against
  /// a duplicate EMI expense transaction + double wallet deduction if the
  /// action is triggered again (e.g. a rapid double-tap) before the first
  /// call finishes — there's no confirmation dialog on this action, so this
  /// is the only thing preventing that.
  final Set<String> _pendingEmiPayments = {};

  @override
  Future<List<Loan>> build() async {
    final repository = ref.watch(loanRepositoryProvider);
    final loans = await repository.getAll();
    await _rescheduleReminders(loans);
    return loans;
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Loan>>(() async {
      final repository = ref.read(loanRepositoryProvider);
      final loans = await repository.getAll();
      await _rescheduleReminders(loans);
      return loans;
    });
  }

  Future<void> addLoan(Loan loan) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Loan>>(() async {
      final repository = ref.read(loanRepositoryProvider);
      await repository.add(loan);
      final loans = await repository.getAll();
      await _rescheduleReminders(loans);
      return loans;
    });
  }

  Future<void> updateLoan(Loan loan) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Loan>>(() async {
      final repository = ref.read(loanRepositoryProvider);
      await repository.update(loan);
      final loans = await repository.getAll();
      await _rescheduleReminders(loans);
      return loans;
    });
  }

  Future<bool> deleteLoan(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard<bool>(() async {
      final repository = ref.read(loanRepositoryProvider);
      final success = await repository.delete(id);
      await _cancelReminders(id);
      final loans = await repository.getAll();
      await _rescheduleReminders(loans);
      state = AsyncData(loans);
      return success;
    });
    return result.value ?? false;
  }

  /// Marks one EMI installment paid: records a real expense [Transaction],
  /// deducts the paying wallet, and advances the loan to its next due date
  /// (or closes it out if this was the final installment).
  Future<void> markEmiPaid(String id, {double? amount}) async {
    if (!_pendingEmiPayments.add(id)) {
      // Already processing this loan's EMI payment — ignore the duplicate
      // trigger instead of recording a second transaction.
      return;
    }
    try {
      state = const AsyncLoading();
      state = await AsyncValue.guard<List<Loan>>(() async {
        final repository = ref.read(loanRepositoryProvider);
        final loan = await repository.getById(id);
        if (loan == null) {
          return repository.getAll();
        }

        final now = DateTime.now();
        final paymentAmount = amount ?? loan.emiAmount;
        final transactionRepository = ref.read(transactionRepositoryProvider);
        final walletRepository = ref.read(walletRepositoryProvider);

        // Resolve to a real Wallet.id — never store loan.accountId's raw
        // display label on the ledger record. Falls back to the legacy
        // synthetic mapping only for old loans whose accountId can't be
        // matched to any real wallet.
        final wallets = await walletRepository.getAll();
        final walletId =
            resolveWalletIdForAccount(loan.accountId, wallets) ??
            resolveLoanWalletId(loan.accountId);

        await transactionRepository.add(
          Transaction(
            id: const Uuid().v4(),
            title: '${loan.loanName} EMI',
            amount: paymentAmount,
            categoryId: loan.loanType,
            accountId: walletId,
            transactionType: 'expense',
            paymentMethod: 'loan_emi',
            note: loan.lenderName,
            createdAt: now,
          ),
        );

        await walletRepository.decreaseBalance(walletId, paymentAmount);

        final updated = loan.markEmiPaid(now, amount: paymentAmount);
        await repository.update(updated);

        ref.invalidate(transactionsProvider);
        ref.invalidate(walletsProvider);

        final loans = await repository.getAll();
        await _rescheduleReminders(loans);
        return loans;
      });
    } finally {
      _pendingEmiPayments.remove(id);
    }
  }

  Future<void> closeLoan(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Loan>>(() async {
      final repository = ref.read(loanRepositoryProvider);
      final loan = await repository.getById(id);
      if (loan == null) {
        return repository.getAll();
      }

      await repository.update(loan.closeLoan(DateTime.now()));
      await _cancelReminders(id);
      return repository.getAll();
    });
  }

  Future<void> _rescheduleReminders(List<Loan> loans) async {
    final remindersEnabled = AppSettingsRepository.instance.loanRemindersEnabled();
    final now = DateTime.now();
    for (final loan in loans) {
      if (!loan.isActive || !remindersEnabled) {
        await _cancelReminders(loan.id);
        continue;
      }

      final dueDate = loan.nextDueDate;
      final amountText = '₹${loan.emiAmount.toStringAsFixed(0)}';

      await NotificationService.instance.scheduleReminder(
        id: '${loan.id}-before',
        title: 'EMI due tomorrow: ${loan.loanName}',
        body: '$amountText due ${_formatDate(dueDate)}',
        scheduledDate: dueDate.subtract(const Duration(days: 1)),
      );
      await NotificationService.instance.scheduleReminder(
        id: '${loan.id}-due',
        title: 'EMI due today: ${loan.loanName}',
        body: '$amountText due today',
        scheduledDate: dueDate,
      );
      await NotificationService.instance.scheduleReminder(
        id: '${loan.id}-after',
        title: 'EMI missed: ${loan.loanName}',
        body: '$amountText was due ${_formatDate(dueDate)}',
        scheduledDate: dueDate.add(const Duration(days: 1)),
      );

      if (loan.isOverdue(now) || loan.isUpcoming(now)) {
        final isOverdue = loan.isOverdue(now);
        await ref.read(notificationsProvider.notifier).addIfNotExists(
          AppNotification(
            id: 'loan:${loan.id}:${dueDate.toIso8601String()}',
            title: loan.loanName,
            message: isOverdue
                ? 'EMI overdue — $amountText was due ${_formatDate(dueDate)}'
                : 'EMI due ${_formatDate(dueDate)} — $amountText',
            type: NotificationType.loanPayment.name,
            createdAt: now,
            relatedRoute: AppRoutes.loans,
          ),
        );
      }
    }
  }

  Future<void> _cancelReminders(String loanId) async {
    await NotificationService.instance.cancelReminder('$loanId-before');
    await NotificationService.instance.cancelReminder('$loanId-due');
    await NotificationService.instance.cancelReminder('$loanId-after');
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

/// Maps a display account name to the wallet id used for balance updates,
/// mirroring the mapping used by bills and recurring transactions.
String resolveLoanWalletId(String? account) {
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
