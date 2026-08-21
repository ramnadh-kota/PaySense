import 'package:flutter/foundation.dart';

/// INDIA TAX PLANNER 1.0 — pure, deterministic tax arithmetic for
/// FY 2026-27 (AY 2027-28), verified from official/government sources
/// (Income Tax Department, PIB Union Budget 2026-27 summary — see
/// ai_backend/README.md or the milestone report for citations). No
/// Flutter widget dependency, no Riverpod, no Hive, no AI/network calls —
/// this is the ONLY place in PaySense that performs tax arithmetic. The UI,
/// the AI backend, and every other layer only ever display or explain a
/// [TaxCalculationResult] this class already produced.
///
/// SCOPE (see the milestone final report for the full list of what was
/// verified vs. what was deliberately left out):
/// - Resident individuals only (no NRI/HUF/company rules).
/// - Old regime deductions supported: Section 80C-equivalent (₹1,50,000
///   cap), Section 80D-equivalent (₹25,000 / ₹50,000 senior-citizen cap,
///   self only — no separate parents' cap), home-loan interest on a
///   self-occupied property (₹2,00,000 cap), a manually-entered HRA
///   exemption (PaySense does not compute HRA itself — see
///   PHASE 2/PHASE 19), and a manually-entered "other eligible deductions"
///   catch-all.
/// - New regime: only the statutory standard deduction applies — no
///   Chapter VI-A-equivalent deductions, matching how the new regime has
///   always worked.
/// - Surcharge tiers are applied WITHOUT marginal relief at the surcharge
///   thresholds (₹50L/₹1Cr/₹2Cr/₹5Cr) — a documented limitation, not a
///   guess (see the final report). Section 87A rebate marginal relief
///   (the ₹12L/₹5L cliff) IS implemented, since that is the case the
///   overwhelming majority of PaySense users will actually hit.
/// - The Income-tax Act, 2025 (in force from 1 April 2026, i.e. for this
///   exact FY) renumbers many sections (e.g. 80C-equivalent relief is
///   reported to now sit under a different section number). PaySense could
///   not verify the new section numbers from a primary government text
///   within this milestone, so deduction fields are labelled by their
///   long-established common names ("80C", "80D") rather than an unverified
///   new section number — the LIMIT AMOUNTS themselves were verified as
///   unchanged for FY 2026-27.
class TaxRates {
  TaxRates._();

  /// New regime standard deduction (verified — unchanged from FY 2025-26).
  static const double newRegimeStandardDeduction = 75000;

  /// Old regime standard deduction (verified — unchanged, salaried/pension
  /// income only; PaySense does not distinguish income sources, so this is
  /// applied uniformly, matching the new regime's own uniform application).
  static const double oldRegimeStandardDeduction = 50000;

  static const double section80CCap = 150000;
  static const double section80DCapBelow60 = 25000;
  static const double section80DCapSeniorCitizen = 50000;
  static const double homeLoanInterestCap = 200000;

  /// Section 87A rebate thresholds (taxable income at/below which tax is
  /// fully rebated) — verified from the Income Tax Department.
  static const double newRegimeRebateThreshold = 1200000;
  static const double oldRegimeRebateThreshold = 500000;

  static const double cessRate = 0.04;

  /// New regime slabs — identical across all ages (verified).
  static const List<_Bracket> _newRegimeSlabs = [
    _Bracket(0, 400000, 0.0),
    _Bracket(400000, 800000, 0.05),
    _Bracket(800000, 1200000, 0.10),
    _Bracket(1200000, 1600000, 0.15),
    _Bracket(1600000, 2000000, 0.20),
    _Bracket(2000000, 2400000, 0.25),
    _Bracket(2400000, null, 0.30),
  ];

  static const List<_Bracket> _oldRegimeSlabsBelow60 = [
    _Bracket(0, 250000, 0.0),
    _Bracket(250000, 500000, 0.05),
    _Bracket(500000, 1000000, 0.20),
    _Bracket(1000000, null, 0.30),
  ];

  static const List<_Bracket> _oldRegimeSlabsSenior60to79 = [
    _Bracket(0, 300000, 0.0),
    _Bracket(300000, 500000, 0.05),
    _Bracket(500000, 1000000, 0.20),
    _Bracket(1000000, null, 0.30),
  ];

  static const List<_Bracket> _oldRegimeSlabsSuperSenior80Plus = [
    _Bracket(0, 500000, 0.0),
    _Bracket(500000, 1000000, 0.20),
    _Bracket(1000000, null, 0.30),
  ];

