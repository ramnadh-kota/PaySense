import 'package:hive/hive.dart';

import '../utils/tax_calculator.dart';

part 'tax_settings.g.dart';

/// The persisted form of a [TaxProfile] (PHASE 2/13) — kept as a separate
/// Hive model rather than annotating [TaxProfile] itself, since
/// [TaxCalculator]/[TaxProfile] are deliberately pure Dart with zero Hive
/// dependency (PHASE 4). [regime]/[ageBand] are stored as plain strings
/// (not a Hive enum adapter) to keep this model simple; [toTaxProfile] /
/// [TaxSettings.fromTaxProfile] are the only places that translate between
/// the two representations.
@HiveType(typeId: 11)
class TaxSettings {
  const TaxSettings({
    required this.annualGrossIncome,
    required this.otherIncome,
    required this.regime,
    required this.ageBand,
    required this.section80C,
    required this.section80D,
    required this.homeLoanInterest,
    required this.hraExemption,
    required this.otherEligibleDeductions,
    required this.tdsAlreadyDeducted,
    required this.isIncomeEstimated,
    required this.updatedAt,
  });

  @HiveField(0)
  final double annualGrossIncome;
  @HiveField(1)
  final double otherIncome;
  @HiveField(2)
  final String regime; // 'old' | 'newRegime'
  @HiveField(3)
  final String ageBand; // 'below60' | 'seniorCitizen60to79' | 'superSenior80Plus'
  @HiveField(4)
  final double section80C;
  @HiveField(5)
  final double section80D;
  @HiveField(6)
  final double homeLoanInterest;
  @HiveField(7)
  final double hraExemption;
  @HiveField(8)
  final double otherEligibleDeductions;
  @HiveField(9)
  final double tdsAlreadyDeducted;
  @HiveField(10)
  final bool isIncomeEstimated;
  @HiveField(11)
  final DateTime updatedAt;

  factory TaxSettings.fromTaxProfile(TaxProfile profile, {DateTime? updatedAt}) {
    return TaxSettings(
      annualGrossIncome: profile.annualGrossIncome,
      otherIncome: profile.otherIncome,
      regime: profile.regime == TaxRegime.old ? 'old' : 'newRegime',
      ageBand: profile.ageBand.name,
      section80C: profile.section80C,
      section80D: profile.section80D,
      homeLoanInterest: profile.homeLoanInterest,
      hraExemption: profile.hraExemption,
      otherEligibleDeductions: profile.otherEligibleDeductions,
      tdsAlreadyDeducted: profile.tdsAlreadyDeducted,
      isIncomeEstimated: profile.isIncomeEstimated,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  TaxProfile toTaxProfile() {
    return TaxProfile(
      annualGrossIncome: annualGrossIncome,
      otherIncome: otherIncome,
      regime: regime == 'old' ? TaxRegime.old : TaxRegime.newRegime,
      ageBand: TaxAgeBand.values.firstWhere(
        (a) => a.name == ageBand,
        orElse: () => TaxAgeBand.below60,
      ),
      section80C: section80C,
      section80D: section80D,
      homeLoanInterest: homeLoanInterest,
      hraExemption: hraExemption,
      otherEligibleDeductions: otherEligibleDeductions,
      tdsAlreadyDeducted: tdsAlreadyDeducted,
      isIncomeEstimated: isIncomeEstimated,
    );
  }
}
