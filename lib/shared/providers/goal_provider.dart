import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository.instance;
});

final goalsProvider = AsyncNotifierProvider<GoalsNotifier, List<Goal>>(
  GoalsNotifier.new,
);

final goalTotalsProvider = Provider<GoalTotals>((ref) {
  final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
  final totalGoals = goals.length;
  final totalTarget = goals.fold<double>(
    0,
    (sum, goal) => sum + goal.targetAmount,
  );
  final totalSaved = goals.fold<double>(
    0,
    (sum, goal) => sum + goal.currentAmount,
  );
  final totalRemaining = goals.fold<double>(
    0,
    (sum, goal) => sum + goal.remainingAmount,
  );

  final incompleteGoals = goals.where((goal) => !goal.isCompleted).toList()
    ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
  final closestGoal = incompleteGoals.isEmpty ? '' : incompleteGoals.first.title;

  return GoalTotals(
    totalGoals: totalGoals,
    totalTarget: totalTarget,
    totalSaved: totalSaved,
    totalRemaining: totalRemaining,
    closestGoal: closestGoal,
  );
});

class GoalsNotifier extends AsyncNotifier<List<Goal>> {
  @override
  Future<List<Goal>> build() async {
    final repository = ref.watch(goalRepositoryProvider);
    return repository.getAll();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Goal>>(() async {
      final repository = ref.read(goalRepositoryProvider);
      return repository.getAll();
    });
  }

  Future<void> addGoal(Goal goal) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Goal>>(() async {
      final repository = ref.read(goalRepositoryProvider);
      await repository.add(goal);
      return repository.getAll();
    });
  }

  Future<void> updateGoal(Goal goal) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<List<Goal>>(() async {
      final repository = ref.read(goalRepositoryProvider);
      await repository.update(goal);
      return repository.getAll();
    });
  }

  Future<bool> deleteGoal(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard<bool>(() async {
      final repository = ref.read(goalRepositoryProvider);
      final success = await repository.delete(id);
      state = await AsyncValue.guard(() => repository.getAll());
      return success;
    });
    return result.value ?? false;
  }
}

class GoalTotals {
  GoalTotals({
    required this.totalGoals,
    required this.totalTarget,
    required this.totalSaved,
    required this.totalRemaining,
    required this.closestGoal,
  });

  final int totalGoals;
  final double totalTarget;
  final double totalSaved;
  final double totalRemaining;
  final String closestGoal;
}
