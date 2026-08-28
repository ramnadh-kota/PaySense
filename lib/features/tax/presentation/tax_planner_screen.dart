import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/constants/disclaimers.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/entitlement.dart';
import 'package:paysense/shared/providers/entitlement_provider.dart';
import 'package:paysense/shared/providers/tax_provider.dart';
import 'package:paysense/shared/utils/tax_calculator.dart';
import 'package:paysense/shared/utils/tax_income_estimator.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'package:paysense/shared/widgets/premium_discovery_banner.dart';

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// PHASE 13 — the Tax Planner screen. Every figure shown is either a raw
/// user input or [TaxCalculator]'s output — this screen never computes tax
/// itself. Reachable from Financial Planning and the AI screen (PHASE 13
/// deliberately does not add another bottom-nav Quick Action).
class TaxPlannerScreen extends ConsumerStatefulWidget {
  const TaxPlannerScreen({super.key});

  @override
  ConsumerState<TaxPlannerScreen> createState() => _TaxPlannerScreenState();
}

class _TaxPlannerScreenState extends ConsumerState<TaxPlannerScreen> {
  final _annualIncomeController = TextEditingController();
  final _otherIncomeController = TextEditingController();
  final _section80CController = TextEditingController();
  final _section80DController = TextEditingController();
  final _homeLoanInterestController = TextEditingController();
  final _hraExemptionController = TextEditingController();
  final _otherDeductionsController = TextEditingController();
  final _tdsController = TextEditingController();

  TaxRegime _regime = TaxRegime.newRegime;
  TaxAgeBand _ageBand = TaxAgeBand.below60;
  bool _isIncomeEstimated = false;
  bool _initialized = false;
  String? _validationError;

  @override
  void dispose() {
    _annualIncomeController.dispose();
    _otherIncomeController.dispose();
    _section80CController.dispose();
    _section80DController.dispose();
    _homeLoanInterestController.dispose();
    _hraExemptionController.dispose();
    _otherDeductionsController.dispose();
    _tdsController.dispose();
    super.dispose();
  }

  void _hydrateFrom(TaxProfile profile) {
    _annualIncomeController.text = profile.annualGrossIncome > 0 ? profile.annualGrossIncome.toStringAsFixed(0) : '';
    _otherIncomeController.text = profile.otherIncome > 0 ? profile.otherIncome.toStringAsFixed(0) : '';
    _section80CController.text = profile.section80C > 0 ? profile.section80C.toStringAsFixed(0) : '';
    _section80DController.text = profile.section80D > 0 ? profile.section80D.toStringAsFixed(0) : '';
    _homeLoanInterestController.text =
        profile.homeLoanInterest > 0 ? profile.homeLoanInterest.toStringAsFixed(0) : '';
    _hraExemptionController.text = profile.hraExemption > 0 ? profile.hraExemption.toStringAsFixed(0) : '';
    _otherDeductionsController.text =
        profile.otherEligibleDeductions > 0 ? profile.otherEligibleDeductions.toStringAsFixed(0) : '';
    _tdsController.text = profile.tdsAlreadyDeducted > 0 ? profile.tdsAlreadyDeducted.toStringAsFixed(0) : '';
    _regime = profile.regime;
    _ageBand = profile.ageBand;
    _isIncomeEstimated = profile.isIncomeEstimated;
  }

  void _useEstimate(IncomeEstimate estimate) {
    setState(() {
      _annualIncomeController.text = estimate.estimatedAnnualIncome.toStringAsFixed(0);
      _isIncomeEstimated = true;
      _validationError = null;
    });
  }

  /// Parses a currency-ish text field. Returns null (and sets
  /// [_validationError]) for anything negative or unparsable — PHASE 7:
  /// invalid deduction input is rejected, never silently accepted.
  double? _parseNonNegative(String label, String text) {
    if (text.trim().isEmpty) return 0;
    final value = double.tryParse(text.trim());
    if (value == null || value < 0) {
      _validationError = '$label must be a valid, non-negative amount.';
      return null;
    }
    return value;
  }

