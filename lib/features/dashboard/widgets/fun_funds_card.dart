import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/providers/fun_funds_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';

/// Compact Dashboard entry point for Fun Funds — "how much can I enjoy
/// spending this month", with the full breakdown and Friends/Group
/// expenses one tap away on [AppRoutes.funFunds]. Deliberately as compact
/// as [SafeToSpendCard] so the Dashboard doesn't get overloaded.
class FunFundsCard extends ConsumerWidget {
  const FunFundsCard({super.key, required this.currencyFormatter});

  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(funFundsProvider);

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
              'Add your accounts to see what you can comfortably enjoy '
              'spending this month.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          else ...[
            Text(
              '${currencyFormatter.format(result.remaining)} remaining',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.celebration_outlined,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${result.utilizationPercent.clamp(0, 999).toStringAsFixed(0)}% used · "
                    'this is what you can comfortably enjoy this month.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.funFunds),
                  icon: const Icon(Icons.group_add_rounded, size: 16),
                  label: const Text('Add Group Expense'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
