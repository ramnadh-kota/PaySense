import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/providers/subscription_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';

/// Compact Dashboard entry point for the Subscription Manager — a quick
/// "what am I paying for" glance, with the full list one tap away on
/// [AppRoutes.subscriptions].
class SubscriptionsCard extends ConsumerWidget {
  const SubscriptionsCard({super.key, required this.currencyFormatter});

  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(subscriptionTotalsProvider);
    final upcoming = ref.watch(subscriptionUpcomingRenewalsProvider);

    return AppCard(
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.subscriptions),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'SUBSCRIPTIONS',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 10),
          if (!totals.hasSubscriptions)
            Text(
              'Add recurring expenses to track subscriptions.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            Text(
              '${currencyFormatter.format(totals.totalMonthlyCost)} / month',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${totals.activeCount} active service${totals.activeCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (upcoming.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.autorenew_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Next: ${upcoming.first.name} · ${currencyFormatter.format(upcoming.first.amount)}',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 10),
          Text(
            'View subscriptions →',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
