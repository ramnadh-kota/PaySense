import 'package:flutter/foundation.dart';

import '../models/bill.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/subscription_summary.dart';
import 'financial_action_engine.dart';
import 'subscription_calculator.dart';

/// FEATURE — RECURRING PAYMENT / SUBSCRIPTION INTELLIGENCE. Pure Dart,
/// deterministic, Flutter-independent. Deliberately does NOT introduce a
/// new subscription-detection formula: subscriptions come straight from
/// the EXISTING [SubscriptionCalculator] (which already turns active
/// expense [RecurringTransaction]s into [SubscriptionSummary]s), bills
/// come straight from the EXISTING [Bill] model, and EMIs come straight
/// from the EXISTING [Loan] model. This class only groups and sums
/// already-computed values for display — it never recalculates a
/// monthly/annual cost differently than [SubscriptionCalculator] does.
///
/// SCOPE NOTE: a fourth "Other recurring expenses" bucket was considered
/// but deliberately not built — there is no reliable existing signal to
/// separate "a subscription" from "some other recurring expense" beyond
/// what [SubscriptionCalculator] already treats uniformly (any active
/// recurring expense). Inventing a keyword-based classifier for this
/// would be exactly the kind of fabricated financial categorization this
/// feature is supposed to avoid — so everything from
/// [SubscriptionCalculator] is shown together under "Subscriptions",
/// honestly reflecting what the underlying data actually distinguishes.
@immutable
class RecurringMoneySummary {
  const RecurringMoneySummary({
    required this.subscriptions,
    required this.recurringBills,
    required this.emiLoans,
    required this.totalMonthlyCost,
    required this.totalAnnualCost,
    required this.insights,
  });

  final List<SubscriptionSummary> subscriptions;
  final List<Bill> recurringBills;
  final List<Loan> emiLoans;

  /// Sum of every section's own monthly-equivalent cost — subscriptions'
  /// [SubscriptionSummary.monthlyEquivalent], each recurring bill's
  /// per-occurrence amount treated as monthly (bills are due-date driven,
  /// not amortized), and each active loan's real [Loan.emiAmount].
  final double totalMonthlyCost;
  final double totalAnnualCost;

  /// Deterministic, rule-based observations only — never AI-generated.
  final List<String> insights;

  int get totalCommitmentCount => subscriptions.length + recurringBills.length + emiLoans.length;

  bool get isEmpty => totalCommitmentCount == 0;
}

class RecurringMoneyAggregator {
  RecurringMoneyAggregator._();

  /// A commitment "counts" as monthly for the combined total regardless
  /// of its own frequency — [SubscriptionSummary.monthlyEquivalent]
  /// already does this correctly (reusing [SubscriptionCalculator]'s own
  /// `annualCostFor`/12 conversion); bills and loan EMIs are naturally
  /// monthly by convention in this app already.
  static RecurringMoneySummary summarize({
    required List<RecurringTransaction> recurringTransactions,
    required List<Bill> bills,
    required List<Loan> loans,
    required DateTime now,
  }) {
    final subscriptions = SubscriptionCalculator.sortByCostDescending(
      SubscriptionCalculator.eligibleSubscriptions(recurringTransactions: recurringTransactions, now: now),
    );
    final recurringBills = bills.where((b) => b.isRecurring).toList();
    final emiLoans = loans.where((l) => l.isActive && l.emiAmount > 0).toList();

    final subscriptionsMonthly = SubscriptionCalculator.totalMonthlyCost(subscriptions);
    final billsMonthly = recurringBills.fold<double>(0, (sum, b) => sum + b.amount);
    final emiMonthly = emiLoans.fold<double>(0, (sum, l) => sum + l.emiAmount);
    final totalMonthly = subscriptionsMonthly + billsMonthly + emiMonthly;

    return RecurringMoneySummary(
      subscriptions: subscriptions,
      recurringBills: recurringBills,
      emiLoans: emiLoans,
      totalMonthlyCost: totalMonthly,
      totalAnnualCost: totalMonthly * 12,
      insights: _buildInsights(
        subscriptions: subscriptions,
        recurringTransactions: recurringTransactions,
        recurringBills: recurringBills,
        emiLoans: emiLoans,
        now: now,
      ),
    );
  }

  static List<String> _buildInsights({
    required List<SubscriptionSummary> subscriptions,
    required List<RecurringTransaction> recurringTransactions,
    required List<Bill> recurringBills,
    required List<Loan> emiLoans,
    required DateTime now,
  }) {
    final insights = <String>[];
    final totalCount = subscriptions.length + recurringBills.length + emiLoans.length;

    if (totalCount > 0) {
      insights.add('You have $totalCount recurring commitment${totalCount == 1 ? '' : 's'}.');
    }

    // A "new recurring payment" is one whose underlying record was
    // created within the last 30 days AND whose monthly cost clears the
    // SAME materiality bar FinancialActionEngine already uses for
    // surfacing subscription costs — reusing that threshold rather than
    // inventing a new one.
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final createdAtBySourceId = {for (final rt in recurringTransactions) rt.id: rt.createdAt};

    for (final subscription in subscriptions) {
      final createdAt = createdAtBySourceId[subscription.sourceId];
      if (createdAt != null &&
          createdAt.isAfter(thirtyDaysAgo) &&
          subscription.monthlyEquivalent >= FinancialActionEngine.subscriptionMaterialityThreshold) {
        insights.add(
          '₹${subscription.monthlyEquivalent.toStringAsFixed(0)}/month (${subscription.name}) appears to be a new recurring payment.',
        );
      }
    }
    for (final bill in recurringBills) {
      if (bill.createdAt.isAfter(thirtyDaysAgo) && bill.amount >= FinancialActionEngine.subscriptionMaterialityThreshold) {
        insights.add('₹${bill.amount.toStringAsFixed(0)}/month (${bill.title}) appears to be a new recurring payment.');
      }
    }

    return insights;
  }
}
