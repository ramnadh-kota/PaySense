import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/repositories/budget_repository.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';

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
    return repository.getAll();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Budget>>(() async {
      final repository = ref.read(budgetRepositoryProvider);
      final transactions = await ref.read(transactionsProvider.future);
      await repository.refreshBudgets(transactions);
      return repository.getAll();
    });
  }

  Future<void> addBudget(Budget budget) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Budget>>(() async {
      final repository = ref.read(budgetRepositoryProvider);
      await repository.add(budget);
      final transactions = await ref.read(transactionsProvider.future);
      await repository.refreshBudgets(transactions);
      return repository.getAll();
    });
  }

  Future<void> updateBudget(Budget budget) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Budget>>(() async {
      final repository = ref.read(budgetRepositoryProvider);
      await repository.update(budget);
      final transactions = await ref.read(transactionsProvider.future);
      await repository.refreshBudgets(transactions);
      return repository.getAll();
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
