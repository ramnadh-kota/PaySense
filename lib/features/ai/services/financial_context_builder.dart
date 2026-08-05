import 'package:paysense/features/ai/models/financial_context.dart';
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

    return FinancialContext(
      fullName: profile?.fullName ?? '',
      monthlyIncome: profile?.monthlyIncome ?? 0.0,
      monthlyEmi: profile?.monthlyEmi ?? 0.0,
      savingsGoal: profile?.savingsGoal ?? 0.0,
      totalWalletBalance: totalWalletBalance,
      monthlyIncomeTotal: monthlyIncomeTotal,
      monthlyExpenseTotal: monthlyExpenseTotal,
      recentTransactionsSummary: recentTransactionsSummary,
    );
  }
}
