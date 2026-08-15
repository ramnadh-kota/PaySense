import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/providers/safe_to_spend_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';

/// Compact Dashboard entry point for the Safe-to-Spend feature — a quick
/// daily-use answer, with the full breakdown one tap away on
/// [AppRoutes.safeToSpend].
class SafeToSpendCard extends ConsumerWidget {
  const SafeToSpendCard({super.key, required this.currencyFormatter});

  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(safeToSpendProvider);

    return AppCard(
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.safeToSpend),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'SAFE TO SPEND',
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
          if (!result.hasSufficientData)
            Text(
              'Add your accounts to calculate your safe-to-spend amount.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else if (result.isShortfall) ...[
            Text(
              '${currencyFormatter.format(result.shortfall)} short',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'for upcoming commitments',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ] else ...[
            Text(
              currencyFormatter.format(result.safeToSpend),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Suggested daily spending: ${currencyFormatter.format(result.dailySafeToSpend)}/day',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Based on upcoming commitments · Next ${result.windowDays} days',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