  /// (threshold, rate) pairs, ascending — the highest-income surcharge rate
  /// under the OLD regime is 37% above ₹5Cr; the NEW regime caps surcharge
  /// at 25% even above ₹5Cr (verified).
  static const List<_SurchargeTier> _surchargeTiersNewRegime = [
    _SurchargeTier(5000000, 0.10),
    _SurchargeTier(10000000, 0.15),
    _SurchargeTier(20000000, 0.25),
  ];

  static const List<_SurchargeTier> _surchargeTiersOldRegime = [
    _SurchargeTier(5000000, 0.10),
    _SurchargeTier(10000000, 0.15),
    _SurchargeTier(20000000, 0.25),
    _SurchargeTier(50000000, 0.37),
  ];
}

class _Bracket {
  const _Bracket(this.from, this.to, this.rate);
  final double from;
  final double? to; // null = no upper bound
  final double rate;
}

class _SurchargeTier {
  const _SurchargeTier(this.threshold, this.rate);
  final double threshold;
  final double rate;
}

enum TaxRegime { old, newRegime }

enum TaxAgeBand {
  below60,
  seniorCitizen60to79,
  superSenior80Plus;

  String get label {
    switch (this) {
      case TaxAgeBand.below60:
        return 'Below 60';
      case TaxAgeBand.seniorCitizen60to79:
        return 'Senior citizen (60-79)';
      case TaxAgeBand.superSenior80Plus:
        return 'Super senior citizen (80+)';
    }
  }
}

/// PHASE 2 — the deterministic tax profile. Every deduction field defaults
/// to 0 (never fabricated) and must be explicitly entered by the user;
/// [isIncomeEstimated] records whether [annualGrossIncome] came from
/// PaySense's own income-transaction estimate or was manually confirmed/
/// overridden by the user (PHASE 3) — this class never silently prefers one
/// over the other, it just records which one is currently in effect.
@immutable
class TaxProfile {
  const TaxProfile({
    required this.annualGrossIncome,
    this.otherIncome = 0,
    this.regime = TaxRegime.newRegime,
    this.ageBand = TaxAgeBand.below60,
    this.section80C = 0,
    this.section80D = 0,
    this.homeLoanInterest = 0,
    this.hraExemption = 0,
    this.otherEligibleDeductions = 0,
    this.tdsAlreadyDeducted = 0,
    this.isIncomeEstimated = false,
  });

  final double annualGrossIncome;
  final double otherIncome;
  final TaxRegime regime;
  final TaxAgeBand ageBand;
  final double section80C;
  final double section80D;
  final double homeLoanInterest;
  final double hraExemption;
  final double otherEligibleDeductions;
  final double tdsAlreadyDeducted;

  /// True when [annualGrossIncome] currently reflects PaySense's own
  /// income-history estimate (PHASE 3) rather than a value the user typed
  /// in and confirmed as their actual annual income.
  final bool isIncomeEstimated;

  TaxProfile copyWith({
    double? annualGrossIncome,
    double? otherIncome,
    TaxRegime? regime,
    TaxAgeBand? ageBand,
    double? section80C,
    double? section80D,
    double? homeLoanInterest,
    double? hraExemption,
    double? otherEligibleDeductions,
    double? tdsAlreadyDeducted,
    bool? isIncomeEstimated,
  }) {
    return TaxProfile(
      annualGrossIncome: annualGrossIncome ?? this.annualGrossIncome,
      otherIncome: otherIncome ?? this.otherIncome,
      regime: regime ?? this.regime,
      ageBand: ageBand ?? this.ageBand,
      section80C: section80C ?? this.section80C,
      section80D: section80D ?? this.section80D,
      homeLoanInterest: homeLoanInterest ?? this.homeLoanInterest,
      hraExemption: hraExemption ?? this.hraExemption,
      otherEligibleDeductions: otherEligibleDeductions ?? this.otherEligibleDeductions,
      tdsAlreadyDeducted: tdsAlreadyDeducted ?? this.tdsAlreadyDeducted,
      isIncomeEstimated: isIncomeEstimated ?? this.isIncomeEstimated,
    );
  }
}

/// PHASE 5 — every numeric field here is guaranteed finite and
/// non-negative (see [TaxCalculator._safe]) — never NaN, never Infinity,
/// never a negative taxable income or negative tax.
@immutable
class TaxCalculationResult {
  const TaxCalculationResult({
    required this.regime,
    required this.grossIncome,
    required this.standardDeduction,
    required this.totalDeductions,
    required this.taxableIncome,
    required this.taxBeforeRebate,
    required this.rebate,
    required this.taxAfterRebate,
    required this.surcharge,
    required this.cess,
    required this.estimatedTax,
    required this.effectiveTaxRatePercent,
    required this.tdsAlreadyDeducted,
    required this.remainingTax,
    required this.excessTds,
    required this.monthlyTaxProvision,
    required this.remainingMonthsInFinancialYear,
    required this.financialYearLabel,
  });

