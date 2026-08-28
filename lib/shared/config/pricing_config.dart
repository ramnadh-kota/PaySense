import 'package:flutter/foundation.dart';

/// CONSUMER MONETIZATION FOUNDATION — PHASE 8. THE single place pricing
/// figures live. No screen/widget anywhere should hardcode a ₹ price —
/// everything reads from here, so swapping in real, remotely-configured
/// (or store-reported, once a payment SDK is integrated) prices later is a
/// one-file change.
///
/// These are explicitly PLACEHOLDER figures for the initial beta — see
/// each field's doc. Nothing here is connected to a real payment provider
/// (none is installed in this app yet); see `EntitlementRepository`.
@immutable
class PricingPlan {
  const PricingPlan({
    required this.id,
    required this.label,
    required this.amount,
    required this.currencyCode,
    required this.currencySymbol,
    required this.billingPeriodLabel,
    this.badge,
  });

  final String id;
  final String label;
  final double amount;
  final String currencyCode;
  final String currencySymbol;
  final String billingPeriodLabel;

  /// e.g. "Best value" — null when this plan has no badge.
  final String? badge;

  String get formattedPrice => '$currencySymbol${amount.toStringAsFixed(0)}$billingPeriodLabel';
}

class PricingConfig {
  PricingConfig._();

  /// PLACEHOLDER beta pricing — "Do not assume the final prices yet" per
  /// the product spec. Replace these two figures (and only these two) once
  /// final pricing is decided; every screen reads through [plans].
  static const List<PricingPlan> plans = [
    PricingPlan(
      id: 'plus_monthly',
      label: 'Monthly',
      amount: 149,
      currencyCode: 'INR',
      currencySymbol: '₹',
      billingPeriodLabel: '/month',
    ),
    PricingPlan(
      id: 'plus_annual',
      label: 'Annual',
      amount: 1299,
      currencyCode: 'INR',
      currencySymbol: '₹',
      billingPeriodLabel: '/year',
      badge: 'Best value',
    ),
  ];

  static PricingPlan get defaultPlan => plans.last;

  static PricingPlan? planById(String id) {
    for (final plan in plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  /// PHASE 9 — Founding Member offer. A development-safe, configurable
  /// discount shown only when [isFoundingUser] (see `entitlement_provider.dart`)
  /// is true. Never implies a real payment occurred.
  static const String foundingBadgeLabel = 'PaySense Founding Member';
  static const double foundingDiscountPercent = 30;

  static double foundingPrice(PricingPlan plan) => plan.amount * (1 - foundingDiscountPercent / 100);
}
