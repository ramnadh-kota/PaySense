import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/services/notification_service.dart';
import 'package:paysense/shared/models/app_settings.dart';
import 'package:paysense/shared/providers/bill_provider.dart';
import 'package:paysense/shared/providers/budget_provider.dart';
import 'package:paysense/shared/providers/goal_provider.dart';
import 'package:paysense/shared/providers/loan_provider.dart';
import 'package:paysense/shared/providers/recurring_transaction_provider.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/bill_repository.dart';
import 'package:paysense/shared/repositories/budget_repository.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';
import 'package:paysense/shared/repositories/loan_repository.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository.instance;
});

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    return ref.read(appSettingsRepositoryProvider).getSettings();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final repo = ref.read(appSettingsRepositoryProvider);
    await repo.setThemeMode(mode);
    state = AsyncValue.data((state.value ?? const AppSettings()).copyWith(
      themeMode: mode,
    ));
  }

  Future<void> setBillReminders(bool enabled) async {
    final repo = ref.read(appSettingsRepositoryProvider);
    await repo.setBillReminders(enabled);
    state = AsyncValue.data((state.value ?? const AppSettings()).copyWith(
      billReminders: enabled,
    ));
  }

  Future<void> setRecurringReminders(bool enabled) async {
    final repo = ref.read(appSettingsRepositoryProvider);
    await repo.setRecurringReminders(enabled);
    state = AsyncValue.data((state.value ?? const AppSettings()).copyWith(
      recurringReminders: enabled,
    ));
  }

  Future<void> setLoanReminders(bool enabled) async {
    final repo = ref.read(appSettingsRepositoryProvider);
    await repo.setLoanReminders(enabled);
    state = AsyncValue.data((state.value ?? const AppSettings()).copyWith(
      loanReminders: enabled,
    ));
  }

  /// Clears only financial records (transactions, wallets, budgets, goals,
  /// recurring transactions, bills, loans) and any scheduled reminders.
  /// Never touches the authenticated account, [UserProfile], or settings.
  Future<void> clearFinancialData() async {
    await _clearBox(
      TransactionRepository.instance.getAll,
      TransactionRepository.instance.delete,
    );
    await _clearBox(
      WalletRepository.instance.getAll,
      WalletRepository.instance.delete,
    );
    await _clearBox(
      BudgetRepository.instance.getAll,
      BudgetRepository.instance.delete,
    );
    await _clearBox(
      GoalRepository.instance.getAll,
      GoalRepository.instance.delete,
    );
    await _clearBox(
      RecurringTransactionRepository.instance.getAll,
      RecurringTransactionRepository.instance.delete,
    );
    await _clearBox(
      BillRepository.instance.getAll,
      BillRepository.instance.delete,
    );
    await _clearBox(
      LoanRepository.instance.getAll,
      LoanRepository.instance.delete,
    );

    await NotificationService.instance.cancelAll();

    ref.invalidate(transactionsProvider);
    ref.invalidate(walletsProvider);
    ref.invalidate(budgetsProvider);
    ref.invalidate(goalsProvider);
    ref.invalidate(recurringTransactionsProvider);
    ref.invalidate(billsProvider);
    ref.invalidate(loansProvider);
  }

  Future<void> _clearBox<T>(
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
