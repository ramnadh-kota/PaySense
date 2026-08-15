import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/sms_review_item.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/sms_review_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'package:paysense/shared/widgets/wallet_selector_field.dart';

/// Lists SMS-detected transactions that weren't confident enough to
/// auto-add — either the parser wasn't sure, or the wallet to attribute
/// them to was ambiguous. Reachable from the "Transaction detected"
/// notification (Notification Center's existing tap-to-navigate flow) or
/// directly from Settings.
class SmsReviewScreen extends ConsumerWidget {
  const SmsReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(smsReviewItemsProvider);
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Detected Transactions'),
      ),
      body: SafeArea(
        child: itemsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No SMS-detected transactions waiting for review.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ReviewCard(
                item: items[index],
                wallets: wallets,
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load detected transactions right now.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.item, required this.wallets});

  final SmsReviewItem item;
  final List<Wallet> wallets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = item.direction == SmsReviewDirection.debit;
    final suggestedWallet = wallets
        .where((w) => w.id == item.suggestedWalletId)
        .toList();
    final walletLabel = suggestedWallet.isEmpty ? null : suggestedWallet.single.name;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${isExpense ? '-' : '+'}₹${item.amount.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isExpense ? AppColors.danger : AppColors.success,
                ),
              ),
              Text(
                item.isLikelyTransfer ? 'Possible transfer' : 'Transaction detected',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.merchant ?? item.sender,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            walletLabel != null ? 'Suggested: $walletLabel' : 'No account suggested',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (item.isLikelyTransfer)
            Text(
              'This looks like a transfer between your own accounts — add it '
              'manually from the Wallet screen if needed.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () =>
                    ref.read(smsReviewItemsProvider.notifier).ignoreItem(item.id),
                child: const Text('Ignore'),
              ),
              if (!item.isLikelyTransfer)
                FilledButton(
                  onPressed: wallets.isEmpty
                      ? null
                      : () => _handleAccept(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add Transaction'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAccept(BuildContext context, WidgetRef ref) async {
    var walletId = item.suggestedWalletId;
    final hasValidSuggestion = wallets.any((w) => w.id == walletId);

    if (!hasValidSuggestion) {
      walletId = await _pickWallet(context);
      if (walletId == null) {
        return;
      }
    }

    await ref
        .read(smsReviewItemsProvider.notifier)
        .acceptItem(item.id, walletId: walletId!);
  }

  Future<String?> _pickWallet(BuildContext context) async {
    String? selected = wallets.first.id;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose an account',
                    style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  WalletSelectorField(
                    wallets: wallets,
                    selectedWalletId: selected,
                    onChanged: (value) => setState(() => selected = value),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(selected),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
