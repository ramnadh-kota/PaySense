import '../models/bill.dart';
import '../models/financial_safety_alert.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';

/// FINANCIAL SAFETY ENGINE — deterministic, rule-based detection over
/// EXISTING transaction/wallet/bill/loan/recurring data. No AI-generated
/// figures anywhere in this file; every number is a direct sum/average
/// of real records.
///
/// Deliberately does NOT duplicate `FinancialActionEngine`/
/// `FinancialInsightEngine` — those already cover overspending/budget/
/// savings-decline/debt-burden/subscription-cost/goal-risk and
/// unusual-category-spending/upcoming-commitment-pressure/subscription-
/// increase. This engine adds only the checks NOT already covered by
/// either: spending spike (month-over-month, not budget-relative), low
/// balance / pre-payday shortage, EMI-specific pressure, salary
/// irregularity, a single unusually large transaction, a same-week
/// cluster of large transactions, and cash-flow deficit.
///
/// WORDING: every alert uses "PaySense insight" framing — an observation,
/// never a directive ("you should..."), and never a claim of financial
/// advice.
///
/// KNOWN LIMITATION: "credit card utilization risk" (Phase G item 7) is
/// NOT implemented — no PaySense model (`Wallet`, `Loan`,
/// `AccountAggregatorAccount`) has a credit LIMIT field, only an
/// outstanding balance. Utilization (%) cannot be computed without a
/// limit, and inventing one would be exactly the kind of fabricated
/// figure this engine must never produce. Documented, not guessed at.
class FinancialSafetyEngine {
  FinancialSafetyEngine._();

  static const double spendingSpikeThresholdPercent = 30;
  static const double spendingSpikeHighThresholdPercent = 60;
  static const int lowBalanceRiskHorizonDays = 7;
  static const double largeTransactionMultiplier = 3.0;
  static const int clusterWindowDays = 3;
  static const int clusterMinCount = 3;
  static const double clusterMinIndividualAmount = 5000;

