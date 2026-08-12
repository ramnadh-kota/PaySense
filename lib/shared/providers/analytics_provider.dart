import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/shared/models/loan.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/loan_provider.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';

/// Income and expense totals for a single calendar month.
class MonthlyTotal {
  MonthlyTotal({
    required this.month,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final double income;
  final double expense;
}

/// Total expense for a single category, with its share of overall spend.
class CategoryBreakdown {
  CategoryBreakdown({
    required this.categoryId,
    required this.amount,
    required this.percentage,
  });

  final String categoryId;
  final double amount;
  final double percentage;
}

class AnalyticsSummary {
  AnalyticsSummary({
    required this.monthlyTotals,
    required this.categoryBreakdown,
    required this.currentMonthIncome,
    required this.currentMonthExpense,
    required this.savingsRate,
  });

  /// Oldest to newest, up to the last 6 calendar months (including this one).
  final List<MonthlyTotal> monthlyTotals;

  /// Expense-only, current calendar month, sorted by amount descending.
  final List<CategoryBreakdown> categoryBreakdown;

  final double currentMonthIncome;
  final double currentMonthExpense;

  /// (income - expense) / income * 100 for the current month, 0 when there's
  /// no income to divide by.
  final double savingsRate;
}

/// Number of trailing months (including the current one) shown in the trend
/// chart.
const int analyticsTrendMonths = 6;

final analyticsSummaryProvider = Provider<AnalyticsSummary>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  return buildAnalyticsSummary(transactions, DateTime.now());
});

/// Pure computation kept separate from the provider so it can be unit
/// tested without needing a [ProviderContainer] or Hive.
AnalyticsSummary buildAnalyticsSummary(
  List<Transaction> transactions,
  DateTime now,
) {
  final currentMonthStart = DateTime(now.year, now.month, 1);
  final trendStart = DateTime(
    currentMonthStart.year,
    currentMonthStart.month - (analyticsTrendMonths - 1),
    1,
  );

  final monthlyTotals = <MonthlyTotal>[];
  for (var i = 0; i < analyticsTrendMonths; i++) {
    final monthDate = DateTime(trendStart.year, trendStart.month + i, 1);
    double income = 0;
    double expense = 0;
    for (final transaction in transactions) {
      if (transaction.createdAt.year == monthDate.year &&
          transaction.createdAt.month == monthDate.month) {
        final type = transaction.transactionType.toLowerCase();
        if (type == 'income') {
          income += transaction.amount;
        } else if (type == 'expense') {
          expense += transaction.amount;
        }
      }
    }
    monthlyTotals.add(
      MonthlyTotal(month: monthDate, income: income, expense: expense),
    );
  }

  final currentMonth = monthlyTotals.last;
  final savingsRate = currentMonth.income > 0
      ? ((currentMonth.income - currentMonth.expense) / currentMonth.income * 100)
      : 0.0;

  final categoryTotals = <String, double>{};
  for (final transaction in transactions) {
    if (transaction.transactionType.toLowerCase() != 'expense') {
      continue;
    }
    if (transaction.createdAt.year != now.year ||
        transaction.createdAt.month != now.month) {
      continue;
    }
    categoryTotals.update(
      transaction.categoryId,
      (value) => value + transaction.amount,
      ifAbsent: () => transaction.amount,
    );
  }

  final totalExpense = categoryTotals.values.fold<double>(0, (a, b) => a + b);
  final categoryBreakdown = categoryTotals.entries
      .map(
        (entry) => CategoryBreakdown(
          categoryId: entry.key,
          amount: entry.value,
          percentage: totalExpense > 0 ? (entry.value / totalExpense * 100) : 0,
        ),
      )
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  return AnalyticsSummary(
    monthlyTotals: monthlyTotals,
    categoryBreakdown: categoryBreakdown,
    currentMonthIncome: currentMonth.income,
    currentMonthExpense: currentMonth.expense,
    savingsRate: savingsRate,
  );
}

/// Total outstanding loan balance for a single trailing month.
class MonthlyOutstanding {
  MonthlyOutstanding({required this.month, required this.outstanding});

  final DateTime month;
  final double outstanding;
}

