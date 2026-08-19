import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';

/// A fixed category preset for savings goals, bundling a display name with
/// the icon key and color persisted on [Goal].
class GoalPreset {
  const GoalPreset({
    required this.category,
    required this.iconKey,
    required this.icon,
    required this.color,
  });

  final String category;
  final String iconKey;
  final IconData icon;
  final Color color;
}

List<GoalPreset> get goalPresets => <GoalPreset>[
  GoalPreset(
    category: 'Emergency Fund',
    iconKey: 'shield',
    icon: Icons.shield_rounded,
    color: AppColors.danger,
  ),
  GoalPreset(
    category: 'Travel',
    iconKey: 'flight',
    icon: Icons.flight_takeoff_rounded,
    color: AppColors.primary,
  ),
  GoalPreset(
    category: 'Electronics',
    iconKey: 'laptop',
    icon: Icons.laptop_mac_rounded,
    color: AppColors.secondary,
  ),
  GoalPreset(
    category: 'Vehicle',
    iconKey: 'car',
    icon: Icons.directions_car_rounded,
    color: AppColors.warning,
  ),
  GoalPreset(
    category: 'Home',
    iconKey: 'home',
    icon: Icons.home_rounded,
    color: AppColors.success,
  ),
  GoalPreset(
    category: 'Education',
    iconKey: 'school',
    icon: Icons.school_rounded,
    color: AppColors.primary,
  ),
  GoalPreset(
    category: 'Other',
    iconKey: 'savings',
    icon: Icons.savings_rounded,
    color: AppColors.textSecondary,
  ),
];

/// Resolves a stored icon key back to its [IconData]. Falls back to the
/// 'Other' preset's icon if the key is unrecognized.
IconData iconForKey(String iconKey) {
  return goalPresets
      .firstWhere(
        (preset) => preset.iconKey == iconKey,
        orElse: () => goalPresets.last,
      )
      .icon;
}
