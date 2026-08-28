import 'package:flutter/foundation.dart';

import 'financial_health_trends_calculator.dart';

/// FINANCIAL INTELLIGENCE TIMELINE 1.0 — PHASE 3. Deliberately NOT another
/// financial-health score: this computes no new number at all. It's a thin,
/// explainable wrapper that reuses [FinancialHealthTrendResult.trajectory]
/// (already deterministically computed by [FinancialHealthTrendsCalculator])
/// for the headline status, plus the underlying per-domain
/// [TrendDirection]s already on [trends] as the "why" — so the Timeline can
/// answer "is my financial situation improving or declining lately?"
/// without introducing a second, potentially-conflicting scoring system.
enum FinancialMomentumStatus { improving, stable, declining, insufficientData }

@immutable
class FinancialMomentumSignal {
  const FinancialMomentumSignal({
    required this.label,
    required this.direction,
    required this.detail,
  });

  final String label;
  final TrendDirection direction;
  final String detail;
}

@immutable
class FinancialMomentum {
  const FinancialMomentum({
    required this.status,
    required this.signals,
    required this.hasSufficientData,
  });

  final FinancialMomentumStatus status;

  /// The underlying per-domain directions this status was derived from —
  /// makes the result explainable rather than a single opaque label.
  final List<FinancialMomentumSignal> signals;

  final bool hasSufficientData;
}

class FinancialMomentumCalculator {
  FinancialMomentumCalculator._();

  static FinancialMomentum calculate(FinancialHealthTrendResult trends) {
    if (!trends.hasSufficientData) {
      return const FinancialMomentum(
        status: FinancialMomentumStatus.insufficientData,
        signals: [],
        hasSufficientData: false,
      );
    }

    final signals = <FinancialMomentumSignal>[
      FinancialMomentumSignal(
        label: 'Savings rate',
        direction: trends.savingsTrend.direction,
        detail: _detailFor(trends.savingsTrend.direction, 'your savings rate'),
      ),
      FinancialMomentumSignal(
        label: 'Spending',
        direction: trends.expenseTrend.direction,
        detail: _detailFor(trends.expenseTrend.direction, 'your spending'),
      ),
      FinancialMomentumSignal(
        label: 'Budget discipline',
        direction: trends.budgetTrend.direction,
        detail: _detailFor(trends.budgetTrend.direction, 'how well you\'re staying within budget'),
      ),
      FinancialMomentumSignal(
        label: 'Debt',
        direction: trends.debtTrend.direction,
        detail: _detailFor(trends.debtTrend.direction, 'your outstanding debt'),
      ),
    ];

    return FinancialMomentum(
      status: _statusForTrajectory(trends.trajectory),
      signals: signals,
      hasSufficientData: true,
    );
  }

  static FinancialMomentumStatus _statusForTrajectory(OverallTrajectory trajectory) {
    switch (trajectory) {
      case OverallTrajectory.stronglyImproving:
      case OverallTrajectory.improving:
        return FinancialMomentumStatus.improving;
      case OverallTrajectory.declining:
        return FinancialMomentumStatus.declining;
      case OverallTrajectory.stable:
      case OverallTrajectory.mixed:
        return FinancialMomentumStatus.stable;
      case OverallTrajectory.insufficientData:
        return FinancialMomentumStatus.insufficientData;
    }
  }

  static String _detailFor(TrendDirection direction, String subject) {
    switch (direction) {
      case TrendDirection.improving:
        return 'Improving — $subject is trending in a good direction.';
      case TrendDirection.declining:
        return 'Declining — $subject needs attention.';
      case TrendDirection.stable:
        return 'Stable — no material change in $subject.';
      case TrendDirection.insufficientData:
        return 'Not enough history yet to judge $subject.';
    }
  }
}