class LoanAnalytics {
  LoanAnalytics({
    required this.loanToAssetRatio,
    required this.totalInterestPaidEstimate,
    required this.monthlyEmiBurden,
    required this.monthlyEmiBurdenPercentage,
    required this.outstandingTrend,
  });

  /// Outstanding loan balance as a percentage of total wallet balance, 0
  /// when there are no assets to divide by.
  final double loanToAssetRatio;

  /// Proportional estimate of interest paid so far across all loans (no
  /// full amortization ledger is kept, so this scales with principal
  /// repaid).
  final double totalInterestPaidEstimate;

  final double monthlyEmiBurden;

  /// Monthly EMI burden as a percentage of the current month's income, 0
  /// when there's no income to divide by.
  final double monthlyEmiBurdenPercentage;

  /// Oldest to newest, up to the last 6 calendar months (including this
  /// one). A synthetic reconstruction from each loan's schedule, since we
  /// don't keep a historical balance ledger.
  final List<MonthlyOutstanding> outstandingTrend;
}

final loanAnalyticsProvider = Provider<LoanAnalytics>((ref) {
  final loans = ref.watch(loansProvider).value ?? const <Loan>[];
  final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
  final currentMonthIncome = ref.watch(analyticsSummaryProvider).currentMonthIncome;
  return buildLoanAnalytics(loans, wallets, currentMonthIncome, DateTime.now());
});

/// Pure computation kept separate from the provider so it can be unit
/// tested without needing a [ProviderContainer] or Hive.
LoanAnalytics buildLoanAnalytics(
  List<Loan> loans,
  List<Wallet> wallets,
  double currentMonthIncome,
  DateTime now,
) {
  final totalAssets = wallets.fold<double>(
    0,
    (sum, wallet) => sum + wallet.currentBalance,
  );
  final activeLoans = loans.where((loan) => loan.isActive).toList();
  final outstandingBalance = activeLoans.fold<double>(
    0,
    (sum, loan) => sum + loan.outstandingAmount,
  );
  final loanToAssetRatio = totalAssets > 0
      ? (outstandingBalance / totalAssets * 100)
      : 0.0;

  final totalInterestPaidEstimate = loans.fold<double>(
    0,
    (sum, loan) => sum + loan.estimatedInterestPaid,
  );

  final monthlyEmiBurden = activeLoans.fold<double>(
    0,
    (sum, loan) => sum + loan.emiAmount,
  );
  final monthlyEmiBurdenPercentage = currentMonthIncome > 0
      ? (monthlyEmiBurden / currentMonthIncome * 100)
      : 0.0;

  final currentMonthStart = DateTime(now.year, now.month, 1);
  final trendStart = DateTime(
    currentMonthStart.year,
    currentMonthStart.month - (analyticsTrendMonths - 1),
    1,
  );

  final outstandingTrend = <MonthlyOutstanding>[];
  for (var i = 0; i < analyticsTrendMonths; i++) {
    final monthDate = DateTime(trendStart.year, trendStart.month + i, 1);
    double outstandingAtMonth = 0;
    for (final loan in loans) {
      final loanStartMonth = DateTime(
        loan.startDate.year,
        loan.startDate.month,
        1,
      );
      if (monthDate.isBefore(loanStartMonth)) {
        continue;
      }
      final monthsElapsed =
          (monthDate.year - loanStartMonth.year) * 12 +
          (monthDate.month - loanStartMonth.month) +
          1;
      final estimatedPaidByMonth = monthsElapsed * loan.emiAmount;
      outstandingAtMonth += (loan.principalAmount - estimatedPaidByMonth)
          .clamp(0.0, loan.principalAmount);
    }
    outstandingTrend.add(
      MonthlyOutstanding(month: monthDate, outstanding: outstandingAtMonth),
    );
  }

  return LoanAnalytics(
    loanToAssetRatio: loanToAssetRatio,
    totalInterestPaidEstimate: totalInterestPaidEstimate,
    monthlyEmiBurden: monthlyEmiBurden,
    monthlyEmiBurdenPercentage: monthlyEmiBurdenPercentage,
    outstandingTrend: outstandingTrend,
  );
}