  Future<void> _save() async {
    setState(() => _validationError = null);

    final annualIncome = _parseNonNegative('Annual income', _annualIncomeController.text);
    final otherIncome = _parseNonNegative('Other income', _otherIncomeController.text);
    final section80C = _parseNonNegative('Section 80C', _section80CController.text);
    final section80D = _parseNonNegative('Section 80D', _section80DController.text);
    final homeLoanInterest = _parseNonNegative('Home loan interest', _homeLoanInterestController.text);
    final hraExemption = _parseNonNegative('HRA exemption', _hraExemptionController.text);
    final otherDeductions = _parseNonNegative('Other deductions', _otherDeductionsController.text);
    final tds = _parseNonNegative('TDS already deducted', _tdsController.text);

    if ([annualIncome, otherIncome, section80C, section80D, homeLoanInterest, hraExemption, otherDeductions, tds]
        .any((v) => v == null)) {
      setState(() {});
      return;
    }

    final profile = TaxProfile(
      annualGrossIncome: annualIncome!,
      otherIncome: otherIncome!,
      regime: _regime,
      ageBand: _ageBand,
      section80C: section80C!,
      section80D: section80D!,
      homeLoanInterest: homeLoanInterest!,
      hraExemption: hraExemption!,
      otherEligibleDeductions: otherDeductions!,
      tdsAlreadyDeducted: tds!,
      isIncomeEstimated: _isIncomeEstimated,
    );

    await ref.read(taxProfileProvider.notifier).save(profile);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tax profile saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(taxProfileProvider);
    final estimate = ref.watch(taxIncomeEstimateProvider);

    if (!_initialized && profileAsync.hasValue) {
      final saved = profileAsync.value;
      if (saved != null) {
        _hydrateFrom(saved);
      } else if (estimate.hasIncomeData) {
        _annualIncomeController.text = estimate.estimatedAnnualIncome.toStringAsFixed(0);
        _isIncomeEstimated = true;
      }
      _initialized = true;
    }

    final annualIncome = double.tryParse(_annualIncomeController.text) ?? 0;
    final otherIncome = double.tryParse(_otherIncomeController.text) ?? 0;
    final previewProfile = TaxProfile(
      annualGrossIncome: annualIncome,
      otherIncome: otherIncome,
      regime: _regime,
      ageBand: _ageBand,
      section80C: double.tryParse(_section80CController.text) ?? 0,
      section80D: double.tryParse(_section80DController.text) ?? 0,
      homeLoanInterest: double.tryParse(_homeLoanInterestController.text) ?? 0,
      hraExemption: double.tryParse(_hraExemptionController.text) ?? 0,
      otherEligibleDeductions: double.tryParse(_otherDeductionsController.text) ?? 0,
      tdsAlreadyDeducted: double.tryParse(_tdsController.text) ?? 0,
      isIncomeEstimated: _isIncomeEstimated,
    );
    final hasIncome = previewProfile.annualGrossIncome > 0;
    final result = hasIncome ? TaxCalculator.calculate(profile: previewProfile) : null;
    final comparison = hasIncome ? TaxCalculator.compareRegimes(profile: previewProfile) : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Tax Planner'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CONSUMER MONETIZATION FOUNDATION (PHASE 7) — purely
              // additive; the calculator below remains fully usable
              // regardless of tier, letting the user understand the
              // feature before deciding to upgrade.
              if (!canAccessEntitlement(ref, Entitlement.taxPlanner)) ...[
                const PremiumDiscoveryBanner(
                  title: 'Unlock your personalized tax planning',
                  subtitle: 'Save this scenario and get proactive tax-saving reminders with PaySense Plus.',
                  ctaLabel: 'Plus',
                  analyticsContext: 'tax_planner',
                ),
                const SizedBox(height: 18),
              ],
              _SectionTitle('Income'),
              const SizedBox(height: 8),
              _IncomeSection(
                estimate: estimate,
                annualIncomeController: _annualIncomeController,
                otherIncomeController: _otherIncomeController,
                isIncomeEstimated: _isIncomeEstimated,
                onUseEstimate: estimate.hasIncomeData ? () => _useEstimate(estimate) : null,
                onIncomeEdited: () => setState(() => _isIncomeEstimated = false),
              ),
              const SizedBox(height: 18),
              _SectionTitle('Tax Regime'),
              const SizedBox(height: 8),
              _RegimeSection(
                regime: _regime,
                ageBand: _ageBand,
                onRegimeChanged: (r) => setState(() => _regime = r),
                onAgeBandChanged: (a) => setState(() => _ageBand = a),
              ),
              const SizedBox(height: 18),
              _SectionTitle('Deductions'),
              const SizedBox(height: 4),
              Text(
                _regime == TaxRegime.newRegime
                    ? 'Deductions below apply only under the Old Regime — the New Regime uses the standard deduction only.'
                    : 'Enter a deduction only if you are eligible for it.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              _DeductionsSection(
                enabled: _regime == TaxRegime.old,
                section80CController: _section80CController,
                section80DController: _section80DController,
                homeLoanInterestController: _homeLoanInterestController,
                hraExemptionController: _hraExemptionController,
                otherDeductionsController: _otherDeductionsController,
              ),
              const SizedBox(height: 18),
              _SectionTitle('TDS'),
              const SizedBox(height: 8),
              _NumberField(label: 'TDS already deducted', controller: _tdsController),
              const SizedBox(height: 20),
              if (_validationError != null) ...[
                Text(
                  _validationError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _save, child: const Text('Save Tax Profile')),
              ),
              const SizedBox(height: 24),
              if (!hasIncome)
                _EmptyResultBanner(hasIncomeData: estimate.hasIncomeData)
              else ...[
                _SectionTitle('Estimated Tax'),
                const SizedBox(height: 8),
                _EstimatedTaxCard(result: result!),
                const SizedBox(height: 18),
                _SectionTitle('Old vs New'),
                const SizedBox(height: 8),
                _RegimeComparisonCard(comparison: comparison!),
                const SizedBox(height: 18),
                _SectionTitle('Monthly Provision'),
                const SizedBox(height: 8),
                _MonthlyProvisionCard(result: result),
              ],
              const SizedBox(height: 18),
              _SectionTitle('Tax What-If'),
              const SizedBox(height: 8),
              const _TaxWhatIfSection(),
              const SizedBox(height: 20),
              _Disclaimer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller, this.onChanged, this.enabled = true});

  final String label;
  final TextEditingController controller;
  final VoidCallback? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged?.call(),
      style: TextStyle(color: enabled ? AppColors.textPrimary : AppColors.disabledText),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _IncomeSection extends StatelessWidget {
  const _IncomeSection({
    required this.estimate,
    required this.annualIncomeController,
    required this.otherIncomeController,
    required this.isIncomeEstimated,
    required this.onUseEstimate,
    required this.onIncomeEdited,
  });

  final IncomeEstimate estimate;
  final TextEditingController annualIncomeController;
  final TextEditingController otherIncomeController;
  final bool isIncomeEstimated;
  final VoidCallback? onUseEstimate;
  final VoidCallback onIncomeEdited;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (estimate.hasIncomeData) ...[
            Text(
              'Estimated from PaySense income history (${estimate.estimationPeriodLabel}): '
              '${_money.format(estimate.estimatedAnnualIncome)}/year',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            if (estimate.isIrregular)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Your income history has gaps — this estimate may be unreliable.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(onPressed: onUseEstimate, child: const Text('Use my PaySense estimate')),
            const SizedBox(height: 4),
          ],
          _NumberField(label: 'Your actual annual income', controller: annualIncomeController, onChanged: onIncomeEdited),
          if (isIncomeEstimated)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Currently using the PaySense estimate — edit the field above to enter your actual income.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 10),
          _NumberField(label: 'Other income (optional)', controller: otherIncomeController),
        ],
      ),
    );
  }
}

