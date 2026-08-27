import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/shared/models/fun_group_expense.dart';
import 'package:paysense/shared/repositories/fun_group_expense_repository.dart';

final funGroupExpenseRepositoryProvider = Provider<FunGroupExpenseRepository>((
  ref,
) {
  return FunGroupExpenseRepository.instance;
});

final funGroupExpensesProvider =
    AsyncNotifierProvider<FunGroupExpensesNotifier, List<FunGroupExpense>>(
      FunGroupExpensesNotifier.new,
    );

class FunGroupExpensesNotifier extends AsyncNotifier<List<FunGroupExpense>> {
  @override
  Future<List<FunGroupExpense>> build() async {
    final repository = ref.watch(funGroupExpenseRepositoryProvider);
    return repository.getAll();
  }

  Future<void> addExpense(FunGroupExpense expense) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<FunGroupExpense>>(() async {
      final repository = ref.read(funGroupExpenseRepositoryProvider);
      await repository.add(expense);
      return repository.getAll();
    });
  }

  Future<void> updateExpense(FunGroupExpense expense) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<FunGroupExpense>>(() async {
      final repository = ref.read(funGroupExpenseRepositoryProvider);
      await repository.update(expense);
      return repository.getAll();
    });
  }

  /// Toggles [participantId]'s settlement status on [expenseId].
  Future<void> toggleSettled(String expenseId, String participantId) async {
    final repository = ref.read(funGroupExpenseRepositoryProvider);
    final expense = await repository.getById(expenseId);
    if (expense == null) {
      return;
    }
    final updatedParticipants = expense.participants.map((p) {
      if (p.id != participantId) return p;
      return p.copyWith(isSettled: !p.isSettled);
    }).toList();
    await updateExpense(expense.copyWith(participants: updatedParticipants));
  }

  Future<bool> deleteExpense(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard<bool>(() async {
      final repository = ref.read(funGroupExpenseRepositoryProvider);
      final success = await repository.delete(id);
      state = await AsyncValue.guard(() => repository.getAll());
      return success;
    });
    return result.value ?? false;
  }
}
