import 'package:hive/hive.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/transaction.dart';

class BudgetRepository {
  BudgetRepository._();

  static final BudgetRepository instance = BudgetRepository._();

  static const String _boxName = 'budgets';

  Box<Budget> get _box => Hive.box<Budget>(_boxName);

  Future<List<Budget>> getAll() async {
    return List<Budget>.unmodifiable(_box.values.toList());
  }

  Future<Budget?> getById(String id) async {
    return _box.get(id);
  }

  Future<void> add(Budget budget) async {
    await _box.put(budget.id, budget);
  }

  Future<void> update(Budget budget) async {
    if (_box.containsKey(budget.id)) {
      await _box.put(budget.id, budget);
    }
  }

  Future<bool> delete(String id) async {
    if (!_box.containsKey(id)) {
      return false;
    }

    await _box.delete(id);
    return true;
  }

  Future<void> refreshBudgets(List<Transaction> transactions) async {
    final values = _box.values.toList();
    for (final budget in values) {
      final spentAmount = transactions
          .where(
            (transaction) =>
                transaction.transactionType.toLowerCase() == 'expense' &&
                transaction.categoryId == budget.categoryId &&
                transaction.createdAt.year == budget.year &&
                transaction.createdAt.month == _monthNameToNumber(budget.month),
          )
          .fold<double>(0, (sum, tx) => sum + tx.amount);

      final updated = budget.updateMetrics(spentAmount: spentAmount);
      await _box.put(updated.id, updated);
    }
  }

  int _monthNameToNumber(String monthName) {
    switch (monthName.toLowerCase()) {
      case 'january':
        return 1;
      case 'february':
        return 2;
      case 'march':
        return 3;
      case 'april':
        return 4;
      case 'may':
        return 5;
      case 'june':
        return 6;
      case 'july':
        return 7;
      case 'august':
        return 8;
      case 'september':
        return 9;
      case 'october':
        return 10;
      case 'november':
        return 11;
      case 'december':
        return 12;
      default:
        return 0;
    }
  }
}
