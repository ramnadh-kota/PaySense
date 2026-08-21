import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/features/ai/models/chat_message.dart';
import 'dart:convert';

import 'package:paysense/features/ai/models/affordability_outcome.dart';
import 'package:paysense/features/ai/models/financial_context.dart';
import 'package:paysense/features/ai/models/tax_outcome.dart';
import 'package:paysense/features/ai/models/what_if_result.dart';
import 'package:paysense/features/ai/services/affordability_intent_parser.dart';
import 'package:paysense/features/ai/services/affordability_orchestrator.dart';
import 'package:paysense/features/ai/services/ai_question_router.dart';
import 'package:paysense/features/ai/services/ai_service.dart';
import 'package:paysense/features/ai/services/openai_service.dart';
import 'package:paysense/features/ai/services/financial_context_builder.dart';
import 'package:paysense/features/ai/services/tax_intent_parser.dart';
import 'package:paysense/features/ai/services/tax_orchestrator.dart';
import 'package:paysense/features/ai/services/what_if_intent_parser.dart';
import 'package:paysense/features/ai/services/what_if_orchestrator.dart';
import 'package:paysense/shared/utils/tax_calculator.dart';

/// Provider for the AI service implementation. Talks to the PaySense AI
/// backend (Cloud Run) over HTTPS — see ai_backend/README.md. The OpenAI API
/// key is never present in this app.
final aiServiceProvider = Provider<AiService>((ref) {
  return OpenAiService();
});

final aiChatProvider = AsyncNotifierProvider<AiChatNotifier, List<ChatMessage>>(
  AiChatNotifier.new,
);

class AiChatNotifier extends AsyncNotifier<List<ChatMessage>> {
  /// Guards against firing a second AI request while one is already in
  /// flight (e.g. a rapid double-tap on send, or a suggestion chip tapped
  /// mid-request) — keeps backend/OpenAI usage bounded to one call per user
  /// action, mirroring the in-flight guard pattern used by BillsNotifier and
  /// LoansNotifier for their own duplicate-trigger risks.
  bool _isSending = false;

  @override
  Future<List<ChatMessage>> build() async {
    return <ChatMessage>[];
  }

