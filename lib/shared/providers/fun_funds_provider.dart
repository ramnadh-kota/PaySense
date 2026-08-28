import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fun_funds_expense.dart';
import '../models/fun_funds_group.dart';
import '../models/fun_funds_settlement.dart';
import '../repositories/fun_funds_expense_repository.dart';
import '../repositories/fun_funds_group_repository.dart';
import '../repositories/fun_funds_settlement_repository.dart';
import '../utils/fun_funds_calculator.dart';
import 'budget_provider.dart';
import 'financial_planning_provider.dart';
import 'safe_to_spend_provider.dart';

final funFundsGroupRepositoryProvider = Provider<FunFundsGroupRepository>((ref) {
  return FunFundsGroupRepository.instance;
});
final funFundsExpenseRepositoryProvider = Provider<FunFundsExpenseRepository>((ref) {
  return FunFundsExpenseRepository.instance;
});
final funFundsSettlementRepositoryProvider = Provider<FunFundsSettlementRepository>((ref) {
  return FunFundsSettlementRepository.instance;
});

final funFundsGroupsProvider = AsyncNotifierProvider<FunFundsGroupsNotifier, List<FunFundsGroup>>(
  FunFundsGroupsNotifier.new,
);

final funFundsExpensesProvider = AsyncNotifierProvider<FunFundsExpensesNotifier, List<FunFundsExpense>>(
  FunFundsExpensesNotifier.new,
);

final funFundsSettlementsProvider = AsyncNotifierProvider<FunFundsSettlementsNotifier, List<FunFundsSettlement>>(
  FunFundsSettlementsNotifier.new,
);

/// Currently-viewed group on the Fun Funds screens — local UI navigation
/// state, mirroring `subscriptionCategoryFilterProvider`'s established
/// pattern rather than introducing a `.family` provider (not used
/// anywhere else in this app).
final selectedFunFundsGroupIdProvider = StateProvider<String?>((ref) => null);

/// [FunFundsResult] for the signed-in user's whole financial picture — see
/// FunFundsCalculator's doc comment for why this is a thin adapter, not a
/// new formula. Reuses the SAME providers the Dashboard's Safe-to-Spend
/// card, Budget screen, and Financial Planning screen already watch.
final funFundsResultProvider = Provider<FunFundsResult>((ref) {
  final safeToSpend = ref.watch(safeToSpendProvider);
  final budgetTotals = ref.watch(budgetTotalsProvider);
  final planning = ref.watch(financialPlanningProvider);
  return FunFundsCalculator.calculate(
    safeToSpend: safeToSpend,
    budgetTotals: budgetTotals,
    goalProjections: planning.goalProjections,
  );
});

class FunFundsGroupsNotifier extends AsyncNotifier<List<FunFundsGroup>> {
  @override
  Future<List<FunFundsGroup>> build() async {
    final repository = ref.watch(funFundsGroupRepositoryProvider);
    return repository.getAll();
  }

  Future<void> addGroup(FunFundsGroup group) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<FunFundsGroup>>(() async {
      final repository = ref.read(funFundsGroupRepositoryProvider);
      await repository.upsert(group);
      return repository.getAll();
    });
  }

  Future<void> updateGroup(FunFundsGroup group) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<FunFundsGroup>>(() async {
      final repository = ref.read(funFundsGroupRepositoryProvider);
      await repository.upsert(group);
      return repository.getAll();
    });
  }

  /// Deletes the group AND every expense/settlement that belongs to it —
  /// no orphaned Fun Funds data left behind.
  Future<void> deleteGroup(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<FunFundsGroup>>(() async {
      final repository = ref.read(funFundsGroupRepositoryProvider);
      await ref.read(funFundsExpenseRepositoryProvider).deleteForGroup(id);
      await ref.read(funFundsSettlementRepositoryProvider).deleteForGroup(id);
      await repository.delete(id);
      return repository.getAll();
    });
    ref.invalidate(funFundsExpensesProvider);
    ref.invalidate(funFundsSettlementsProvider);
  }
}

class FunFundsExpensesNotifier extends AsyncNotifier<List<FunFundsExpense>> {
  @override
  Future<List<FunFundsExpense>> build() async {
    final repository = ref.watch(funFundsExpenseRepositoryProvider);
    return repository.getAll();
  }

  Future<void> addExpense(FunFundsExpense expense) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<FunFundsExpense>>(() async {
      final repository = ref.read(funFundsExpenseRepositoryProvider);
      await repository.upsert(expense);
      return repository.getAll();
    });
  }

  Future<void> deleteExpense(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<FunFundsExpense>>(() async {
      final repository = ref.read(funFundsExpenseRepositoryProvider);
      await repository.delete(id);
      return repository.getAll();
    });
  }
}

class FunFundsSettlementsNotifier extends AsyncNotifier<List<FunFundsSettlement>> {
  @override
  Future<List<FunFundsSettlement>> build() async {
    final repository = ref.watch(funFundsSettlementRepositoryProvider);
    return repository.getAll();
  }

  Future<void> markSettled({
    required String groupId,
    required String expenseId,
    required String debtorName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<FunFundsSettlement>>(() async {
      final repository = ref.read(funFundsSettlementRepositoryProvider);
      await repository.markSettled(
        groupId: groupId,
        expenseId: expenseId,
        debtorName: debtorName,
        settledAt: DateTime.now(),
      );
      return repository.getAll();
    });
  }

  Future<void> markPending({required String expenseId, required String debtorName}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<FunFundsSettlement>>(() async {
      final repository = ref.read(funFundsSettlementRepositoryProvider);
      await repository.markPending(expenseId: expenseId, debtorName: debtorName);
      return repository.getAll();
    });
  }
}
