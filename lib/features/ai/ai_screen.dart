import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/constants/disclaimers.dart';
import 'package:paysense/features/ai/models/chat_message.dart';
import 'package:paysense/features/ai/models/affordability_outcome.dart';
import 'package:paysense/features/ai/models/tax_outcome.dart';
import 'package:paysense/features/ai/models/what_if_result.dart';
import 'package:paysense/features/ai/providers/ai_provider.dart';
import 'package:paysense/features/affordability/presentation/affordability_screen.dart';
import 'package:paysense/shared/utils/affordability_calculator.dart';
import 'package:paysense/shared/utils/tax_calculator.dart';
import 'package:paysense/features/ai/services/what_if_intent_parser.dart' show WhatIfIntentType;
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/providers/financial_planning_provider.dart';
import 'package:paysense/shared/utils/financial_planning_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'package:paysense/shared/widgets/premium_discovery_banner.dart';
import 'package:paysense/shared/models/entitlement.dart';
import 'package:paysense/shared/providers/entitlement_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';

/// PHASE 15 — the exact disclaimer every What-If result card must show.
/// Exposed as a public constant (rather than an inline string literal)
/// purely so it has one single source of truth that a test can assert on
/// without needing to pump the whole widget tree.
const String whatIfSimulationDisclaimer =
    'Simulation — your actual finances have not been changed.';

