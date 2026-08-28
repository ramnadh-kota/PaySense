import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/providers/auth_provider.dart';
import 'package:paysense/shared/services/account_deletion_service.dart';

/// ACCOUNT DELETION — PHASE N. Settings -> Account -> Delete Account.
/// PaySense has no server-side identity (confirmed during the Account
/// Aggregator Phase 0 audit — auth is fully local/on-device), so this
/// deletes every local trace and there is no backend request to send
/// today — see `AccountDeletionService`'s own doc comment for exactly
/// where that hook would go if one is ever introduced.
class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  ConsumerState<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Delete Account'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                'This will permanently delete your account',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              // HONESTY FIX: PaySense's local financial storage is not yet
              // partitioned per account (every account on this device
              // currently shares the same local data) — deleting removes
              // ALL of it, not just records tied to the account you're
              // signed in as. Making that explicit here rather than
              // implying a precision the app can't yet guarantee.
              Text(
                'This removes ALL PaySense data on this device — including data '
                'from any other account signed in on this device, since PaySense '
                'does not yet separate accounts\' data locally:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              const _DeletionItem(text: 'All transactions, wallets, and account balances'),
              const _DeletionItem(text: 'Goals, budgets, loans, and recurring payments'),
              const _DeletionItem(text: 'Connected bank account metadata'),
              const _DeletionItem(text: 'Search history and notification history'),
              const _DeletionItem(text: 'SMS-derived transaction review data and your app lock PIN'),
              const _DeletionItem(text: 'Your profile and login credentials'),
              const SizedBox(height: 16),
              Text(
                'This action cannot be undone.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isDeleting ? null : () => _handleDelete(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isDeleting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Delete My Account'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('All your PaySense data on this device will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    final email = ref.read(authProvider).value?.account?.email;
    if (email == null) return;

    try {
      await AccountDeletionService.deleteEverythingLocally(email);
      ref.invalidate(authProvider);
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("We couldn't complete account deletion. Please try again.")),
      );
    }
  }
}

class _DeletionItem extends StatelessWidget {
  const _DeletionItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.remove_circle_outline_rounded, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
