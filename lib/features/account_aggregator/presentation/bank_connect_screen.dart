import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/bank_connect_session.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/account_aggregator_provider.dart';
import 'package:paysense/shared/providers/bank_connect_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_models.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'package:paysense/shared/widgets/wallet_selector_field.dart';

/// ACCOUNT AGGREGATOR — PART B. The one-time "Connect Bank" flow, driven
/// entirely by [BankConnectSession.step]. Mirrors the CSV import screen's
/// pattern: one screen, step-switched content, no full-page navigation
/// between steps — keeps state threading simple and matches this
/// codebase's established convention for multi-step flows.
class BankConnectScreen extends ConsumerStatefulWidget {
  const BankConnectScreen({super.key});

  @override
  ConsumerState<BankConnectScreen> createState() => _BankConnectScreenState();
}

class _BankConnectScreenState extends ConsumerState<BankConnectScreen> {
  final Set<FinancialInstitutionType> _selectedTypes = {
    FinancialInstitutionType.bank,
    FinancialInstitutionType.creditCard,
    FinancialInstitutionType.loan,
  };
  Duration _historyDuration = const Duration(days: 180);

  @override
  void dispose() {
    ref.read(bankConnectProvider.notifier).reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(bankConnectProvider);
    final isMockProvider = ref.watch(accountAggregatorServiceProvider).activeProviderId == 'mock';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Connect Bank Account'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        actions: [
          // SECURITY AUDIT FINDING: the mock provider is reachable in any
          // build that doesn't explicitly pass
          // --dart-define=AA_ENVIRONMENT=production, including release —
          // this badge makes that visible in the UI itself rather than
          // relying on a build-time flag alone, so test data is never
          // mistaken for a real bank connection.
          if (isMockProvider)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('TEST DATA', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, session)),
    );
  }

  Widget _buildBody(BuildContext context, BankConnectSession session) {
    switch (session.step) {
      case BankConnectStep.selectingInstitutions:
        return _buildIntro(context);
      case BankConnectStep.consentExplanation:
        return _buildConsentExplanation(context, session);
      case BankConnectStep.awaitingConsent:
        return _buildAwaitingConsent(context, session);
      case BankConnectStep.fetchingAccounts:
        return const _CenteredLoading(message: 'Fetching your accounts…');
      case BankConnectStep.mappingAccounts:
        return _buildMapping(context, session);
      case BankConnectStep.syncing:
        return const _CenteredLoading(message: 'Syncing transactions…');
      case BankConnectStep.completed:
        return _buildCompleted(context, session);
      case BankConnectStep.failed:
        return _buildFailed(context, session);
    }
  }

  // ---------------------------------------------------------------------
  // Step: intro / institution selection
  // ---------------------------------------------------------------------

  Widget _buildIntro(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_balance_rounded, size: 48, color: AppColors.accent),
          const SizedBox(height: 16),
          Text(
            'Connect your financial life',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect supported financial accounts using a secure, consent-based process. '
            'You stay in control of what data you share, and PaySense never needs your bank password.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _BenefitLine(text: 'Automatic transaction updates'),
          _BenefitLine(text: 'One complete financial picture'),
          _BenefitLine(text: 'Less manual entry'),
          _BenefitLine(text: 'Smarter financial insights'),
          const SizedBox(height: 20),
          Text(
            'What type of accounts?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FinancialInstitutionType.values.map((type) {
              final selected = _selectedTypes.contains(type);
              return FilterChip(
                label: Text(type.label),
                selected: selected,
                onSelected: (value) => setState(() {
                  if (value) {
                    _selectedTypes.add(type);
                  } else {
                    _selectedTypes.remove(type);
                  }
                }),
                selectedColor: AppColors.accent.withValues(alpha: 0.18),
                checkmarkColor: AppColors.accent,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            'How much history?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _DurationChip(
                label: '3 months',
                selected: _historyDuration.inDays == 90,
                onTap: () => setState(() => _historyDuration = const Duration(days: 90)),
              ),
              const SizedBox(width: 8),
              _DurationChip(
                label: '6 months',
                selected: _historyDuration.inDays == 180,
                onTap: () => setState(() => _historyDuration = const Duration(days: 180)),
              ),
              const SizedBox(width: 8),
              _DurationChip(
                label: '12 months',
                selected: _historyDuration.inDays == 365,
                onTap: () => setState(() => _historyDuration = const Duration(days: 365)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'PaySense never asks for your bank password, UPI PIN, OTP, or card PIN.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedTypes.isEmpty
                  ? null
                  : () {
                      final notifier = ref.read(bankConnectProvider.notifier);
                      notifier.selectInstitutionTypes(_selectedTypes.toList());
                      notifier.setHistoryDuration(_historyDuration);
                      notifier.proceedToConsentExplanation();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Connect Accounts'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Step: consent explanation
  // ---------------------------------------------------------------------

  Widget _buildConsentExplanation(BuildContext context, BankConnectSession session) {
    final userId = ref.watch(userProfileProvider).value?.id ?? 'local-user';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What will PaySense access?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const _BenefitLine(text: 'Account details'),
          const _BenefitLine(text: 'Transaction history'),
          const _BenefitLine(text: 'Account balance'),
          const SizedBox(height: 16),
          Text(
            'Choose what financial data you want to share.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'History requested: ${_historyLabel(session.historyDuration)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            'Your consent can be revoked at any time from Settings.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => ref.read(bankConnectProvider.notifier).startConsent(userId),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  String _historyLabel(Duration d) {
    if (d.inDays <= 90) return '3 months';
    if (d.inDays <= 180) return '6 months';
    return '12 months';
  }

  // ---------------------------------------------------------------------
  // Step: awaiting consent
  // ---------------------------------------------------------------------

  Widget _buildAwaitingConsent(BuildContext context, BankConnectSession session) {
    final mockControls = ref.watch(accountAggregatorDevControlsProvider);
    final notifier = ref.read(bankConnectProvider.notifier);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Waiting for your consent',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete the consent request on your financial institution\'s flow, then come back here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => notifier.refreshConsentStatus(),
              child: const Text("I've completed this"),
            ),
            if (mockControls != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Development mode — simulate the outcome',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => notifier.simulateApproveConsent(),
                          child: const Text('Simulate: Approve'),
                        ),
                        TextButton(
                          onPressed: () => notifier.simulateRejectConsent(),
                          child: const Text('Simulate: Reject'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Step: account mapping (PART D)
  // ---------------------------------------------------------------------

  Widget _buildMapping(BuildContext context, BankConnectSession session) {
    final walletsAsync = ref.watch(walletsProvider);
    final wallets = (walletsAsync.value ?? const <Wallet>[]).where((w) => !w.isArchived).toList();
    final notifier = ref.read(bankConnectProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Found ${session.discoveredAccounts.length} financial accounts',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how each account should show up in PaySense.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final account in session.mappableAccounts)
            _AccountMappingCard(
              account: account,
              wallets: wallets,
              decision: session.mappingDecisions[account.id] ?? AccountMappingDecision.pending,
              selectedWalletId: session.selectedWalletIdByAccountId[account.id],
              onCreateNew: () => notifier.setMappingDecision(account.id, AccountMappingDecision.createNewWallet),
              onMapExisting: (walletId) => notifier.setExistingWalletChoice(account.id, walletId),
              onIgnore: () => notifier.setMappingDecision(account.id, AccountMappingDecision.ignore),
            ),
          if (session.liabilityAccounts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Liabilities (shown for reference — not added as spending wallets)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            for (final account in session.liabilityAccounts) _LiabilityAccountCard(account: account),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => notifier.confirmMappingAndSync(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Step: completed / failed
  // ---------------------------------------------------------------------

  Widget _buildCompleted(BuildContext context, BankConnectSession session) {
    final summary = session.syncSummary;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 56, color: AppColors.success),
            const SizedBox(height: 16),
            Text(
              'Your financial picture is ready',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (summary != null) ...[
              const SizedBox(height: 16),
              _SummaryLine(label: '${session.discoveredAccounts.length} accounts connected', value: ''),
              _SummaryLine(label: 'New transactions', value: '${summary.importedCount}'),
              _SummaryLine(label: 'Already existed', value: '${summary.duplicateCount}'),
              if (summary.needsReviewCount > 0)
                _SummaryLine(label: 'Need review', value: '${summary.needsReviewCount}'),
              if (summary.skippedUnmappedCount > 0)
                _SummaryLine(label: 'Skipped (unmapped)', value: '${summary.skippedUnmappedCount}'),
              _SummaryLine(
                label: 'Total cash balance',
                value: currency.format(
                  session.mappableAccounts.fold<double>(0, (sum, a) => sum + (a.balance ?? 0)),
                ),
              ),
              if (session.liabilityAccounts.isNotEmpty)
                _SummaryLine(
                  label: 'Total debt',
                  value: currency.format(
                    session.liabilityAccounts.fold<double>(0, (sum, a) => sum + (a.balance ?? 0)),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('View Financial Picture'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailed(BuildContext context, BankConnectSession session) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              session.errorMessage ?? "We couldn't complete the connection.",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your existing PaySense data is safe.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => ref.read(bankConnectProvider.notifier).reset(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Try Again'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredLoading extends StatelessWidget {
  const _CenteredLoading({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _BenefitLine extends StatelessWidget {
  const _BenefitLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.accent.withValues(alpha: 0.18),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          if (value.isNotEmpty)
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
        ],
      ),
    );
  }
}

class _AccountMappingCard extends StatelessWidget {
  const _AccountMappingCard({
    required this.account,
    required this.wallets,
    required this.decision,
    required this.selectedWalletId,
    required this.onCreateNew,
    required this.onMapExisting,
    required this.onIgnore,
  });

  final AccountAggregatorAccount account;
  final List<Wallet> wallets;
  final AccountMappingDecision decision;
  final String? selectedWalletId;
  final VoidCallback onCreateNew;
  final ValueChanged<String> onMapExisting;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${account.institutionName} · ${account.maskedIdentifier}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (account.balance != null)
                Text(
                  '₹${account.balance!.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Create new wallet'),
                selected: decision == AccountMappingDecision.createNewWallet,
                onSelected: (_) => onCreateNew(),
              ),
              ChoiceChip(
                label: const Text('Ignore'),
                selected: decision == AccountMappingDecision.ignore,
                onSelected: (_) => onIgnore(),
              ),
            ],
          ),
          if (wallets.isNotEmpty) ...[
            const SizedBox(height: 8),
            WalletSelectorField(
              label: 'Or map to existing wallet',
              wallets: wallets,
              selectedWalletId: decision == AccountMappingDecision.mapToExistingWallet ? selectedWalletId : null,
              onChanged: (walletId) {
                if (walletId != null) onMapExisting(walletId);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _LiabilityAccountCard extends StatelessWidget {
  const _LiabilityAccountCard({required this.account});
  final AccountAggregatorAccount account;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 16,
      color: AppColors.surfaceVariant,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(
                  '${account.institutionName} · ${account.maskedIdentifier}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (account.balance != null)
            Text(
              '₹${account.balance!.toStringAsFixed(0)} outstanding',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.danger),
            ),
        ],
      ),
    );
  }
}