  final TaxRegime regime;
  final double grossIncome;
  final double standardDeduction;

  /// Sum of every Chapter-VI-A-equivalent deduction actually applied (0 for
  /// the new regime, which does not allow them).
  final double totalDeductions;

  final double taxableIncome;
  final double taxBeforeRebate;
  final double rebate;
  final double taxAfterRebate;
  final double surcharge;
  final double cess;

  /// taxAfterRebate + surcharge + cess.
  final double estimatedTax;

  final double effectiveTaxRatePercent;

  final double tdsAlreadyDeducted;

  /// max(0, estimatedTax - tdsAlreadyDeducted).
  final double remainingTax;

  /// max(0, tdsAlreadyDeducted - estimatedTax) — an ESTIMATE of excess TDS,
  /// never described as a guaranteed refund (PHASE 8).
  final double excessTds;

  /// remainingTax ÷ remainingMonthsInFinancialYear — PHASE 9. Never a blind
  /// ÷12.
  final double monthlyTaxProvision;
  final int remainingMonthsInFinancialYear;

  final String financialYearLabel;
}

@immutable
class TaxRegimeComparisonResult {
  const TaxRegimeComparisonResult({required this.oldRegime, required this.newRegime});

  final TaxCalculationResult oldRegime;
  final TaxCalculationResult newRegime;

  /// oldRegime.estimatedTax - newRegime.estimatedTax — positive means the
  /// new regime is cheaper, negative means the old regime is cheaper. The
  /// UI/AI must present this neutrally (PHASE 6) — this class never states
  /// a recommendation, only the figures.
  double get difference => oldRegime.estimatedTax - newRegime.estimatedTax;

  TaxRegime get lowerTaxRegime =>
      newRegime.estimatedTax <= oldRegime.estimatedTax ? TaxRegime.newRegime : TaxRegime.old;
}

/// PHASE 4 — the sole owner of tax arithmetic in PaySense.
class TaxCalculator {
  TaxCalculator._();

  static double _safe(double value) {
    if (value.isNaN || value.isInfinite) return 0;
    return value < 0 ? 0 : value;
  }

  static double _slabTax(double taxableIncome, List<_Bracket> brackets) {
    var tax = 0.0;
    for (final bracket in brackets) {
      if (taxableIncome <= bracket.from) break;
      final upper = bracket.to == null ? taxableIncome : (taxableIncome < bracket.to! ? taxableIncome : bracket.to!);
      final span = upper - bracket.from;
      if (span > 0) tax += span * bracket.rate;
    }
    return _safe(tax);
  }

  static List<_Bracket> _oldRegimeSlabs(TaxAgeBand ageBand) {
    switch (ageBand) {
      case TaxAgeBand.below60:
        return TaxRates._oldRegimeSlabsBelow60;
      case TaxAgeBand.seniorCitizen60to79:
        return TaxRates._oldRegimeSlabsSenior60to79;
      case TaxAgeBand.superSenior80Plus:
        return TaxRates._oldRegimeSlabsSuperSenior80Plus;
    }
  }

  /// Section 87A rebate + its marginal relief, in one step: at/below
  /// [threshold] tax is fully rebated; just above it, tax is capped at the
  /// income exceeding the threshold (never more tax than the excess income
  /// itself) — the standard statutory formula, which self-phases-out once
  /// normal slab tax naturally exceeds the excess.
  static double _applyRebateWithMarginalRelief({
    required double taxableIncome,
    required double taxBeforeRebate,
    required double threshold,
  }) {
    if (taxableIncome <= threshold) return 0;
    final excess = taxableIncome - threshold;
    return _safe(taxBeforeRebate < excess ? taxBeforeRebate : excess);
  }

  static double _surcharge({
    required double taxableIncome,
    required double taxAfterRebate,
    required TaxRegime regime,
  }) {
    final tiers = regime == TaxRegime.newRegime
        ? TaxRates._surchargeTiersNewRegime
        : TaxRates._surchargeTiersOldRegime;

    var rate = 0.0;
    for (final tier in tiers) {
      if (taxableIncome > tier.threshold) rate = tier.rate;
    }
    // Marginal relief at surcharge thresholds is NOT implemented — see the
    // class-level doc comment. This never understates tax, only
    // (rarely, for incomes just above a surcharge threshold) slightly
    // overstates it relative to the full statutory relief.
    return _safe(taxAfterRebate * rate);
  }

