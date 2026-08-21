import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget.dart';
import '../utils/financial_action_engine.dart';
import 'budget_provider.dart';
import 'financial_planning_provider.dart';
import 'subscription_provider.dart';

/// FINANCIAL ACTION ENGINE 1.0 — combines already-watched providers
/// ([financialPlanningProvider], [budgetsProvider],
/// [eligibleSubscriptionsProvider]) into the up-to-3-action plan the
/// Dashboard's "Your Financial Actions" section (and the AI context)
/// render. A plain [Provider] — no state of its own, recomputes whenever
/// any upstream provider changes, exactly like [financialPlanningProvider]
/// itself.
final financialActionPlanProvider = Provider<FinancialActionPlan>((ref) {
  final planning = ref.watch(financialPlanningProvider);
  final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
  final subscriptions = ref.watch(eligibleSubscriptionsProvider);

  return FinancialActionEngine.generate(
    FinancialActionEngineInput(planning: planning, budgets: budgets, subscriptions: subscriptions),
  );
});
