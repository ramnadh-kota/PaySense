import 'package:paysense/features/ai/models/affordability_outcome.dart';
import 'package:paysense/features/ai/services/affordability_intent_parser.dart';
import 'package:paysense/shared/providers/analytics_provider.dart' show buildAnalyticsSummary;
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/bill_repository.dart';
import 'package:paysense/shared/repositories/goal_repository.dart';
import 'package:paysense/shared/repositories/loan_repository.dart';
import 'package:paysense/shared/repositories/recurring_transaction_repository.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/utils/affordability_calculator.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';
import 'package:paysense/shared/utils/safe_to_spend_calculator.dart';

/// Stage B of the affordability pipeline (PHASE 6/7) — loads the same
/// repository data every other orchestrator this session already reads,
/// computes [SafeToSpendResult]/[FinancialPlanningResult] via their
/// existing calculators (never re-derived), and hands off to
/// [AffordabilityCalculator] for the actual verdict. This class does
/// resolution/wiring only — it never computes affordability itself, and it
/// never writes to any repository (a pure simulation, PHASE 5).
class AffordabilityOrchestrator {
  AffordabilityOrchestrator._();

  static final AffordabilityOrchestrator instance = AffordabilityOrchestrator._();

  Future<AffordabilityOutcome> resolve(AffordabilityIntent intent, {DateTime? now}) async {
    if (intent.confidence == AffordabilityConfidence.medium) {
      return AffordabilityOutcome.clarification(
        intent.clarificationPrompt ?? 'How much does it cost?',
      );
    }
    if (!intent.isActionable) {
      return AffordabilityOutcome.none();
    }

    final referenceNow = now ?? DateTime.now();
    final wallets = await WalletRepository.instance.getAll();
    final transactions = await TransactionRepository.instance.getAll();
    final goals = await GoalRepository.instance.getAll();
    final loans = await LoanRepository.instance.getAll();
    final bills = await BillRepository.instance.getAll();
    final recurringTransactions = await RecurringTransactionRepository.instance.getAll();
    final settings = AppSettingsRepository.instance;

    final safeToSpend = SafeToSpendCalculator.calculate(
      wallets: wallets,
      bills: bills,
      loans: loans,
      recurringTransactions: recurringTransactions,
      now: referenceNow,
    );

    final planning = FinancialPlanningCalculator.calculate(
      transactions: transactions,
      wallets: wallets,
      goals: goals,
      loans: loans,
      bills: bills,
      recurringTransactions: recurringTransactions,
      analytics: buildAnalyticsSummary(transactions, referenceNow),
      emergencyFundEligibleWalletIds: settings.emergencyFundEligibleWalletIds(),
      emergencyFundTargetMonths: settings.emergencyFundTargetMonths(),
      now: referenceNow,
    );

    final result = AffordabilityCalculator.calculate(
      AffordabilityInput(
        purchaseAmount: intent.amount!,
        safeToSpend: safeToSpend,
        planning: planning,
        itemDescription: intent.itemDescription,
      ),
    );

    if (result.status == AffordabilityStatus.insufficientData) {
      final details = result.reasons.isEmpty ? '' : ' ${result.reasons.join(' ')}';
      return AffordabilityOutcome.notFound('${result.recommendation}$details');
    }

    return AffordabilityOutcome.calculated(result, itemDescription: intent.itemDescription);
  }
}
