import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/providers/fun_funds_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';

/// Compact Dashboard entry point for Fun Funds — the full breakdown and
/// Friends/Groups list are one tap away on [AppRoutes.funFunds]. Never
/// implies spending is mandatory — see the ₹0 copy below.
class FunFundsCard extends ConsumerWidget {
  const FunFundsCard({super.key, required this.currencyFormatter});

  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(funFundsResultProvider);

    return AppCard(
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.funFunds),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'FUN FUNDS',
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
              'Build your financial picture to see your Fun Funds.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          else if (result.funFunds <= 0) ...[
            Text(
              currencyFormatter.format(0),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Focus on commitments first.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ] else ...[
            Text(
              currencyFormatter.format(result.funFunds),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Safe discretionary amount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.groups_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'View Fun Funds · Friends & Groups',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
