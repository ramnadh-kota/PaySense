import 'package:flutter/material.dart';

import 'entitlement.dart' as entitlement_model;

/// FEATURE SEARCH — one entry in the central feature registry
/// ([kFeatureRegistry] in `feature_registry.dart`). Every entry maps to a
/// REAL existing PaySense route — this model never represents a feature
/// that doesn't already exist in the app; the registry is a curated index
/// of `AppRoutes` constants, not a place to invent new capabilities.
@immutable
class FeatureSearchItem {
  const FeatureSearchItem({
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.category,
    required this.icon,
    required this.route,
    this.entitlement,
  });

  final String title;
  final String subtitle;

  /// Extra search terms/aliases beyond the title itself (e.g. "emi" for
  /// Loans, "afford" for the affordability calculator).
  final List<String> keywords;
  final String category;
  final IconData icon;

  /// An `AppRoutes` constant — `Navigator.pushNamed(context, route)`.
  final String route;

  /// Null means always available on the free tier. Reuses the EXISTING
  /// entitlement model (`lib/shared/models/entitlement.dart`) — this
  /// search feature never introduces a second entitlement system.
  final entitlement_model.Entitlement? entitlement;
}
