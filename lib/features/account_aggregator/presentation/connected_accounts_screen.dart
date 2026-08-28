import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/providers/account_aggregator_connections_provider.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_models.dart';
import 'package:paysense/shared/widgets/app_card.dart';

import 'bank_connect_screen.dart';

/// ACCOUNT AGGREGATOR — PART B/PHASE 15 (Settings entry point). Shows
/// every persisted [AccountAggregatorConnection] with its accounts,
/// last-synced timestamp, and Sync Now / Revoke / Disconnect actions.
/// Distinct from [BankConnectScreen] (the one-time connect wizard) —
/// this is the ongoing management surface.
class ConnectedAccountsScreen extends ConsumerWidget {
  const ConnectedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsAsync = ref.watch(accountAggregatorConnectionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Connected Financial Accounts'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      body: SafeArea(
        child: connectionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Text(
              'Unable to load connected accounts right now.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          data: (connections) {
            final active = connections.where((c) => c.status != ConnectionStatus.revoked).toList();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (active.isEmpty)
                  _EmptyState(
                    onConnect: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const BankConnectScreen()),
                    ),
                  )
                else ...[
                  for (final connection in active) _ConnectionCard(connection: connection),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const BankConnectScreen()),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Connect another account'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onConnect});
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.account_balance_outlined, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No accounts connected yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your bank accounts securely to bring your financial picture together.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onConnect,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Connect Accounts'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends ConsumerStatefulWidget {
  const _ConnectionCard({required this.connection});
  final AccountAggregatorConnection connection;

  @override
  ConsumerState<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends ConsumerState<_ConnectionCard> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final connection = widget.connection;
    final dateFormat = DateFormat('d MMM yyyy, h:mm a');
    final statusColor = switch (connection.status) {
      ConnectionStatus.connected => AppColors.success,
      ConnectionStatus.partiallyConnected => AppColors.warning,
      ConnectionStatus.failed => AppColors.danger,
      ConnectionStatus.revoked => AppColors.danger,
      _ => AppColors.textSecondary,
    };

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connection.status.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              if (connection.isMock)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('TEST DATA', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final account in connection.accounts) _AccountRow(account: account),
          const SizedBox(height: 8),
          Text(
            connection.lastSyncedAt != null
                ? 'Last synced: ${dateFormat.format(connection.lastSyncedAt!)}'
                : 'Not yet synced',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (connection.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(connection.errorMessage!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSyncing ? null : () => _handleSyncNow(context),
                  child: _isSyncing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sync now'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleRevoke(context),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: BorderSide(color: AppColors.danger)),
                  child: const Text('Revoke'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleSyncNow(BuildContext context) async {
    setState(() => _isSyncing = true);
    try {
      final summary = await ref.read(accountAggregatorConnectionsProvider.notifier).syncNow(widget.connection.connectionId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Synced ${summary.totalConsidered - summary.duplicateCount - summary.skippedUnmappedCount} transactions — '
            '${summary.importedCount} added, ${summary.duplicateCount} already existed'
            '${summary.needsReviewCount > 0 ? ', ${summary.needsReviewCount} need review' : ''}.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank sync needs attention. Your existing PaySense data is safe.')),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleRevoke(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke access?'),
        content: const Text(
          'PaySense will stop syncing new transactions from this connection. '
          'Transactions already imported will stay in your history.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Revoke', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(accountAggregatorConnectionsProvider.notifier).revoke(widget.connection.connectionId);
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});
  final AccountAggregatorAccount account;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.displayName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
                Text(account.maskedIdentifier, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (account.balance != null)
            Text(
              '₹${account.balance!.toStringAsFixed(0)}${account.institutionType.isLiability ? ' owed' : ''}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: account.institutionType.isLiability ? AppColors.danger : AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
