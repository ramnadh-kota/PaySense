import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/spending_pattern.dart';
import '../repositories/decision_memory_repository.dart';
import '../utils/spending_pattern_engine.dart';
import 'transaction_provider.dart';

/// Provides computed spending patterns for the dashboard based on recent
/// transactions and decision memory history.
final spendingPatternsProvider = Provider<List<SpendingPattern>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);
  final transactions = transactionsAsync.valueOrNull ?? const [];

  // Synchronously analyze with empty decision history as baseline
  // while we also support pure deterministic computation
  return SpendingPatternEngine.analyze(
    transactions: transactions,
  );
});

/// Async provider when decision memory repository data is also joined.
final spendingPatternsWithMemoryProvider =
    FutureProvider<List<SpendingPattern>>((ref) async {
  final transactions = await ref.watch(transactionsProvider.future);
  final memoryHistory =
      await DecisionMemoryRepository.instance.getRecentDecisions(limit: 50);

  return SpendingPatternEngine.analyze(
    transactions: transactions,
    decisionHistory: memoryHistory,
  );
});
