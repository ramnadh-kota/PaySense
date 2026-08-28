import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/entitlement.dart';
import 'package:paysense/shared/providers/entitlement_provider.dart';
import 'package:paysense/shared/providers/financial_planning_provider.dart';
import 'package:paysense/shared/providers/safe_to_spend_provider.dart';
import 'package:paysense/shared/utils/affordability_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'package:paysense/shared/widgets/premium_discovery_banner.dart';

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// PHASE 10 — the full "Can I Afford This?" screen. A pure SIMULATION:
/// every figure comes from [AffordabilityCalculator], fed by the same
/// [safeToSpendProvider]/[financialPlanningProvider] the rest of the app
/// already uses — nothing here is ever saved or mutates any repository.
class AffordabilityScreen extends ConsumerStatefulWidget {
  const AffordabilityScreen({super.key, this.initialAmount, this.initialItemDescription});

  final double? initialAmount;
  final String? initialItemDescription;

  @override
  ConsumerState<AffordabilityScreen> createState() => _AffordabilityScreenState();
}

class _AffordabilityScreenState extends ConsumerState<AffordabilityScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount != null && widget.initialAmount! > 0
          ? widget.initialAmount!.toStringAsFixed(0)
          : '',
    );
    _descriptionController = TextEditingController(text: widget.initialItemDescription ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _tryAnotherAmount() {
    setState(() {
      _amountController.clear();
      _descriptionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeToSpend = ref.watch(safeToSpendProvider);
    final planning = ref.watch(financialPlanningProvider);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    final result = amount > 0
        ? AffordabilityCalculator.calculate(
            AffordabilityInput(
              purchaseAmount: amount,
              safeToSpend: safeToSpend,
              planning: planning,
              itemDescription:
                  _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            ),
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Can I Afford This?'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Purchase amount',
                        filled: true,
                        fillColor: AppColors.inputBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'What is it? (optional)',
                        filled: true,
                        fillColor: AppColors.inputBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (result == null)
                Text(
                  'Enter a purchase amount above to see the analysis.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                )
              else
                _AffordabilityAnalysis(result: result),
              const SizedBox(height: 20),
              if (result != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(onPressed: _tryAnotherAmount, child: const Text('Try another amount')),
                ),
              // CONSUMER MONETIZATION FOUNDATION (PHASE 7) — basic
              // affordability analysis above is fully available for free;
              // this is purely an additive discovery card for free users,
              // never a gate on the analysis itself.
              if (result != null && !canAccessEntitlement(ref, Entitlement.financialPlanning)) ...[
                const SizedBox(height: 16),
                const PremiumDiscoveryBanner(
                  title: 'See the full impact on your financial plan',
                  subtitle: 'Advanced affordability analysis is part of PaySense Plus.',
                  ctaLabel: 'Plus',
                  analyticsContext: 'affordability_advanced',
                ),
              ],
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This is a simulation only — nothing is purchased, saved, or changed in your accounts.',
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
        ),
      ),
    );
  }
}

class _AffordabilityAnalysis extends StatelessWidget {
  const _AffordabilityAnalysis({required this.result});

  final AffordabilityResult result;

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
    final (statusLabel, statusColor, statusIcon) = _statusVisuals(result.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                result.recommendation,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _row(context, 'Available cash after purchase', _money.format(result.availableAfterPurchase)),
              _row(context, 'Emergency-fund impact', _money.format(result.emergencyFundImpact)),
              _row(context, 'Goal impact (₹)', _money.format(result.goalImpact)),
              if (result.estimatedGoalDelayMonths != null)
                _row(
                  context,
                  'Estimated goal delay',
                  '${result.estimatedGoalDelayMonths} month${result.estimatedGoalDelayMonths == 1 ? '' : 's'}',
                ),
              _row(context, 'Monthly cash-flow impact', _money.format(result.cashFlowImpact)),
              _row(context, 'Confidence', '${(result.confidence * 100).round()}%'),
            ],
          ),
        ),
        if (result.reasons.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Reasons',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ...result.reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $reason',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Warnings',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ...result.warnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $warning',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
