import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/services/analytics_service.dart';
import 'package:paysense/shared/widgets/app_card.dart';

/// CONSUMER MONETIZATION FOUNDATION (PHASE 7) — the ONE shared, tasteful
/// premium-discovery touchpoint used on the AI/Affordability/Tax Planner
/// screens. Deliberately a small, non-blocking card — never a modal, never
/// something that interrupts the existing screen's real functionality.
class PremiumDiscoveryBanner extends StatelessWidget {
  const PremiumDiscoveryBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.ctaLabel = 'Unlock Financial Intelligence',
    this.analyticsContext = 'unknown',
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final String analyticsContext;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        AnalyticsService.instance.log(
          AnalyticsEvent.premiumFeatureViewed,
          metadata: {'context': analyticsContext},
        );
        Navigator.of(context).pushNamed(AppRoutes.paywall);
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.lightTeal, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '$ctaLabel →',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
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