class _RegimeSection extends StatelessWidget {
  const _RegimeSection({
    required this.regime,
    required this.ageBand,
    required this.onRegimeChanged,
    required this.onAgeBandChanged,
  });

  final TaxRegime regime;
  final TaxAgeBand ageBand;
  final ValueChanged<TaxRegime> onRegimeChanged;
  final ValueChanged<TaxAgeBand> onAgeBandChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<TaxRegime>(
            segments: const [
              ButtonSegment(value: TaxRegime.newRegime, label: Text('New Regime')),
              ButtonSegment(value: TaxRegime.old, label: Text('Old Regime')),
            ],
            selected: {regime},
            onSelectionChanged: (selection) => onRegimeChanged(selection.first),
          ),
          if (regime == TaxRegime.old) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<TaxAgeBand>(
              initialValue: ageBand,
              decoration: InputDecoration(
                labelText: 'Age',
                filled: true,
                fillColor: AppColors.inputBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              items: TaxAgeBand.values
                  .map((band) => DropdownMenuItem(value: band, child: Text(band.label)))
                  .toList(),
              onChanged: (band) {
                if (band != null) onAgeBandChanged(band);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DeductionsSection extends StatelessWidget {
  const _DeductionsSection({
    required this.enabled,
    required this.section80CController,
    required this.section80DController,
    required this.homeLoanInterestController,
    required this.hraExemptionController,
    required this.otherDeductionsController,
  });

  final bool enabled;
  final TextEditingController section80CController;
  final TextEditingController section80DController;
  final TextEditingController homeLoanInterestController;
  final TextEditingController hraExemptionController;
  final TextEditingController otherDeductionsController;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _NumberField(label: '80C (up to ₹1,50,000)', controller: section80CController, enabled: enabled),
          const SizedBox(height: 10),
          _NumberField(label: '80D health insurance (up to ₹25,000 / ₹50,000 senior)', controller: section80DController, enabled: enabled),
          const SizedBox(height: 10),
          _NumberField(label: 'Home loan interest (up to ₹2,00,000)', controller: homeLoanInterestController, enabled: enabled),
          const SizedBox(height: 10),
          _NumberField(label: 'HRA exemption (already calculated)', controller: hraExemptionController, enabled: enabled),
          const SizedBox(height: 10),
          _NumberField(label: 'Other eligible deductions', controller: otherDeductionsController, enabled: enabled),
        ],
      ),
    );
  }
}

