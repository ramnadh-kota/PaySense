import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/financial_snapshot_builder.dart';
import 'financial_action_provider.dart';
import 'financial_health_provider.dart';
import 'financial_insight_provider.dart';
import 'financial_planning_provider.dart';
import 'safe_to_spend_provider.dart';

/// CONSUMER MONETIZATION FOUNDATION — PHASE 2. Reuses the SAME
/// already-computed [financialPlanningProvider]/[financialHealthProvider]/
/// [financialActionPlanProvider]/[financialInsightsProvider]/
/// [safeToSpendProvider] every other screen already depends on — no second
/// calculation, no new data source.
final financialSnapshotProvider = Provider<FinancialSnapshotResult>((ref) {
  final planning = ref.watch(financialPlanningProvider);
  final health = ref.watch(financialHealthProvider);
  final actionPlan = ref.watch(financialActionPlanProvider);
  final insights = ref.watch(financialInsightsProvider);
  final safeToSpend = ref.watch(safeToSpendProvider);

  return FinancialSnapshotBuilder.build(
    planning: planning,
    health: health,
    actionPlan: actionPlan,
    insights: insights,
    safeToSpend: safeToSpend,
  );
});
