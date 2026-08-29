import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/goal.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/weekly_money_story.dart';
import '../repositories/app_settings_repository.dart';
import '../utils/financial_insight_engine.dart';
import '../utils/weekly_money_story_calculator.dart';
import 'daily_check_in_provider.dart';
import 'financial_action_provider.dart';
import 'financial_health_trends_provider.dart';
import 'goal_provider.dart';
import 'loan_provider.dart';
import 'recurring_transaction_provider.dart';
import 'safe_to_spend_provider.dart';
import 'transaction_provider.dart';

final financialInsightsProvider = Provider<FinancialInsightResult>((ref) {
  final actionPlan = ref.watch(financialActionPlanProvider);
  final trends = ref.watch(financialHealthTrendsProvider);
  final safeToSpend = ref.watch(safeToSpendProvider);
  final recurringTransactions =
      ref.watch(recurringTransactionsProvider).value ?? const <RecurringTransaction>[];
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
  final loans = ref.watch(loansProvider).value ?? const <Loan>[];
  final dailyCheckInState = ref.watch(dailyCheckInProvider);

  final repo = AppSettingsRepository.instance;
  final dismissed = repo.dismissedInsightIds();

  return FinancialInsightEngine.generate(
    actionPlan: actionPlan,
    trends: trends,
    safeToSpend: safeToSpend,
    recurringTransactions: recurringTransactions,
    transactions: transactions,
    goals: goals,
    loans: loans,
    dailyCheckInState: dailyCheckInState,
    dismissedInsightIds: dismissed,
    now: DateTime.now(),
  );
});

final weeklyMoneyStoryProvider = Provider<WeeklyMoneyStory>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  final safeToSpend = ref.watch(safeToSpendProvider);
  final dailyCheckInState = ref.watch(dailyCheckInProvider);

  return WeeklyMoneyStoryCalculator.calculate(
    transactions: transactions,
    safeToSpend: safeToSpend,
    dailyCheckInState: dailyCheckInState,
    now: DateTime.now(),
  );
});
