import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';

import '../utils/allowance_calculator.dart';
import '../utils/spending_decision_calculator.dart';
import '../utils/spending_limit_calculator.dart';

/// Phase 6D — Decision Coach Dialog
///
/// Finalized decision-coaching UX shown before confirming an expense.
/// Synthesizes SpendingLimit, Allowance, Affordability, PurchaseImpact,
/// and Pain-of-Paying into a clear visual hierarchy with non-judgmental guidance.
class DecisionCoachDialog extends StatelessWidget {
  const DecisionCoachDialog({
    super.key,
    required this.amount,
    this.decision,
    this.emiPercentage,
    this.savingsGoalPercentage,
    this.comparisonMessage = '',
    this.categorySpendingLimit,
    this.allowance,
    this.verdictLine,
    this.guidanceLine,
  });

  final double amount;
  final SpendingDecisionResult? decision;

  /// Null when there's no active-loan EMI data to compare against — the
  /// EMI Impact card is hidden rather than showing a fabricated percentage.
  final double? emiPercentage;

  /// Null when there's no incomplete savings goal to compare against — the
  /// Savings Goal card is hidden rather than showing a fabricated
  /// percentage.
  final double? savingsGoalPercentage;

  final String comparisonMessage;

  final SpendingLimitStatus? categorySpendingLimit;
  final AllowanceResult? allowance;
  final String? verdictLine;
  final String? guidanceLine;

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final effectiveSpendingLimit =
        decision?.categorySpendingLimit ?? categorySpendingLimit;
    final effectiveAllowance = decision?.allowance ?? allowance;
    final effectiveEmiPct = decision?.impact.emiPercentage ?? emiPercentage;
    final effectiveSavingsGoalPct =
        decision?.impact.savingsGoalPercentage ?? savingsGoalPercentage;
    final effectiveComparison =
        decision?.impact.perspectiveMessage ?? comparisonMessage;
    final effectiveVerdict = decision?.verdictLine ??
        verdictLine ??
        'Every purchase is a financial decision.';
    final effectiveGuidance = decision?.guidanceLine ?? guidanceLine;

    final tier = decision?.recommendationTier ??
        _fallbackTier(
          spendingLimit: effectiveSpendingLimit,
          allowance: effectiveAllowance,
        );

    final badgeConfig = _badgeConfigFor(tier);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header & Context
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.psychology_outlined,
                      size: 24,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Think Before You Pay',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                        ),
                        Text(
                          'PaySense Decision Coach',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Amount Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    currencyFormatter.format(amount),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Overall Recommendation Banner & Explanation (WHY)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: badgeConfig.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: badgeConfig.borderColor, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          badgeConfig.icon,
                          size: 18,
                          color: badgeConfig.textColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          badgeConfig.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: badgeConfig.textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      effectiveVerdict,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    if (effectiveGuidance != null &&
                        effectiveGuidance.isNotEmpty &&
                        effectiveGuidance != effectiveVerdict) ...[
                      const SizedBox(height: 4),
                      Text(
                        effectiveGuidance,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. Supporting Financial Signals (Scrollable list)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (effectiveSpendingLimit != null) ...[
                        _InsightCard(
                          icon: Icons.speed_rounded,
                          title:
                              '${effectiveSpendingLimit.categoryName} Spending Limit',
                          body: effectiveSpendingLimit.summaryLine,
                          chipLabel: effectiveSpendingLimit.state ==
                                  SpendingLimitState.exceeded
                              ? 'Limit Reached'
                              : (effectiveSpendingLimit.state ==
                                      SpendingLimitState.approaching
                                  ? 'Approaching'
                                  : 'On Track'),
                          chipColor: effectiveSpendingLimit.state ==
                                  SpendingLimitState.exceeded
                              ? AppColors.danger
                              : (effectiveSpendingLimit.state ==
                                      SpendingLimitState.approaching
                                  ? AppColors.warning
                                  : AppColors.success),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (effectiveAllowance != null &&
                          effectiveAllowance.hasSufficientData) ...[
                        _InsightCard(
                          icon: Icons.account_balance_rounded,
                          title: 'Discretionary Allowance',
                          body: effectiveAllowance.summaryLine,
                          chipLabel: effectiveAllowance.state.label,
                          chipColor: effectiveAllowance.state ==
                                  AllowanceState.overAllowance
                              ? AppColors.danger
                              : (effectiveAllowance.state ==
                                          AllowanceState.tight ||
                                      effectiveAllowance.state ==
                                          AllowanceState.watchful
                                  ? AppColors.warning
                                  : AppColors.success),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (effectiveEmiPct != null) ...[
                        _InsightCard(
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'EMI Impact',
                          body:
                              'This purchase equals ${effectiveEmiPct.toStringAsFixed(0)}% of your monthly EMI.',
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (effectiveSavingsGoalPct != null) ...[
                        _InsightCard(
                          icon: Icons.savings_rounded,
                          title: 'Savings Goal Pace',
                          body:
                              '${currencyFormatter.format(amount)} represents ${effectiveSavingsGoalPct.toStringAsFixed(0)}% of your remaining savings goal amount.',
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (effectiveComparison.isNotEmpty) ...[
                        _InsightCard(
                          icon: Icons.lightbulb_rounded,
                          title: 'Perspective',
                          body: effectiveComparison,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Actions (Cancel / Spend Anyway)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Spend Anyway'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static SpendingRecommendationTier _fallbackTier({
    SpendingLimitStatus? spendingLimit,
    AllowanceResult? allowance,
  }) {
    if ((spendingLimit != null &&
            spendingLimit.state == SpendingLimitState.exceeded) ||
        (allowance != null &&
            allowance.state == AllowanceState.overAllowance)) {
      return SpendingRecommendationTier.avoid;
    }
    if ((spendingLimit != null &&
            spendingLimit.state == SpendingLimitState.approaching) ||
        (allowance != null &&
            (allowance.state == AllowanceState.tight ||
                allowance.state == AllowanceState.watchful))) {
      return SpendingRecommendationTier.thinkAgain;
    }
    return SpendingRecommendationTier.spend;
  }

  static _BadgeConfig _badgeConfigFor(SpendingRecommendationTier tier) {
    switch (tier) {
      case SpendingRecommendationTier.spend:
        return _BadgeConfig(
          label: 'Comfortable to spend',
          icon: Icons.check_circle_outline_rounded,
          textColor: AppColors.success,
          backgroundColor: AppColors.success.withValues(alpha: 0.10),
          borderColor: AppColors.success.withValues(alpha: 0.25),
        );
      case SpendingRecommendationTier.thinkAgain:
        return _BadgeConfig(
          label: 'Think again',
          icon: Icons.lightbulb_outline_rounded,
          textColor: AppColors.warning,
          backgroundColor: AppColors.warning.withValues(alpha: 0.12),
          borderColor: AppColors.warning.withValues(alpha: 0.30),
        );
      case SpendingRecommendationTier.avoid:
        return _BadgeConfig(
          label: 'Consider avoiding',
          icon: Icons.info_outline_rounded,
          textColor: AppColors.danger,
          backgroundColor: AppColors.danger.withValues(alpha: 0.10),
          borderColor: AppColors.danger.withValues(alpha: 0.25),
        );
    }
  }
}

class _BadgeConfig {
  const _BadgeConfig({
    required this.label,
    required this.icon,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.title,
    required this.body,
    this.chipLabel,
    this.chipColor,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? chipLabel;
  final Color? chipColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ),
                    if (chipLabel != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (chipColor ?? AppColors.primary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          chipLabel!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: chipColor ?? AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
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