/// Compact, curated set of quick-question chips (PHASE 5 — "do not add
/// dozens of chips, keep the UI compact"). Each sends a real prompt through
/// the same pipeline as manually-typed text.
const List<String> _quickQuestions = [
  'Can I afford to spend today?',
  'How am I doing this month?',
  'Where am I spending the most?',
  'Am I on track for my goals?',
  'When will I complete my emergency fund?',
  'How can I reduce my debt?',
];

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final message = (text ?? _controller.text).trim();
    if (message.isEmpty) return;
    ref.read(aiChatProvider.notifier).sendMessage(message);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bgColor = isUser ? AppColors.primary : AppColors.surface;
    final textColor = isUser ? Colors.white : AppColors.textPrimary;
    final whatIfResult = message.whatIfResult;
    final taxOutcome = message.taxOutcome;
    final affordabilityOutcome = message.affordabilityOutcome;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        if (whatIfResult != null) ...[
          _WhatIfResultCard(result: whatIfResult),
          const SizedBox(height: 8),
        ],
        if (taxOutcome != null) ...[
          _TaxOutcomeCard(outcome: taxOutcome),
          const SizedBox(height: 8),
        ],
        if (affordabilityOutcome != null) ...[
          _AffordabilityOutcomeCard(outcome: affordabilityOutcome),
          const SizedBox(height: 8),
        ],
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: textColor),
          ),
        ),
        Text(
          _shortDate(message.createdAt),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Thinking...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final userName = userProfileAsync.asData?.value?.fullName ?? 'User';

    final chatState = ref.watch(aiChatProvider);
    final isSending = chatState.isLoading;
    final planning = ref.watch(financialPlanningProvider);

    return Scaffold(
      // Default true — kept explicit since it's load-bearing here: with it,
      // MediaQuery.viewInsets.bottom correctly excludes the keyboard from
      // the body's available height, which is what lets the Expanded
      // scrollable below shrink instead of overflowing.
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          // BUG FIX (keyboard overflow): everything except the input row
          // used to sit in one non-scrollable Column alongside an
          // Expanded conversation card. When the keyboard reduced the
          // Column's available height, the fixed-size chrome above the
          // conversation (greeting, Financial Planning card, Tax Planner
          // card, quick-question chips) no longer fit and the Column
          // overflowed at the bottom. The fix: ONE Expanded, scrollable
          // ListView holds everything that can grow (header, cards,
          // banner, chips, conversation) — it shrinks and scrolls
          // instead of overflowing — while the input row is a fixed
          // sibling OUTSIDE the Expanded, so it always stays visible
          // directly above the keyboard.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  children: [
                    Text(
                      'Hello, $userName',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "I'm your PaySense AI Coach.",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // PHASE 6: compact Financial Planning entry point, using
                    // the real calculated readiness score — never a
                    // duplicate of the full Financial Planning screen.
                    // Tapping asks the AI a canned question rather than
                    // navigating away, since the user is already on the AI
                    // screen.
                    _FinancialPlanningCard(
                      readinessScore: planning.readinessScore,
                      onAskAi: isSending
                          ? null
                          : () => _send('How can I improve my financial position?'),
                    ),

                    const SizedBox(height: 12),

                    // INDIA TAX PLANNER 1.0 — PHASE 13's second suggested
                    // entry point (alongside Financial Planning). Navigates
                    // to the full Tax Planner screen rather than asking a
                    // canned question, since entering income/deductions
                    // needs a form, not chat.
                    _TaxPlannerEntryCard(),

                    const SizedBox(height: 12),

                    // CONSUMER MONETIZATION FOUNDATION (PHASE 7) — a small,
                    // non-blocking discovery card for free users only. The
                    // actual AI chat below is NEVER disabled or restricted
                    // by this — it's purely additive.
                    if (!canAccessEntitlement(ref, Entitlement.aiAssistant)) ...[
                      const PremiumDiscoveryBanner(
                        title: 'Ask PaySense anything about your finances.',
                        subtitle: 'Unlimited AI conversations are part of PaySense Plus.',
                        analyticsContext: 'ai_assistant',
                      ),
                      const SizedBox(height: 12),
                    ],

                    // PHASE 15: for a brand-new account, don't pretend to
                    // give personalized advice — but general financial
                    // questions still work (the input below is never
                    // disabled).
                    if (!planning.hasSufficientData) ...[
                      _EmptyDataBanner(),
                      const SizedBox(height: 12),
                    ],

                    // Quick questions (PHASE 5) — compact, curated, real
                    // prompts. Part of the same scrollable as everything
                    // else, so they're always reachable by scrolling even
                    // with the keyboard open, never clipped behind it.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickQuestions.map((question) {
                        return ActionChip(
                          label: Text(question),
                          onPressed: isSending ? null : () => _send(question),
                          backgroundColor: AppColors.surface,
                          labelStyle: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textPrimary),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Conversation area — sized to its content now (not
                    // force-filled via Expanded), since it lives inside the
                    // page-level scrollable above.
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: chatState.when(
                          skipLoadingOnReload: true,
                          data: (messages) {
                            if (messages.isEmpty && !isSending) {
                              return SizedBox(
                                height: 140,
                                child: Center(
                                  child: Text(
                                    'Ask me anything about your money.',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(color: AppColors.textSecondary),
                                  ),
                                ),
                              );
                            }

                            return Column(
                              children: [
                                for (final message in messages) ...[
                                  Align(
                                    alignment: message.isUser
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: _buildMessageBubble(message),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                if (isSending)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _buildTypingIndicator(),
                                  ),
                              ],
                            );
                          },
                          loading: () => const SizedBox(
                            height: 140,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          // In practice unreachable (sendMessage always
                          // resolves to AsyncData, even on failure — see
                          // ai_provider.dart) but kept as a safe fallback
                          // per PHASE 13.
                          error: (error, stack) => Center(
                            child: Text(
                              'Unable to reach your financial assistant right '
                              'now. Your PaySense data is safe.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Input row — a fixed-size sibling OUTSIDE the Expanded
              // scrollable above, so it always stays visible directly
              // above the keyboard, never overflowed or hidden behind it.
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !isSending,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        filled: true,
                        fillColor: AppColors.inputBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: isSending ? AppColors.disabledText : AppColors.primary,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: isSending ? null : () => _send(),
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// PHASE 6: a compact card near the top of AI, using the real
/// [FinancialPlanningResult.readinessScore] — never a duplicate of the full
/// Financial Planning screen (tapping it navigates there instead of
/// re-rendering its content here).
class _TaxPlannerEntryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.taxPlanner),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.lightTeal, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tax Planner',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Estimate your income tax and compare Old vs New Regime',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _FinancialPlanningCard extends StatelessWidget {
  const _FinancialPlanningCard({required this.readinessScore, required this.onAskAi});

  final int readinessScore;
  final VoidCallback? onAskAi;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onAskAi,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightTeal,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.insights_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Planning',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  "You're $readinessScore% financially prepared.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Ask AI how to improve your financial position →',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// PHASE 15: shown for a brand-new account with nothing to base
/// personalized advice on. General financial-education questions still
/// work — the chat input is never disabled by this.
class _EmptyDataBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.surfaceVariant,
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Add some income and expense data to PaySense and I'll help "
              "you understand your finances. You can still ask me general "
              "financial questions in the meantime.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// AI WHAT-IF INTELLIGENCE 2.0 (PHASE 14/15/20) — the structured result of a
/// deterministic what-if calculation, shown alongside (never instead of)
/// the AI's plain-language explanation. Every figure here comes straight
/// from [WhatIfResult] — this widget only formats, it never computes.
/// Uses [AppColors] tokens exclusively so it stays correct in both Light
/// and Dark mode with no hardcoded colors.
class _WhatIfResultCard extends StatelessWidget {
  const _WhatIfResultCard({required this.result});

  final WhatIfResult result;

  String _title() {
    final entity = result.entityName;
    switch (result.type) {
      case WhatIfIntentType.increaseSavings:
        return 'Save more per month';
      case WhatIfIntentType.decreaseExpenses:
        return 'Change monthly expenses';
      case WhatIfIntentType.reduceCategorySpending:
        return entity == null ? 'Reduce category spending' : 'Reduce $entity spending';
      case WhatIfIntentType.extraLoanPayment:
        return entity == null ? 'Extra loan payment' : 'Extra payment — $entity';
      case WhatIfIntentType.stopSubscription:
        return entity == null ? 'Stop a subscription' : 'Stop $entity';
      case WhatIfIntentType.reachGoal:
        return entity == null ? 'Reach a savings target' : 'Reach "$entity"';
      case WhatIfIntentType.reachEmergencyFund:
        return 'Emergency fund progress';
      case WhatIfIntentType.none:
        return 'What if?';
    }
  }

  String _fmt(double value) => '₹${value.abs().toStringAsFixed(0)}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String? _dateLabel(DateTime? date) {
    if (date == null) return null;
    return '${_months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final beforeDate = _dateLabel(result.completionDateBefore);
    final afterDate = _dateLabel(result.completionDateAfter);
    final hasTimelineChange =
        beforeDate != null && afterDate != null && beforeDate != afterDate;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.query_stats_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'WHAT IF?',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _title(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Current: ${_fmt(result.currentValue)}   →   New: ${_fmt(result.projectedValue)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (hasTimelineChange) ...[
            const SizedBox(height: 4),
            Text(
              'Projected completion: $beforeDate → $afterDate',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (afterDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Projected completion: $afterDate',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  whatIfSimulationDisclaimer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// INDIA TAX PLANNER 1.0 (PHASE 14/15/20) — the structured result of a
/// deterministic tax calculation or regime comparison, shown alongside the
/// AI's explanation. Every figure comes straight from [TaxOutcome] — this
/// widget only formats, it never computes tax. [AppColors] tokens only, no
/// hardcoded colors, matching [_WhatIfResultCard]'s dark-mode treatment.
class _TaxOutcomeCard extends StatelessWidget {
  const _TaxOutcomeCard({required this.outcome});

  final TaxOutcome outcome;

  String _fmt(double value) => '₹${value.abs().toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                outcome.kind == TaxOutcomeKind.comparison ? 'OLD VS NEW REGIME' : 'TAX ESTIMATE',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (outcome.kind == TaxOutcomeKind.comparison)
            _buildComparison(context, outcome.comparison!)
          else
            _buildSingle(context, outcome),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  taxDisclaimer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingle(BuildContext context, TaxOutcome outcome) {
    final result = outcome.result!;
    final before = outcome.beforeResult;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (outcome.entityLabel != null)
          Text(
            outcome.entityLabel!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        const SizedBox(height: 4),
        if (before != null)
          Text(
            'Current estimated tax: ${_fmt(before.estimatedTax)}   →   New: ${_fmt(result.estimatedTax)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          )
        else
          Text(
            'Estimated tax (FY ${result.financialYearLabel}): ${_fmt(result.estimatedTax)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        const SizedBox(height: 4),
        Text(
          'Suggested monthly provision: ${_fmt(result.monthlyTaxProvision)}/month',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildComparison(BuildContext context, TaxRegimeComparisonResult comparison) {
    final diff = comparison.difference.abs();
    final lowerLabel = comparison.lowerTaxRegime == TaxRegime.newRegime ? 'New Regime' : 'Old Regime';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New Regime: ${_fmt(comparison.newRegime.estimatedTax)}   |   '
          'Old Regime: ${_fmt(comparison.oldRegime.estimatedTax)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          diff == 0
              ? 'Based on the information entered, both regimes produce the same estimated tax.'
              : 'Based on the information entered, the estimated tax is lower under the $lowerLabel by ${_fmt(diff)}.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// FINANCIAL ACTION ENGINE 1.0 / "CAN I AFFORD THIS?" (PHASE 9/13) — the
/// structured result of a deterministic affordability calculation, shown
/// alongside the AI's explanation. Every figure comes straight from
/// [AffordabilityResult] — this widget only formats, it never computes.
/// PHASE 13 safety: never says "buy it" or guarantees affordability, only
/// ever the neutral comfortable/possible/risky/not-recommended language
/// [AffordabilityResult] itself already produced.
class _AffordabilityOutcomeCard extends StatelessWidget {
  const _AffordabilityOutcomeCard({required this.outcome});

  final AffordabilityOutcome outcome;

  String _fmt(double value) => '₹${value.abs().toStringAsFixed(0)}';

  (String, Color, IconData) _statusVisuals(AffordabilityStatus status) {
    switch (status) {
      case AffordabilityStatus.comfortable:
        return ('Comfortable', AppColors.success, Icons.check_circle_outline_rounded);
      case AffordabilityStatus.possible:
        return ('Possible', AppColors.primary, Icons.info_outline_rounded);
      case AffordabilityStatus.risky:
        return ('Possible, but risky', AppColors.warning, Icons.warning_amber_rounded);
      case AffordabilityStatus.notRecommended:
        return ('Not recommended right now', AppColors.danger, Icons.error_outline_rounded);
      case AffordabilityStatus.insufficientData:
        return ('Not enough information', AppColors.textSecondary, Icons.help_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = outcome.result!;
    final (statusLabel, statusColor, statusIcon) = _statusVisuals(result.status);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'CAN I AFFORD THIS?',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            outcome.itemDescription != null
                ? '${_fmt(result.purchaseAmount)} — ${outcome.itemDescription}'
                : _fmt(result.purchaseAmount),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cash after purchase: ${_fmt(result.availableAfterPurchase)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (result.emergencyFundImpact > 0)
            Text(
              'Emergency fund: ↓ ${_fmt(result.emergencyFundImpact)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          if (result.estimatedGoalDelayMonths != null)
            Text(
              'Goal impact: roughly ${result.estimatedGoalDelayMonths} month'
              '${result.estimatedGoalDelayMonths == 1 ? '' : 's'} of contribution',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AffordabilityScreen(initialAmount: result.purchaseAmount),
              ),
            ),
            child: Text(
              'See full analysis →',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'This is a simulation, not financial authorization — nothing has been purchased or changed.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
