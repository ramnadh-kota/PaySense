import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/providers/notification_provider.dart';
import 'package:paysense/shared/repositories/budget_repository.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/utils/budget_calculator.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository.instance;
});

final budgetsProvider = AsyncNotifierProvider<BudgetsNotifier, List<Budget>>(
  BudgetsNotifier.new,
);

final budgetTotalsProvider = Provider<BudgetTotals>((ref) {
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
  final totalBudget = budgets.fold<double>(
    0,
    (sum, budget) => sum + budget.allocatedAmount,
  );
  final totalSpent = budgets.fold<double>(
    0,
    (sum, budget) => sum + budget.spentAmount,
  );
  final remainingBudget = budgets.fold<double>(
    0,
    (sum, budget) => sum + budget.remainingAmount,
  );
  final percentageUsed = totalBudget > 0
      ? (totalSpent / totalBudget * 100)
      : 0.0;
  final highestSpendingCategory = budgets.isEmpty
      ? ''
      : budgets
            .reduce((a, b) => a.spentAmount >= b.spentAmount ? a : b)
            .categoryName;

  return BudgetTotals(
    totalBudget: totalBudget,
    totalSpent: totalSpent,
    remainingBudget: remainingBudget,
    percentageUsed: percentageUsed,
    highestSpendingCategory: highestSpendingCategory,
  );
});

class BudgetsNotifier extends AsyncNotifier<List<Budget>> {
  @override
  Future<List<Budget>> build() async {
    final repository = ref.watch(budgetRepositoryProvider);
    final transactions = await ref.watch(transactionsProvider.future);

    await repository.refreshBudgets(transactions);
    final budgets = await repository.getAll();
    await _notifyThresholds(budgets);
    return budgets;
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Budget>>(() async {
      final repository = ref.read(budgetRepositoryProvider);
      final transactions = await ref.read(transactionsProvider.future);
      await repository.refreshBudgets(transactions);
      final budgets = await repository.getAll();
      await _notifyThresholds(budgets);
      return budgets;
    });
  }

  Future<void> addBudget(Budget budget) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Budget>>(() async {
      final repository = ref.read(budgetRepositoryProvider);
      await repository.add(budget);
      final transactions = await ref.read(transactionsProvider.future);
      await repository.refreshBudgets(transactions);
      final budgets = await repository.getAll();
      await _notifyThresholds(budgets);
      return budgets;
    });
  }

  Future<void> updateBudget(Budget budget) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Budget>>(() async {
      final repository = ref.read(budgetRepositoryProvider);
      await repository.update(budget);
      final transactions = await ref.read(transactionsProvider.future);
      await repository.refreshBudgets(transactions);
      final budgets = await repository.getAll();
      await _notifyThresholds(budgets);
      return budgets;
    });
  }

  Future<bool> deleteBudget(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard<bool>(() async {
      final repository = ref.read(budgetRepositoryProvider);
      final success = await repository.delete(id);
      final transactions = await ref.read(transactionsProvider.future);
      await repository.refreshBudgets(transactions);
      state = await AsyncValue.guard(() => repository.getAll());
      return success;
    });
    return result.value ?? false;
  }

  /// Notifies once per budget per threshold crossing — id-keyed on
  /// (budget, threshold, month/year) through the existing
  /// `NotificationRepository.addIfNotExists` idempotency mechanism, so
  /// re-running this on every rebuild/refresh (`build`/`reload`/
  /// `addBudget`/`updateBudget` all call it) never creates a duplicate.
  /// Near-limit (80-100%) and over-budget (>100%) are reported as the two
  /// distinct events; "reaches exactly 100%" is the top of the near-limit
  /// band under [BudgetCalculator]'s own thresholds, so it doesn't need a
  /// third, separate notification to stay meaningful.
  Future<void> _notifyThresholds(List<Budget> budgets) async {
    final notifier = ref.read(notificationsProvider.notifier);
    for (final budget in budgets) {
      final status = BudgetCalculator.statusForBudget(budget);
      final period = '${budget.year}-${budget.month}';

      switch (status) {
        case BudgetStatus.nearLimit:
          await notifier.addIfNotExists(
            AppNotification(
              id: 'budget:${budget.id}:near-limit:$period',
              title: 'Approaching budget limit',
              message:
                  'You\'ve used ${budget.percentageUsed.toStringAsFixed(0)}% '
                  'of your ${budget.categoryName} budget (${budget.month}).',
              type: NotificationType.budget.name,
              createdAt: DateTime.now(),
              relatedRoute: AppRoutes.budget,
            ),
          );
        case BudgetStatus.overBudget:
          final overspend = budget.spentAmount - budget.allocatedAmount;
          await notifier.addIfNotExists(
            AppNotification(
              id: 'budget:${budget.id}:over-budget:$period',
              title: 'Over budget',
              message:
                  'You\'re ₹${overspend.toStringAsFixed(0)} over your '
                  '${budget.categoryName} budget (${budget.month}).',
              type: NotificationType.budget.name,
              createdAt: DateTime.now(),
              relatedRoute: AppRoutes.budget,
            ),
          );
        case BudgetStatus.underBudget:
          break;
      }
    }
  }
}

class BudgetTotals {
  BudgetTotals({
    required this.totalBudget,
    required this.totalSpent,
    required this.remainingBudget,
    required this.percentageUsed,
    required this.highestSpendingCategory,
  });

  final double totalBudget;
  final double totalSpent;
  final double remainingBudget;
  final double percentageUsed;
  final String highestSpendingCategory;
}
