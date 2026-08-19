import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/wallet.dart';

/// The single, centralized wallet-selection control used everywhere a form
/// needs the user to pick a real [Wallet] — Add Expense, Add Income, and
/// the Bill/Loan/Recurring Transaction forms. Displays each wallet's name
/// and current balance; the value it reports back via [onChanged] is always
/// the wallet's stable [Wallet.id], never its display name.
///
/// Intentionally has no Riverpod dependency of its own — callers (each of
/// which already has access to `walletsProvider`) pass the wallet list in,
/// keeping this widget reusable from both `ConsumerStatefulWidget` screens
/// and plain `StatefulWidget` form sheets fed via constructor parameters.
class WalletSelectorField extends StatelessWidget {
  const WalletSelectorField({
    super.key,
    required this.wallets,
    required this.selectedWalletId,
    required this.onChanged,
    this.label = 'Account',
  });

  final List<Wallet> wallets;
  final String? selectedWalletId;
  final ValueChanged<String?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final validValue = wallets.any((w) => w.id == selectedWalletId) ? selectedWalletId : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: validValue,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
        items: wallets.map((wallet) {
          return DropdownMenuItem<String>(
            value: wallet.id,
            child: Text('${wallet.name} · ₹${wallet.currentBalance.toStringAsFixed(0)}'),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

/// A compact inline message for when there are no (eligible) wallets to
/// choose from — used consistently anywhere [WalletSelectorField] would
/// otherwise have nothing to offer. When [onAddWallet] is given, this
/// renders an actual "Add Wallet" action rather than leaving the user with
/// informational text and no way forward from this screen.
class NoWalletsMessage extends StatelessWidget {
  const NoWalletsMessage({
    super.key,
    required this.message,
    this.onAddWallet,
  });

  final String message;
  final VoidCallback? onAddWallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No wallets yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (onAddWallet != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddWallet,
                icon: Icon(Icons.add_rounded, color: AppColors.primary),
                label: const Text('Add Wallet'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
