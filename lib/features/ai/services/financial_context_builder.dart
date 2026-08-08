import 'package:paysense/features/ai/models/financial_context.dart';
import 'package:paysense/shared/repositories/bill_repository.dart';
import 'package:paysense/shared/repositories/budget_repository.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';
import 'package:paysense/shared/repositories/user_profile_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';

class FinancialContextBuilder {
  FinancialContextBuilder._();

  static final FinancialContextBuilder instance = FinancialContextBuilder._();

  Future<FinancialContext> build() async {
    final profile = await UserProfileRepository.instance.getProfile();
    final wallets = await WalletRepository.instance.getAll();
    final transactions = await TransactionRepository.instance.getAll();
    final budgets = await BudgetRepository.instance.getAll();
    final goals = await GoalRepository.instance.getAll();
    final recurringTransactions = await RecurringTransactionRepository
        .instance
        .getAll();
    final bills = await BillRepository.instance.getAll();

    final totalWalletBalance = wallets.fold<double>(
      0.0,
      (sum, w) => sum + w.currentBalance,
    );

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final monthlyTransactions = transactions.where(
      (t) =>
          !t.createdAt.isBefore(startOfMonth) &&
          t.createdAt.year == now.year &&
          t.createdAt.month == now.month,
    );

    final monthlyIncomeTotal = monthlyTransactions
        .where((t) => t.transactionType.toLowerCase() == 'income')
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    final monthlyExpenseTotal = monthlyTransactions
        .where((t) => t.transactionType.toLowerCase() == 'expense')
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    final recent = transactions.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final recentTransactionsSummary = recent
        .take(5)
        .map(
          (t) =>
              '${t.title}: ${t.amount.toStringAsFixed(2)} on ${t.createdAt.toIso8601String().split('T').first}',
        )
        .join('; ');

    final totalBudget = budgets.fold<double>(
      0.0,
      (sum, b) => sum + b.allocatedAmount,
    );
    final totalBudgetSpent = budgets.fold<double>(
      0.0,
      (sum, b) => sum + b.spentAmount,
    );
    final totalBudgetRemaining = budgets.fold<double>(
      0.0,
      (sum, b) => sum + b.remainingAmount,
    );
    final budgetUsagePercentage = totalBudget > 0
        ? (totalBudgetSpent / totalBudget * 100)
        : 0.0;
    final highestSpendingBudgetCategory = budgets.isEmpty
        ? ''
        : budgets
              .reduce((a, b) => a.spentAmount >= b.spentAmount ? a : b)
              .categoryName;

    final totalGoals = goals.length;
    final completedGoals = goals.where((g) => g.isCompleted).length;
    final totalTargetSavings = goals.fold<double>(
      0.0,
      (sum, g) => sum + g.targetAmount,
    );
    final totalCurrentSavings = goals.fold<double>(
      0.0,
      (sum, g) => sum + g.currentAmount,
    );
    final goalCompletionPercentage = totalTargetSavings > 0
        ? (totalCurrentSavings / totalTargetSavings * 100)
        : 0.0;
    final incompleteGoals = goals.where((g) => !g.isCompleted).toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    final nearestGoal = incompleteGoals.isEmpty
        ? ''
        : incompleteGoals.first.title;

    final activeRecurring =
        recurringTransactions
            .where((r) => r.isActive && !r.isExpired)
            .toList()
          ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    double monthlyRecurringIncome = 0;
    double monthlyRecurringExpense = 0;
    for (final recurring in activeRecurring) {
      final monthlyAmount = _monthlyEquivalent(
        recurring.amount,
        recurring.frequency,
      );
      if (recurring.transactionType.toLowerCase() == 'income') {
        monthlyRecurringIncome += monthlyAmount;
      } else {
        monthlyRecurringExpense += monthlyAmount;
      }
    }

    final nextUpcoming = activeRecurring.isEmpty
        ? null
        : activeRecurring.first;
    final nextUpcomingPayment = nextUpcoming?.title ?? '';
    final nextUpcomingPaymentDate = nextUpcoming == null
        ? ''
        : '${nextUpcoming.nextDueDate.day}/${nextUpcoming.nextDueDate.month}/${nextUpcoming.nextDueDate.year}';

    final unpaidBillsList = bills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final overdueBillsCount = unpaidBillsList
        .where((b) => b.isOverdue(now))
        .length;
    final totalUnpaidBillsAmount = unpaidBillsList.fold<double>(
      0.0,
      (sum, b) => sum + b.amount,
    );
    final nextBill = unpaidBillsList.isEmpty ? null : unpaidBillsList.first;
    final nextBillTitle = nextBill?.title ?? '';
    final nextBillDueDate = nextBill == null
        ? ''
        : '${nextBill.dueDate.day}/${nextBill.dueDate.month}/${nextBill.dueDate.year}';

    return FinancialContext(
      fullName: profile?.fullName ?? '',
      monthlyIncome: profile?.monthlyIncome ?? 0.0,
      monthlyEmi: profile?.monthlyEmi ?? 0.0,
      savingsGoal: profile?.savingsGoal ?? 0.0,
      totalWalletBalance: totalWalletBalance,
      monthlyIncomeTotal: monthlyIncomeTotal,
      monthlyExpenseTotal: monthlyExpenseTotal,
      totalBudget: totalBudget,
      totalBudgetSpent: totalBudgetSpent,
      totalBudgetRemaining: totalBudgetRemaining,
      budgetUsagePercentage: budgetUsagePercentage,
      highestSpendingBudgetCategory: highestSpendingBudgetCategory,
      recentTransactionsSummary: recentTransactionsSummary,
      totalGoals: totalGoals,
      completedGoals: completedGoals,
      totalTargetSavings: totalTargetSavings,
      totalCurrentSavings: totalCurrentSavings,
      nearestGoal: nearestGoal,
      goalCompletionPercentage: goalCompletionPercentage,
      totalRecurringTransactions: recurringTransactions.length,
      activeRecurringTransactions: activeRecurring.length,
      monthlyRecurringIncome: monthlyRecurringIncome,
      monthlyRecurringExpense: monthlyRecurringExpense,
      nextUpcomingPayment: nextUpcomingPayment,
      nextUpcomingPaymentDate: nextUpcomingPaymentDate,
      totalBills: bills.length,
      unpaidBills: unpaidBillsList.length,
      overdueBills: overdueBillsCount,
      totalUnpaidBillsAmount: totalUnpaidBillsAmount,
      nextBillTitle: nextBillTitle,
      nextBillDueDate: nextBillDueDate,
    );
  }

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
}