  static List<FinancialSafetyAlert> generate({
    required List<Transaction> transactions,
    required List<Wallet> wallets,
    required List<Bill> bills,
    required List<Loan> loans,
    required List<RecurringTransaction> recurringTransactions,
    required DateTime now,
  }) {
    final alerts = <FinancialSafetyAlert>[];

    final totalBalance = wallets.fold<double>(0, (sum, w) => sum + w.currentBalance);
    final expenseTx = transactions.where((t) => t.transactionType == 'expense').toList();
    final incomeTx = transactions.where((t) => t.transactionType == 'income').toList();

    final currentMonthStart = DateTime(now.year, now.month, 1);

    double expenseForMonth(DateTime monthStart) {
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
      return expenseTx
          .where((t) => !t.createdAt.isBefore(monthStart) && t.createdAt.isBefore(monthEnd))
          .fold(0.0, (sum, t) => sum + t.amount);
    }

    // 1. Spending spike — this month vs the average of the last 3 months
    // that actually had spending (never divides by a month with no data).
    final thisMonthExpense = expenseForMonth(currentMonthStart);
    final priorMonthExpenses = [1, 2, 3]
        .map((i) => expenseForMonth(DateTime(currentMonthStart.year, currentMonthStart.month - i, 1)))
        .where((amount) => amount > 0)
        .toList();
    if (priorMonthExpenses.isNotEmpty && thisMonthExpense > 0) {
      final averagePrior = priorMonthExpenses.reduce((a, b) => a + b) / priorMonthExpenses.length;
      if (averagePrior > 0) {
        final increasePercent = ((thisMonthExpense - averagePrior) / averagePrior) * 100;
        if (increasePercent >= spendingSpikeThresholdPercent) {
          alerts.add(FinancialSafetyAlert(
            type: FinancialSafetyAlertType.spendingSpike,
            severity: increasePercent >= spendingSpikeHighThresholdPercent
                ? FinancialSafetyAlertSeverity.high
                : FinancialSafetyAlertSeverity.attention,
            title: 'PaySense insight: spending is higher than usual',
            explanation:
                'Your spending this month is ${increasePercent.round()}% higher than your usual monthly pattern.',
            recommendedAction: 'Review this month\'s transactions to see what changed.',
            amount: thisMonthExpense,
            createdAt: now,
          ));
        }
      }
    }

    // 2. Low balance / pre-payday shortage — known upcoming bills + EMIs
    // due within the horizon, compared against current cash on hand.
    final horizon = now.add(const Duration(days: lowBalanceRiskHorizonDays));
    final upcomingBillsTotal = bills
        .where((b) => !b.isPaid && !b.dueDate.isBefore(now) && b.dueDate.isBefore(horizon))
        .fold(0.0, (sum, b) => sum + b.amount);
    final upcomingEmis = loans.where((l) => l.isActive && !l.nextDueDate.isBefore(now) && l.nextDueDate.isBefore(horizon)).toList();
    final upcomingEmiTotal = upcomingEmis.fold(0.0, (sum, l) => sum + l.emiAmount);
    final upcomingOutflow = upcomingBillsTotal + upcomingEmiTotal;

    if (upcomingOutflow > 0 && totalBalance < upcomingOutflow) {
      alerts.add(FinancialSafetyAlert(
        type: FinancialSafetyAlertType.lowBalanceRisk,
        severity: FinancialSafetyAlertSeverity.high,
        title: 'PaySense insight: your balance may fall short',
        explanation: 'Your available balance may fall below what\'s needed for ₹${upcomingOutflow.toStringAsFixed(0)} '
            'in bills and EMIs due in the next $lowBalanceRiskHorizonDays days.',
        recommendedAction: 'Review upcoming bills and EMIs before they\'re due.',
        amount: upcomingOutflow,
        createdAt: now,
      ));
    }

    // 3. Upcoming EMI pressure — called out specifically (distinct from
    // the general low-balance check above), since an EMI miss has
    // consequences a regular bill doesn't.
    if (upcomingEmis.isNotEmpty) {
      alerts.add(FinancialSafetyAlert(
        type: FinancialSafetyAlertType.upcomingEmiPressure,
        severity: FinancialSafetyAlertSeverity.attention,
        title: 'PaySense insight: EMI payments due soon',
        explanation: '₹${upcomingEmiTotal.toStringAsFixed(0)} in EMI payments '
            '${upcomingEmis.length == 1 ? 'is' : 'are'} due in the next $lowBalanceRiskHorizonDays days.',
        recommendedAction: 'Make sure the linked account has enough balance on the due date.',
        amount: upcomingEmiTotal,
        date: upcomingEmis.map((l) => l.nextDueDate).reduce((a, b) => a.isBefore(b) ? a : b),
        createdAt: now,
      ));
    }

    // 4. Recurring payment pressure — total recurring monthly commitments
    // (subscriptions/bills/EMIs) relative to average monthly income.
    final activeRecurringExpense = recurringTransactions
        .where((r) => r.isActive && r.transactionType == 'expense' && !r.isExpired)
        .fold(0.0, (sum, r) => sum + _monthlyEquivalent(r.amount, r.frequency));
    final recurringBillsMonthly = bills.where((b) => b.isRecurring).fold(0.0, (sum, b) => sum + b.amount);
    final recurringLoanEmis = loans.where((l) => l.isActive).fold(0.0, (sum, l) => sum + l.emiAmount);
    final totalRecurringMonthly = activeRecurringExpense + recurringBillsMonthly + recurringLoanEmis;

    final recentIncomeMonths = [0, 1, 2]
        .map((i) => incomeTx
            .where((t) =>
                t.createdAt.year == DateTime(currentMonthStart.year, currentMonthStart.month - i, 1).year &&
                t.createdAt.month == DateTime(currentMonthStart.year, currentMonthStart.month - i, 1).month)
            .fold(0.0, (sum, t) => sum + t.amount))
        .where((amount) => amount > 0)
        .toList();
    final averageMonthlyIncome =
        recentIncomeMonths.isEmpty ? 0.0 : recentIncomeMonths.reduce((a, b) => a + b) / recentIncomeMonths.length;

    if (averageMonthlyIncome > 0 && totalRecurringMonthly > 0) {
      final percentOfIncome = (totalRecurringMonthly / averageMonthlyIncome) * 100;
      if (percentOfIncome >= 50) {
        alerts.add(FinancialSafetyAlert(
          type: FinancialSafetyAlertType.recurringPaymentPressure,
          severity: percentOfIncome >= 75 ? FinancialSafetyAlertSeverity.high : FinancialSafetyAlertSeverity.attention,
          title: 'PaySense insight: recurring commitments are a large share of income',
          explanation: '₹${totalRecurringMonthly.toStringAsFixed(0)} in recurring payments is about '
              '${percentOfIncome.round()}% of your average monthly income.',
          recommendedAction: 'Open Recurring Money to review what\'s contributing to this.',
          amount: totalRecurringMonthly,
          createdAt: now,
        ));
      }
    }

    // 5. Salary irregularity — a recognized recurring INCOME record exists,
    // but no matching transaction landed within a reasonable grace window
    // of its expected date this cycle.
    final recurringIncomes = recurringTransactions.where((r) => r.isActive && r.transactionType == 'income').toList();
    for (final recurringIncome in recurringIncomes) {
      final graceWindowStart = recurringIncome.nextDueDate.subtract(const Duration(days: 5));
      final graceWindowEnd = recurringIncome.nextDueDate.add(const Duration(days: 5));
      final matched = incomeTx.any((t) =>
          !t.createdAt.isBefore(graceWindowStart) &&
          !t.createdAt.isAfter(graceWindowEnd) &&
          (t.amount - recurringIncome.amount).abs() <= recurringIncome.amount * 0.1);
      if (!matched && recurringIncome.nextDueDate.isBefore(now)) {
        alerts.add(FinancialSafetyAlert(
          type: FinancialSafetyAlertType.salaryIrregularity,
          severity: FinancialSafetyAlertSeverity.attention,
          title: 'PaySense insight: expected income hasn\'t arrived as usual',
          explanation: '${recurringIncome.title} was expected around '
              '${recurringIncome.nextDueDate.day}/${recurringIncome.nextDueDate.month}, but no matching transaction was recorded.',
          recommendedAction: 'Check whether this payment is delayed or was recorded under a different entry.',
          amount: recurringIncome.amount,
          date: recurringIncome.nextDueDate,
          createdAt: now,
        ));
        break; // one salary-irregularity alert is enough signal at a time.
      }
    }

    // 6. Large unusual transaction — more than [largeTransactionMultiplier]
    // times the MEDIAN expense amount, using the last 90 days as the
    // baseline (never the transaction being evaluated skews its own
    // baseline more than marginally, since it's one of many).
    final recentExpenses = expenseTx.where((t) => now.difference(t.createdAt).inDays <= 90).toList();
    if (recentExpenses.length >= 5) {
      final sortedAmounts = recentExpenses.map((t) => t.amount).toList()..sort();
      final median = sortedAmounts[sortedAmounts.length ~/ 2];
      if (median > 0) {
        final large = recentExpenses.where((t) => t.amount >= median * largeTransactionMultiplier).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (large.isNotEmpty) {
          final biggest = large.first;
          alerts.add(FinancialSafetyAlert(
            type: FinancialSafetyAlertType.largeUnusualTransaction,
            severity: FinancialSafetyAlertSeverity.info,
            title: 'PaySense insight: an unusually large transaction',
            explanation: '"${biggest.title}" (₹${biggest.amount.toStringAsFixed(0)}) is notably larger than your typical transaction.',
            recommendedAction: 'Confirm this transaction is expected.',
            amount: biggest.amount,
            date: biggest.createdAt,
            createdAt: now,
          ));
        }
      }
    }

    // 7. Cash-flow deficit — this month's recorded expense already
    // exceeds this month's recorded income.
    final thisMonthIncome = incomeTx
        .where((t) => !t.createdAt.isBefore(currentMonthStart) && t.createdAt.isBefore(DateTime(currentMonthStart.year, currentMonthStart.month + 1, 1)))
        .fold(0.0, (sum, t) => sum + t.amount);
    if (thisMonthIncome > 0 && thisMonthExpense > thisMonthIncome) {
      alerts.add(FinancialSafetyAlert(
        type: FinancialSafetyAlertType.cashFlowDeficit,
        severity: FinancialSafetyAlertSeverity.high,
        title: 'PaySense insight: spending has outpaced income this month',
        explanation: 'You\'ve spent ₹${thisMonthExpense.toStringAsFixed(0)} against '
            '₹${thisMonthIncome.toStringAsFixed(0)} recorded income so far this month.',
        recommendedAction: 'Review this month\'s transactions to understand the gap.',
        amount: thisMonthExpense - thisMonthIncome,
        createdAt: now,
      ));
    }

    // 8. Multiple large transactions close together — a cluster of
    // [clusterMinCount]+ transactions each at least
    // [clusterMinIndividualAmount], all within a [clusterWindowDays] span.
    final sortedByDate = List<Transaction>.of(expenseTx)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (var i = 0; i < sortedByDate.length; i++) {
      if (sortedByDate[i].amount < clusterMinIndividualAmount) continue;
      final windowEnd = sortedByDate[i].createdAt.add(const Duration(days: clusterWindowDays));
      final cluster = sortedByDate
          .skip(i)
          .takeWhile((t) => !t.createdAt.isAfter(windowEnd))
          .where((t) => t.amount >= clusterMinIndividualAmount)
          .toList();
      if (cluster.length >= clusterMinCount) {
        final clusterTotal = cluster.fold(0.0, (sum, t) => sum + t.amount);
        alerts.add(FinancialSafetyAlert(
          type: FinancialSafetyAlertType.multipleLargeTransactionsCluster,
          severity: FinancialSafetyAlertSeverity.attention,
          title: 'PaySense insight: several large transactions close together',
          explanation: '${cluster.length} transactions totaling ₹${clusterTotal.toStringAsFixed(0)} '
              'happened within $clusterWindowDays days of each other.',
          recommendedAction: 'Review these transactions together to confirm they\'re all expected.',
          amount: clusterTotal,
          date: sortedByDate[i].createdAt,
          createdAt: now,
        ));
        break; // one cluster alert is enough signal at a time.
      }
    }

    return alerts;
  }

  static double _monthlyEquivalent(double amount, String frequency) {
    switch (frequency) {
      case 'Daily':
        return amount * 365 / 12;
      case 'Weekly':
        return amount * 52 / 12;
      case 'Monthly':
        return amount;
      case 'Yearly':
        return amount / 12;
      default:
        return amount;
    }
  }
}