class _EstimatedTaxCard extends StatelessWidget {
  const _EstimatedTaxCard({required this.result});
  final TaxCalculationResult result;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, 'Taxable income', _money.format(result.taxableIncome)),
          _row(context, 'Estimated tax (FY ${result.financialYearLabel})', _money.format(result.estimatedTax)),
          _row(context, 'Effective tax rate', '${result.effectiveTaxRatePercent.toStringAsFixed(1)}%'),
          const Divider(height: 20),
          _row(
            context,
            result.remainingTax > 0 ? 'Remaining tax after TDS' : 'Estimated excess TDS',
            _money.format(result.remainingTax > 0 ? result.remainingTax : result.excessTds),
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool highlight = false}) {
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
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegimeComparisonCard extends StatelessWidget {
  const _RegimeComparisonCard({required this.comparison});
  final TaxRegimeComparisonResult comparison;

  @override
  Widget build(BuildContext context) {
    final diff = comparison.difference.abs();
    final lowerLabel = comparison.lowerTaxRegime == TaxRegime.newRegime ? 'New Regime' : 'Old Regime';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _regimeColumn(context, 'NEW REGIME', comparison.newRegime)),
              const SizedBox(width: 12),
              Expanded(child: _regimeColumn(context, 'OLD REGIME', comparison.oldRegime)),
            ],
          ),
          const Divider(height: 24),
          Text(
            diff == 0
                ? 'Based on the information entered, both regimes produce the same estimated tax.'
                : 'Based on the information entered, the estimated tax is lower under the $lowerLabel by ${_money.format(diff)}.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _regimeColumn(BuildContext context, String title, TaxCalculationResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _money.format(result.estimatedTax),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MonthlyProvisionCard extends StatelessWidget {
  const _MonthlyProvisionCard({required this.result});
  final TaxCalculationResult result;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.lightTeal, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.calendar_month_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggested monthly tax provision',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  '${_money.format(result.monthlyTaxProvision)}/month',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Over the remaining ${result.remainingMonthsInFinancialYear} month'
                  '${result.remainingMonthsInFinancialYear == 1 ? '' : 's'} of FY ${result.financialYearLabel} — an estimate.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxWhatIfSection extends StatelessWidget {
  const _TaxWhatIfSection();

  static const _examples = [
    'What if my salary becomes ₹15 lakh?',
    'What if I invest ₹1.5 lakh under 80C?',
    'What if I claim ₹50,000 under 80D?',
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ask the AI Assistant a what-if question — it uses the same tax calculator as this screen.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _examples
                .map(
                  (example) => ActionChip(
                    label: Text(example, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.lightTeal,
                    onPressed: () => Navigator.of(context).pushNamed(AppRoutes.aiCoach),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _EmptyResultBanner extends StatelessWidget {
  const _EmptyResultBanner({required this.hasIncomeData});
  final bool hasIncomeData;

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
              hasIncomeData
                  ? 'I can estimate your annual income from your recorded income history, or you can enter your actual annual income above.'
                  : 'I need your annual income before I can estimate your tax.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      taxDisclaimer,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
    );
  }
}