  Future<void> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || _isSending) return;

    _isSending = true;
    try {
      final now = DateTime.now();
      final userMessage = ChatMessage(
        id: now.microsecondsSinceEpoch.toString(),
        text: trimmed,
        isUser: true,
        createdAt: now,
      );

      final withUserMessage = [
        ...(state.asData?.value ?? const <ChatMessage>[]),
        userMessage,
      ];
      // Keep existing messages visible (via copyWithPrevious) while the
      // request is in flight rather than blanking the conversation.
      state = AsyncData(withUserMessage);
      state = const AsyncLoading<List<ChatMessage>>().copyWithPrevious(state);

      // AI WHAT-IF INTELLIGENCE 2.0 — a deterministic pre-step that runs
      // before the normal AI flow. HIGH confidence resolves to a real
      // calculator result (still explained by the AI below, never by the
      // AI doing the arithmetic itself); MEDIUM asks a direct clarifying
      // question WITHOUT calling the AI backend at all; LOW/`none` (not a
      // what-if question, or resolution found no matching entity) falls
      // through unchanged to the existing AI flow.
      final whatIfIntent = WhatIfIntentParser.parse(trimmed);
      WhatIfOutcome? whatIfOutcome;
      if (whatIfIntent.type != WhatIfIntentType.none) {
        try {
          whatIfOutcome = await WhatIfOrchestrator.instance.resolve(whatIfIntent);
        } catch (_) {
          // Resolution failure (e.g. a repository read error) must never
          // block the normal AI flow — just proceed without a scenario.
          whatIfOutcome = null;
        }
      }

      if (whatIfOutcome != null &&
          (whatIfOutcome.kind == WhatIfOutcomeKind.clarification ||
              whatIfOutcome.kind == WhatIfOutcomeKind.notFound)) {
        state = AsyncData([...withUserMessage, _reply(whatIfOutcome.message!)]);
        return;
      }

      // INDIA TAX PLANNER 1.0 — a second deterministic pre-step, tried only
      // when the what-if pipeline above found nothing (a message can't be
      // both). Same HIGH/ask-directly/fall-through shape as PHASE 13's
      // what-if gate: a calculated/comparison outcome is still explained by
      // the AI below (never computed by it); a clarification/notFound
      // short-circuits with a direct reply, no AI call at all.
      TaxOutcome? taxOutcome;
      if (whatIfIntent.type == WhatIfIntentType.none) {
        final taxIntent = TaxIntentParser.parse(trimmed);
        if (taxIntent.type != TaxIntentType.none) {
          try {
            taxOutcome = await TaxOrchestrator.instance.resolve(taxIntent);
          } catch (_) {
            taxOutcome = null;
          }
        }
      }

      if (taxOutcome != null &&
          (taxOutcome.kind == TaxOutcomeKind.clarification ||
              taxOutcome.kind == TaxOutcomeKind.notFound)) {
        state = AsyncData([...withUserMessage, _reply(taxOutcome.message!)]);
        return;
      }

      // FINANCIAL ACTION ENGINE 1.0 / "CAN I AFFORD THIS?" — a third
      // deterministic pre-step, tried only when neither the what-if nor
      // the tax pipeline above found anything. Same HIGH/ask-directly/
      // fall-through shape: a calculated outcome is still explained by the
      // AI below (never computed by it); a clarification/notFound
      // short-circuits with a direct reply, no AI call at all. The backend
      // never calculates affordability itself (PHASE 7).
      AffordabilityOutcome? affordabilityOutcome;
      if (whatIfIntent.type == WhatIfIntentType.none &&
          (taxOutcome == null || taxOutcome.kind == TaxOutcomeKind.none)) {
        final affordabilityIntent = AffordabilityIntentParser.parse(trimmed);
        if (affordabilityIntent.type != AffordabilityIntentType.none) {
          try {
            affordabilityOutcome = await AffordabilityOrchestrator.instance.resolve(affordabilityIntent);
          } catch (_) {
            affordabilityOutcome = null;
          }
        }
      }

      if (affordabilityOutcome != null &&
          (affordabilityOutcome.kind == AffordabilityOutcomeKind.clarification ||
              affordabilityOutcome.kind == AffordabilityOutcomeKind.notFound)) {
        state = AsyncData([...withUserMessage, _reply(affordabilityOutcome.message!)]);
        return;
      }

      // PHASE 4: deterministic keyword routing — trims which aggregated
      // context sections are populated instead of always sending every
      // section, without any NLP/intent model. `classifyQuestion` falls
      // back to `{general}` (== "include everything") whenever it isn't
      // confident, per the "use the broader context safely" guidance.
      final categories = classifyQuestion(trimmed);

      FinancialContext financialContext;
      try {
        financialContext = await FinancialContextBuilder.instance.build(
          relevantCategories: categories,
        );
      } catch (_) {
        state = AsyncData([
          ...withUserMessage,
          _reply(
            'Unable to load your financial data right now. Please try again later.',
          ),
        ]);
        return;
      }

      final calculatedResult = whatIfOutcome?.kind == WhatIfOutcomeKind.calculated
          ? whatIfOutcome!.result
          : null;
      final taxOutcomeForCard = taxOutcome != null &&
              (taxOutcome.kind == TaxOutcomeKind.calculated ||
                  taxOutcome.kind == TaxOutcomeKind.comparison)
          ? taxOutcome
          : null;
      final affordabilityOutcomeForCard =
          affordabilityOutcome?.kind == AffordabilityOutcomeKind.calculated
              ? affordabilityOutcome
              : null;

      String replyText;
      try {
        final service = ref.read(aiServiceProvider);
        // PHASE 11: reuses the SAME generic financial_context map the
        // backend already accepts — no backend contract change. The system
        // prompt already instructs the model to use figures already
        // present in financial_context and never contradict them, so this
        // is enough to guarantee the AI explains (never recomputes) the
        // deterministic scenario below.
        final contextMap = financialContext.toMap();
        if (calculatedResult != null) {
          contextMap['whatIfScenario'] = _whatIfScenarioMap(calculatedResult);
        }
        if (taxOutcomeForCard != null) {
          contextMap['taxScenario'] = _taxScenarioMap(taxOutcomeForCard);
        }
        if (affordabilityOutcomeForCard != null) {
          contextMap['affordabilityScenario'] = _affordabilityScenarioMap(affordabilityOutcomeForCard);
        }
        final fcString = jsonEncode(contextMap);
        final aiResponse = await service.ask(
          message: trimmed,
          financialContext: fcString,
        );
        // Defense-in-depth: OpenAiService itself already rejects a blank
        // model response as an AiServiceException, but AiService is an
        // interface any implementation must honor — an empty/whitespace
        // reply must never render as a blank chat bubble (PHASE 13).
        replyText = aiResponse.trim().isEmpty
            ? _fallbackText(
                'AI analysis returned an unexpected response. Please try again later.',
                financialContext,
              )
            : aiResponse;
      } on AiServiceException catch (e) {
        replyText = _fallbackText(e.message, financialContext);
      } catch (_) {
        replyText = _fallbackText(
          'AI analysis is temporarily unavailable. Please try again later.',
          financialContext,
        );
      }

      state = AsyncData([
        ...withUserMessage,
        _reply(
          replyText,
          whatIfResult: calculatedResult,
          taxOutcome: taxOutcomeForCard,
          affordabilityOutcome: affordabilityOutcomeForCard,
        ),
      ]);
    } finally {
      _isSending = false;
    }
  }

  ChatMessage _reply(
    String text, {
    WhatIfResult? whatIfResult,
    TaxOutcome? taxOutcome,
    AffordabilityOutcome? affordabilityOutcome,
  }) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      createdAt: DateTime.now(),
      whatIfResult: whatIfResult,
      taxOutcome: taxOutcome,
      affordabilityOutcome: affordabilityOutcome,
    );
  }

  /// Only deterministic numbers/dates — PHASE 19: never any raw SMS,
  /// account numbers, or credentials, matching every other section of
  /// [FinancialContext.toMap].
  Map<String, dynamic> _whatIfScenarioMap(WhatIfResult result) {
    return {
      'type': result.type.name,
      'currentValue': result.currentValue,
      'projectedValue': result.projectedValue,
      'difference': result.difference,
      if (result.monthlyChange != null) 'monthlyChange': result.monthlyChange,
      if (result.monthsBefore != null) 'monthsBefore': result.monthsBefore,
      if (result.monthsAfter != null) 'monthsAfter': result.monthsAfter,
      if (result.completionDateBefore != null)
        'completionDateBefore': result.completionDateBefore!.toIso8601String(),
      if (result.completionDateAfter != null)
        'completionDateAfter': result.completionDateAfter!.toIso8601String(),
      if (result.entityName != null) 'entityName': result.entityName,
      'isSimulationOnly': true,
    };
  }

  /// Only aggregated tax figures — PHASE 17: never any raw SMS, account
  /// numbers, or credentials.
  Map<String, dynamic> _taxScenarioMap(TaxOutcome outcome) {
    if (outcome.kind == TaxOutcomeKind.comparison) {
      final comparison = outcome.comparison!;
      return {
        'oldRegime': _taxResultMap(comparison.oldRegime),
        'newRegime': _taxResultMap(comparison.newRegime),
        'differenceOldMinusNew': comparison.difference,
        'isSimulationOnly': true,
      };
    }
    return {
      if (outcome.entityLabel != null) 'scenarioLabel': outcome.entityLabel,
      if (outcome.beforeResult != null) 'before': _taxResultMap(outcome.beforeResult!),
      'result': _taxResultMap(outcome.result!),
      'isSimulationOnly': true,
    };
  }

  Map<String, dynamic> _taxResultMap(TaxCalculationResult result) {
    return {
      'regime': result.regime.name,
      'grossIncome': result.grossIncome,
      'standardDeduction': result.standardDeduction,
      'totalDeductions': result.totalDeductions,
      'taxableIncome': result.taxableIncome,
      'estimatedTax': result.estimatedTax,
      'effectiveTaxRatePercent': result.effectiveTaxRatePercent,
      'remainingTax': result.remainingTax,
      'excessTds': result.excessTds,
      'monthlyTaxProvision': result.monthlyTaxProvision,
      'financialYearLabel': result.financialYearLabel,
    };
  }

  /// Only aggregated affordability figures — PHASE 12/17: never any raw
  /// SMS, account numbers, or credentials.
  Map<String, dynamic> _affordabilityScenarioMap(AffordabilityOutcome outcome) {
    final result = outcome.result!;
    return {
      if (outcome.itemDescription != null) 'itemDescription': outcome.itemDescription,
      'status': result.status.name,
      'purchaseAmount': result.purchaseAmount,
      'availableAfterPurchase': result.availableAfterPurchase,
      'emergencyFundImpact': result.emergencyFundImpact,
      'goalImpact': result.goalImpact,
      'cashFlowImpact': result.cashFlowImpact,
      if (result.estimatedGoalDelayMonths != null)
        'estimatedGoalDelayMonths': result.estimatedGoalDelayMonths,
      'recommendation': result.recommendation,
      'reasons': result.reasons,
      'warnings': result.warnings,
      'confidence': result.confidence,
      'isSimulationOnly': true,
    };
  }

  /// When OpenAI/the backend is unavailable, degrade gracefully using the
  /// financial data PaySense already computed locally rather than a bare
  /// error — the app must remain useful without OpenAI.
  String _fallbackText(String reason, FinancialContext context) {
    final buffer = StringBuffer(reason);
    if (context.financialHealthStatus.isNotEmpty) {
      buffer.writeln();
      buffer.writeln();
      buffer.write(
        "Here's what your local Financial Health shows: "
        '${context.financialHealthScore}/100 (${context.financialHealthStatus}).',
      );
      if (context.topFinancialInsight.isNotEmpty) {
        buffer.writeln();
        buffer.write(context.topFinancialInsight);
      }
    }
    return buffer.toString().trim();
  }
}
