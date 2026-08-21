// Focused tests for TaxCalculator (PHASE 4/5/6/7/8/9) — the sole owner of
// tax arithmetic in PaySense. Every figure verified against the official
// FY 2026-27 / AY 2027-28 rules researched in PHASE 0 (see the milestone
// final report for sources). Synthetic data only.
import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/utils/tax_calculator.dart';

TaxProfile _profile({
  double annualGrossIncome = 0,
  double otherIncome = 0,
  TaxRegime regime = TaxRegime.newRegime,
  TaxAgeBand ageBand = TaxAgeBand.below60,
  double section80C = 0,
  double section80D = 0,
  double homeLoanInterest = 0,
  double hraExemption = 0,
  double otherEligibleDeductions = 0,
  double tdsAlreadyDeducted = 0,
}) {
  return TaxProfile(
    annualGrossIncome: annualGrossIncome,
    otherIncome: otherIncome,
    regime: regime,
    ageBand: ageBand,
    section80C: section80C,
    section80D: section80D,
    homeLoanInterest: homeLoanInterest,
    hraExemption: hraExemption,
    otherEligibleDeductions: otherEligibleDeductions,
    tdsAlreadyDeducted: tdsAlreadyDeducted,
  );
}

void main() {
  final now = DateTime(2026, 8, 20);

  group('6. New regime', () {
    test('taxable income within the nil band pays zero tax', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 400000),
        now: now,
      );
      // 400000 - 75000 standard deduction = 325000 taxable, well under 12L rebate.
      expect(result.estimatedTax, 0);
    });

    test('₹15,00,000 gross income computes the documented example figures', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1500000),
        now: now,
      );
      // Taxable = 1500000 - 75000 = 1425000.
      // Slab tax = 0 + 20000(4-8L) + 40000(8-12L) + 0.15*(1425000-1200000)=33750 => 93750.
      expect(result.taxableIncome, 1425000);
      expect(result.taxBeforeRebate, closeTo(93750, 0.01));
      expect(result.rebate, 0); // above 12L threshold, no rebate
      expect(result.taxAfterRebate, closeTo(93750, 0.01));
      expect(result.cess, closeTo(93750 * 0.04, 0.01));
      expect(result.surcharge, 0); // well under 50L
    });
  });

  group('7. Old regime', () {
    test('a below-60 taxpayer uses the below-60 slabs', () {
      final result = TaxCalculator.calculate(
        profile: _profile(
          annualGrossIncome: 900000,
          regime: TaxRegime.old,
        ),
        now: now,
      );
      // Taxable = 900000 - 50000 standard deduction = 850000.
      // Slab: 0(0-2.5L) + 12500(2.5-5L @5%) + 0.20*(850000-500000)=70000 => 82500.
      expect(result.taxableIncome, 850000);
      expect(result.taxBeforeRebate, closeTo(82500, 0.01));
    });

    test('a senior citizen (60-79) gets the higher nil band', () {
      final result = TaxCalculator.calculate(
        profile: _profile(
          annualGrossIncome: 900000,
          regime: TaxRegime.old,
          ageBand: TaxAgeBand.seniorCitizen60to79,
        ),
        now: now,
      );
      // Taxable = 850000. Slab: 0(0-3L) + 10000(3-5L@5%) + 70000(5-8.5L@20%) = 80000.
      expect(result.taxBeforeRebate, closeTo(80000, 0.01));
    });

    test('a super senior citizen (80+) has no 5% band at all', () {
      final result = TaxCalculator.calculate(
        profile: _profile(
          annualGrossIncome: 900000,
          regime: TaxRegime.old,
          ageBand: TaxAgeBand.superSenior80Plus,
        ),
        now: now,
      );
      // Taxable = 850000. Slab: 0(0-5L) + 0.20*(850000-500000)=70000 => 70000.
      expect(result.taxBeforeRebate, closeTo(70000, 0.01));
    });
  });

  group('8. Every verified slab boundary', () {
    test('new regime: exactly at each slab boundary matches the published cumulative tax', () {
      final cases = {
        400000: 0.0,
        800000: 20000.0,
        1200000: 60000.0, // fully rebated to 0 below, but taxBeforeRebate here
        1600000: 120000.0,
        2000000: 200000.0,
        2400000: 300000.0,
      };
      for (final entry in cases.entries) {
        // Push above the 12L rebate threshold with otherIncome so rebate
        // doesn't zero out the figure we're checking below 12L too.
        final result = TaxCalculator.calculate(
          profile: _profile(annualGrossIncome: entry.key.toDouble() + 75000),
          now: now,
        );
        expect(
          result.taxBeforeRebate,
          closeTo(entry.value, 0.01),
          reason: 'boundary ${entry.key}',
        );
      }
    });

    test('old regime below-60: exactly at each slab boundary matches the published cumulative tax', () {
      final cases = {250000: 0.0, 500000: 12500.0, 1000000: 112500.0};
      for (final entry in cases.entries) {
        final result = TaxCalculator.calculate(
          profile: _profile(
            annualGrossIncome: entry.key.toDouble() + 50000,
            regime: TaxRegime.old,
          ),
          now: now,
        );
        expect(result.taxBeforeRebate, closeTo(entry.value, 0.01), reason: 'boundary ${entry.key}');
      }
    });
  });

  group('9. Zero income', () {
    test('zero gross income never produces a negative or fabricated tax', () {
      final result = TaxCalculator.calculate(profile: _profile(annualGrossIncome: 0), now: now);
      expect(result.estimatedTax, 0);
      expect(result.taxableIncome, 0);
      expect(result.effectiveTaxRatePercent, 0);
    });
  });

  group('10. 80C', () {
    test('80C is clamped at ₹1,50,000 even if a larger value is entered', () {
      final result = TaxCalculator.calculate(
        profile: _profile(
          annualGrossIncome: 2000000,
          regime: TaxRegime.old,
          section80C: 300000, // above the statutory cap
        ),
        now: now,
      );
      expect(result.totalDeductions, greaterThanOrEqualTo(150000));
      // Only 150000 of the 300000 entered should count.
      final withoutExtra = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 2000000, regime: TaxRegime.old, section80C: 150000),
        now: now,
      );
      expect(result.taxableIncome, withoutExtra.taxableIncome);
    });

    test('80C has no effect at all under the new regime', () {
      final withDeduction = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1500000, section80C: 150000),
        now: now,
      );
      final without = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1500000),
        now: now,
      );
      expect(withDeduction.taxableIncome, without.taxableIncome);
    });
  });

  group('11. 80D', () {
    test('below-60 80D is clamped at ₹25,000', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1500000, regime: TaxRegime.old, section80D: 60000),
        now: now,
      );
      final capped = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1500000, regime: TaxRegime.old, section80D: 25000),
        now: now,
      );
      expect(result.taxableIncome, capped.taxableIncome);
    });

    test('a senior citizen gets the higher ₹50,000 80D cap', () {
      final result = TaxCalculator.calculate(
        profile: _profile(
          annualGrossIncome: 1500000, regime: TaxRegime.old,
          ageBand: TaxAgeBand.seniorCitizen60to79, section80D: 50000,
        ),
        now: now,
      );
      final belowCap = TaxCalculator.calculate(
        profile: _profile(
          annualGrossIncome: 1500000, regime: TaxRegime.old,
          ageBand: TaxAgeBand.seniorCitizen60to79, section80D: 25000,
        ),
        now: now,
      );
      expect(result.taxableIncome, lessThan(belowCap.taxableIncome));
    });
  });

  group('12. Home-loan interest', () {
    test('home-loan interest is clamped at ₹2,00,000 under the old regime', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1500000, regime: TaxRegime.old, homeLoanInterest: 500000),
        now: now,
      );
      final capped = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1500000, regime: TaxRegime.old, homeLoanInterest: 200000),
        now: now,
      );
      expect(result.taxableIncome, capped.taxableIncome);
    });
  });

  group('14. Deduction limits', () {
    test('every deduction is applied only under the old regime, never the new one', () {
      final result = TaxCalculator.calculate(
        profile: _profile(
          annualGrossIncome: 1500000,
          section80C: 150000, section80D: 25000, homeLoanInterest: 200000,
          hraExemption: 100000, otherEligibleDeductions: 50000,
        ),
        now: now,
      );
      expect(result.totalDeductions, 0);
    });
  });

  group('15-16. TDS / remaining tax / excess TDS', () {
    test('TDS below the estimated tax leaves a positive remaining tax, zero excess', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1500000, tdsAlreadyDeducted: 50000),
        now: now,
      );
      expect(result.remainingTax, closeTo(result.estimatedTax - 50000, 0.01));
      expect(result.excessTds, 0);
    });

    test('17. TDS above the estimated tax produces an excess, never a negative remaining tax', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 400000, tdsAlreadyDeducted: 100000),
        now: now,
      );
      expect(result.remainingTax, 0);
      expect(result.excessTds, greaterThan(0));
    });
  });

  group('18. Monthly tax provision', () {
    test('divides remaining tax by the actual remaining FY months, not blindly by 12', () {
      // now = Aug 20 2026 -> Aug..Mar inclusive = 8 months remaining.
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1500000),
        now: DateTime(2026, 8, 20),
      );
      expect(result.remainingMonthsInFinancialYear, 8);
      expect(result.monthlyTaxProvision, closeTo(result.remainingTax / 8, 0.01));
    });

    test('April (FY start) has all 12 months remaining', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1500000),
        now: DateTime(2026, 4, 5),
      );
      expect(result.remainingMonthsInFinancialYear, 12);
    });

    test('March (FY end) has exactly 1 month remaining, never zero', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1500000),
        now: DateTime(2027, 3, 25),
      );
      expect(result.remainingMonthsInFinancialYear, 1);
      expect(result.monthlyTaxProvision.isFinite, isTrue);
    });
  });

  group('19. Old vs New comparison', () {
    test('compareRegimes computes both regimes from the same profile and a consistent difference', () {
      final comparison = TaxCalculator.compareRegimes(
        profile: _profile(annualGrossIncome: 1500000, regime: TaxRegime.old, section80C: 150000),
        now: now,
      );
      expect(comparison.oldRegime.regime, TaxRegime.old);
      expect(comparison.newRegime.regime, TaxRegime.newRegime);
      expect(
        comparison.difference,
        closeTo(comparison.oldRegime.estimatedTax - comparison.newRegime.estimatedTax, 0.01),
      );
      expect(
        comparison.lowerTaxRegime,
        comparison.newRegime.estimatedTax <= comparison.oldRegime.estimatedTax
            ? TaxRegime.newRegime
            : TaxRegime.old,
      );
    });
  });

  group('22. Invalid negative input', () {
    test('a negative deduction entry never increases taxable income or produces negative tax', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1500000, regime: TaxRegime.old, section80C: -50000),
        now: now,
      );
      expect(result.totalDeductions, greaterThanOrEqualTo(0));
      expect(result.estimatedTax, greaterThanOrEqualTo(0));
    });

    test('negative TDS never produces a negative remaining tax or fabricated excess', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1500000, tdsAlreadyDeducted: -10000),
        now: now,
      );
      expect(result.remainingTax, greaterThanOrEqualTo(0));
      expect(result.excessTds, 0);
    });
  });

  group('23-24. NaN / Infinity protection', () {
    test('an extreme income never produces NaN or Infinity anywhere in the result', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 999999999999),
        now: now,
      );
      expect(result.estimatedTax.isNaN, isFalse);
      expect(result.estimatedTax.isInfinite, isFalse);
      expect(result.effectiveTaxRatePercent.isNaN, isFalse);
      expect(result.monthlyTaxProvision.isFinite, isTrue);
    });

    test('zero income never divides into NaN for the effective tax rate', () {
      final result = TaxCalculator.calculate(profile: _profile(annualGrossIncome: 0), now: now);
      expect(result.effectiveTaxRatePercent.isNaN, isFalse);
      expect(result.effectiveTaxRatePercent, 0);
    });
  });

  group('25. No negative tax', () {
    test('deductions larger than gross income clamp taxable income and tax to zero, never negative', () {
      final result = TaxCalculator.calculate(
        profile: _profile(
          annualGrossIncome: 100000, regime: TaxRegime.old,
          section80C: 150000, homeLoanInterest: 200000,
        ),
        now: now,
      );
      expect(result.taxableIncome, 0);
      expect(result.estimatedTax, 0);
    });
  });

  group('Section 87A marginal relief (new regime)', () {
    test('a taxable income just ₹1,500 above the ₹12L threshold caps tax at the excess, not the full slab tax', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 1201500 + 75000),
        now: now,
      );
      expect(result.taxAfterRebate, closeTo(1500, 0.01));
    });

    test('a taxable income far above the threshold is unaffected by marginal relief', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 2000000 + 75000),
        now: now,
      );
      expect(result.taxAfterRebate, result.taxBeforeRebate);
    });
  });

  group('Section 87A marginal relief (old regime)', () {
    test('old regime rebate fully zeroes tax at exactly ₹5,00,000 taxable income', () {
      final result = TaxCalculator.calculate(
        profile: _profile(annualGrossIncome: 550000, regime: TaxRegime.old),
        now: now,
      );
      expect(result.taxableIncome, 500000);
      expect(result.taxAfterRebate, 0);
    });
  });
}