  /// FY runs 1 Apr - 31 Mar. Returns the FY label ("2026-27") and the
  /// number of months remaining, INCLUDING the current month, for [now].
  static (String label, int remainingMonths) financialYearInfo(DateTime now) {
    final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
    final label = '$fyStartYear-${(fyStartYear + 1).toString().substring(2)}';
    // Months from `now`'s month to March inclusive (Apr-Dec this calendar
    // year, then Jan-Mar of the next).
    final remaining = now.month >= 4 ? (12 - now.month + 1) + 3 : (3 - now.month + 1);
    return (label, remaining.clamp(1, 12));
  }

  static TaxCalculationResult calculate({required TaxProfile profile, DateTime? now}) {
    final referenceNow = now ?? DateTime.now();
    final (fyLabel, remainingMonths) = financialYearInfo(referenceNow);

    final grossIncome = _safe(profile.annualGrossIncome) + _safe(profile.otherIncome);
    final standardDeduction = (profile.regime == TaxRegime.newRegime
            ? TaxRates.newRegimeStandardDeduction
            : TaxRates.oldRegimeStandardDeduction)
        .clamp(0.0, grossIncome);

    double totalDeductions = 0;
    if (profile.regime == TaxRegime.old) {
      final section80D = profile.ageBand == TaxAgeBand.below60
          ? TaxRates.section80DCapBelow60
          : TaxRates.section80DCapSeniorCitizen;
      totalDeductions = _safe(profile.section80C).clamp(0.0, TaxRates.section80CCap) +
          _safe(profile.section80D).clamp(0.0, section80D) +
          _safe(profile.homeLoanInterest).clamp(0.0, TaxRates.homeLoanInterestCap) +
          _safe(profile.hraExemption) +
          _safe(profile.otherEligibleDeductions);
    }

    final incomeAfterStandardDeduction = (grossIncome - standardDeduction).clamp(0.0, double.infinity);
    final taxableIncome = _safe(incomeAfterStandardDeduction - totalDeductions);

    final brackets =
        profile.regime == TaxRegime.newRegime ? TaxRates._newRegimeSlabs : _oldRegimeSlabs(profile.ageBand);
    final taxBeforeRebate = _slabTax(taxableIncome, brackets);

    final rebateThreshold = profile.regime == TaxRegime.newRegime
        ? TaxRates.newRegimeRebateThreshold
        : TaxRates.oldRegimeRebateThreshold;
    final taxAfterRebate = _applyRebateWithMarginalRelief(
      taxableIncome: taxableIncome,
      taxBeforeRebate: taxBeforeRebate,
      threshold: rebateThreshold,
    );
    final rebate = _safe(taxBeforeRebate - taxAfterRebate);

    final surcharge = _surcharge(
      taxableIncome: taxableIncome,
      taxAfterRebate: taxAfterRebate,
      regime: profile.regime,
    );
    final cess = _safe((taxAfterRebate + surcharge) * TaxRates.cessRate);
    final estimatedTax = _safe(taxAfterRebate + surcharge + cess);

    final effectiveRate = grossIncome > 0 ? _safe(estimatedTax / grossIncome * 100) : 0.0;

    final tds = _safe(profile.tdsAlreadyDeducted);
    final remainingTax = _safe(estimatedTax - tds);
    final excessTds = _safe(tds - estimatedTax);
    final monthlyProvision = _safe(remainingTax / remainingMonths);

    return TaxCalculationResult(
      regime: profile.regime,
      grossIncome: grossIncome,
      standardDeduction: standardDeduction,
      totalDeductions: totalDeductions,
      taxableIncome: taxableIncome,
      taxBeforeRebate: taxBeforeRebate,
      rebate: rebate,
      taxAfterRebate: taxAfterRebate,
      surcharge: surcharge,
      cess: cess,
      estimatedTax: estimatedTax,
      effectiveTaxRatePercent: effectiveRate,
      tdsAlreadyDeducted: tds,
      remainingTax: remainingTax,
      excessTds: excessTds,
      monthlyTaxProvision: monthlyProvision,
      remainingMonthsInFinancialYear: remainingMonths,
      financialYearLabel: fyLabel,
    );
  }

  /// PHASE 6 — deterministic old-vs-new comparison, same profile computed
  /// under both regimes.
  static TaxRegimeComparisonResult compareRegimes({required TaxProfile profile, DateTime? now}) {
    return TaxRegimeComparisonResult(
      oldRegime: calculate(profile: profile.copyWith(regime: TaxRegime.old), now: now),
      newRegime: calculate(profile: profile.copyWith(regime: TaxRegime.newRegime), now: now),
    );
  }
}
