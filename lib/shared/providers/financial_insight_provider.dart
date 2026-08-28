import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recurring_transaction.dart';
import '../utils/financial_insight_engine.dart';
import 'financial_action_provider.dart';
import 'financial_health_trends_provider.dart';
import 'recurring_transaction_provider.dart';
import 'safe_to_spend_provider.dart';

/// PROACTIVE FINANCIAL INSIGHTS 1.0 (PHASE 3) — combines already-watched
/// providers ([financialActionPlanProvider], [financialHealthTrendsProvider],
/// [safeToSpendProvider], [recurringTransactionsProvider]) into the up-to-3
/// insight list the Dashboard renders. No new database, no duplicated
/// financial state — a plain [Provider], recomputing whenever any upstream
/// provider changes, exactly like [financialActionPlanProvider] itself.
final financialInsightsProvider = Provider<FinancialInsightResult>((ref) {
  final actionPlan = ref.watch(financialActionPlanProvider);
  final trends = ref.watch(financialHealthTrendsProvider);
  final safeToSpend = ref.watch(safeToSpendProvider);
  final recurringTransactions =
      ref.watch(recurringTransactionsProvider).value ?? const <RecurringTransaction>[];

  return FinancialInsightEngine.generate(
    actionPlan: actionPlan,
    trends: trends,
    safeToSpend: safeToSpend,
    recurringTransactions: recurringTransactions,
    now: DateTime.now(),
  );
});
