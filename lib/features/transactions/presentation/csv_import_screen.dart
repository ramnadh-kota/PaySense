import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/features/wallet/presentation/add_edit_wallet_screen.dart';
import 'package:paysense/shared/models/csv_import_completion_result.dart';
import 'package:paysense/shared/models/csv_import_session.dart';
import 'package:paysense/shared/models/transaction_ingestion_result.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/csv_import_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/widgets/wallet_selector_field.dart';

/// CSV BANK STATEMENT IMPORT — PHASE 15. Single entry-point screen for
/// the whole flow. [CsvImportStatus] (from [CsvImportSession]) drives the
/// major steps (selecting/mapping/preview/importing/completed/failed);
/// "review problematic rows", "select wallet" and "confirm" are UI-only
/// sub-steps of `previewReady` — the underlying pipeline data doesn't
/// change just because the user is looking at a different part of it, so
/// they're tracked here as local widget state, not extra session states.
class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key});

  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportScreenState();
}

enum _PreviewStep { review, wallet, confirm }

class _CsvImportScreenState extends ConsumerState<CsvImportScreen> {
  _PreviewStep _previewStep = _PreviewStep.review;
  CsvImportCompletionResult? _completionResult;
  bool _isImporting = false;

  @override
  void dispose() {
    // Discard any in-progress (never-confirmed) session so leaving this
    // screen — by any route, not just the explicit Cancel/Done buttons —
    // never leaves stale state behind for the next visit. Nothing has
    // been written to any repository regardless (PHASE 13); this only
    // clears in-memory UI state.
    ref.read(csvImportProvider.notifier).reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(csvImportProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Import Bank Statement'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      body: SafeArea(child: _buildBody(context, session)),
    );
  }

  Widget _buildBody(BuildContext context, CsvImportSession session) {
    switch (session.status) {
      case CsvImportStatus.selecting:
        return _buildSelecting(context);
      case CsvImportStatus.reading:
      case CsvImportStatus.detecting:
        return const _CenteredLoading(message: 'Reading your file…');
      case CsvImportStatus.mappingRequired:
        return _buildMapping(context, session);
      case CsvImportStatus.previewReady:
        return _buildPreviewFlow(context, session);
      case CsvImportStatus.importing:
        return const _CenteredLoading(message: 'Importing transactions…');
      case CsvImportStatus.completed:
        return _buildCompleted(context);
      case CsvImportStatus.failed:
        return _buildFailed(context, session);
    }
  }

  // ---------------------------------------------------------------------
  // Step: select file
  // ---------------------------------------------------------------------

  Widget _buildSelecting(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file_rounded, size: 56, color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              'Import a bank statement',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a CSV file exported from your bank. Everything is processed on your '
              'device — nothing is uploaded anywhere.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => ref.read(csvImportProvider.notifier).pickAndReadFile(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Select CSV File'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Step: column mapping
  // ---------------------------------------------------------------------

  Widget _buildMapping(BuildContext context, CsvImportSession session) {
    final mapping = session.columnMapping ?? const CsvColumnMapping();
    final headers = session.headers;

    Widget columnDropdown({
      required String label,
      required String? value,
      required ValueChanged<String?> onChanged,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(labelText: label, border: InputBorder.none),
            items: [
              const DropdownMenuItem<String>(value: '', child: Text('Not in this file')),
              ...headers.map((h) => DropdownMenuItem<String>(value: h, child: Text(h))),
            ],
            onChanged: (v) => onChanged(v == '' ? null : v),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "We couldn't confidently match every column — please confirm which column holds each field.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          columnDropdown(
            label: 'Date',
            value: mapping.dateColumn,
            onChanged: (v) => ref
                .read(csvImportProvider.notifier)
                .updateColumnMapping(mapping.copyWith(dateColumn: v)),
          ),
          columnDropdown(
            label: 'Description / Narration',
            value: mapping.descriptionColumn,
            onChanged: (v) => ref
                .read(csvImportProvider.notifier)
                .updateColumnMapping(mapping.copyWith(descriptionColumn: v)),
          ),
          columnDropdown(
            label: 'Debit / Withdrawal',
            value: mapping.debitColumn,
            onChanged: (v) => ref
                .read(csvImportProvider.notifier)
                .updateColumnMapping(mapping.copyWith(debitColumn: v)),
          ),
          columnDropdown(
            label: 'Credit / Deposit',
            value: mapping.creditColumn,
            onChanged: (v) => ref
                .read(csvImportProvider.notifier)
                .updateColumnMapping(mapping.copyWith(creditColumn: v)),
          ),
          columnDropdown(
            label: 'Amount (single column)',
            value: mapping.amountColumn,
            onChanged: (v) => ref
                .read(csvImportProvider.notifier)
                .updateColumnMapping(mapping.copyWith(amountColumn: v)),
          ),
          columnDropdown(
            label: 'Reference / UTR',
            value: mapping.referenceColumn,
            onChanged: (v) => ref
                .read(csvImportProvider.notifier)
                .updateColumnMapping(mapping.copyWith(referenceColumn: v)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => ref.read(csvImportProvider.notifier).confirmColumnMapping(),
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
  // Step: preview / review / wallet / confirm (all previewReady)
  // ---------------------------------------------------------------------

  Widget _buildPreviewFlow(BuildContext context, CsvImportSession session) {
    switch (_previewStep) {
      case _PreviewStep.review:
        return _buildPreviewAndReview(context, session);
      case _PreviewStep.wallet:
        return _buildWalletSelect(context, session);
      case _PreviewStep.confirm:
        return _buildConfirm(context, session);
    }
  }

  Widget _buildPreviewAndReview(BuildContext context, CsvImportSession session) {
    final dateFormat = DateFormat('d MMM yyyy');
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCard(session: session, dateFormat: dateFormat, currency: currency),
          const SizedBox(height: 16),
          _BreakdownRow(session: session),
          if (session.needsReviewCount > 0) ...[
            const SizedBox(height: 20),
            Text(
              'Needs review',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ..._needsReviewRows(session).map(
              (entry) => _ReviewRowCard(
                index: entry.key,
                result: entry.value,
                decision: session.rowDecisions[entry.key] ?? CsvRowDecision.pending,
                dateFormat: dateFormat,
                onDecision: (decision) =>
                    ref.read(csvImportProvider.notifier).applyRowDecision(entry.key, decision),
              ),
            ),
          ],
          if (session.invalidCount > 0) ...[
            const SizedBox(height: 20),
            Text(
              'Could not be imported',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...session.rowIssues.map((issue) => _InvalidRowCard(
                  description: 'Row ${issue.rowNumber}',
                  reason: issue.message,
                )),
            ...session.invalidResults.map((result) => _InvalidRowCard(
                  description: result.record.description ?? result.record.merchant ?? 'Row',
                  reason: result.validationErrors.join(' '),
                )),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(() => _previewStep = _PreviewStep.wallet),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ref.read(csvImportProvider.notifier).reset();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Iterable<MapEntry<int, TransactionIngestionResult>> _needsReviewRows(CsvImportSession session) sync* {
    for (var i = 0; i < session.pipelineResults.length; i++) {
      final result = session.pipelineResults[i];
      if (result.status == TransactionIngestionStatus.needsReview) {
        yield MapEntry(i, result);
      }
    }
  }

  Widget _buildWalletSelect(BuildContext context, CsvImportSession session) {
    final walletsAsync = ref.watch(walletsProvider);
    final wallets = (walletsAsync.value ?? const <Wallet>[]).where((w) => !w.isArchived).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Which account should these transactions go into?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (wallets.isEmpty)
            NoWalletsMessage(
              message: 'Create a wallet first to import transactions.',
              onAddWallet: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddEditWalletScreen()),
              ),
            )
          else
            WalletSelectorField(
              label: 'Import into',
              wallets: wallets,
              selectedWalletId: session.selectedWalletId,
              onChanged: (walletId) {
                if (walletId != null) {
                  ref.read(csvImportProvider.notifier).selectWallet(walletId);
                }
              },
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: session.selectedWalletId == null
                  ? null
                  : () => setState(() => _previewStep = _PreviewStep.confirm),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _previewStep = _PreviewStep.review),
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirm(BuildContext context, CsvImportSession session) {
    final walletsAsync = ref.watch(walletsProvider);
    final wallets = walletsAsync.value ?? const <Wallet>[];
    final walletName = wallets
        .where((w) => w.id == session.selectedWalletId)
        .map((w) => w.name)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormat = DateFormat('d MMM yyyy');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ready to import ${session.readyToImportCount} transaction'
            '${session.readyToImportCount == 1 ? '' : 's'}'
            '${walletName != null ? ' into $walletName' : ''}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _SummaryLine(label: 'Income total', value: currency.format(session.incomeTotal)),
          _SummaryLine(label: 'Expense total', value: currency.format(session.expenseTotal)),
          if (session.earliestDate != null && session.latestDate != null)
            _SummaryLine(
              label: 'Date range',
              value: '${dateFormat.format(session.earliestDate!)} – ${dateFormat.format(session.latestDate!)}',
            ),
          _SummaryLine(label: 'Duplicates skipped', value: '${session.duplicateCount}'),
          _SummaryLine(label: 'Review rows skipped', value: '${session.needsReviewCount}'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isImporting ? null : () => _handleConfirmImport(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Import Transactions'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isImporting
                  ? null
                  : () {
                      ref.read(csvImportProvider.notifier).reset();
                      Navigator.of(context).pop();
                    },
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmImport(BuildContext context) async {
    setState(() => _isImporting = true);
    final result = await ref.read(csvImportProvider.notifier).confirmImport();
    if (!mounted) return;
    setState(() {
      _completionResult = result;
      _isImporting = false;
    });
  }

  // ---------------------------------------------------------------------
  // Step: completed / failed
  // ---------------------------------------------------------------------

  Widget _buildCompleted(BuildContext context) {
    final result = _completionResult;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 56, color: AppColors.success),
            const SizedBox(height: 16),
            Text(
              'Import complete',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              _SummaryLine(label: 'Imported', value: '${result.importedCount}'),
              _SummaryLine(label: 'Duplicates skipped', value: '${result.duplicateCount}'),
              _SummaryLine(label: 'Rows skipped', value: '${result.skippedCount}'),
              if (result.failedCount > 0)
                _SummaryLine(label: 'Failed', value: '${result.failedCount}'),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ref.read(csvImportProvider.notifier).reset();
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailed(BuildContext context, CsvImportSession session) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              session.errorMessage ?? 'Something went wrong while reading this file.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => ref.read(csvImportProvider.notifier).reset(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Try Again'),
              ),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.session, required this.dateFormat, required this.currency});
  final CsvImportSession session;
  final DateFormat dateFormat;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final bank = session.detectionResult?.detectedBank.label ?? 'Generic bank statement';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${session.totalRows} transactions found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _SummaryLine(label: 'File', value: session.fileName ?? '—'),
          _SummaryLine(label: 'Detected bank', value: bank),
          if (session.earliestDate != null && session.latestDate != null)
            _SummaryLine(
              label: 'Date range',
              value: '${dateFormat.format(session.earliestDate!)} – ${dateFormat.format(session.latestDate!)}',
            ),
          _SummaryLine(label: 'Income total', value: currency.format(session.incomeTotal)),
          _SummaryLine(label: 'Expense total', value: currency.format(session.expenseTotal)),
        ],
      ),
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
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.session});
  final CsvImportSession session;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _BreakdownChip(icon: Icons.check_circle_rounded, color: AppColors.success, label: 'Ready', count: session.validCount),
        _BreakdownChip(icon: Icons.swap_horiz_rounded, color: AppColors.warning, label: 'Possible duplicates', count: session.duplicateCount),
        _BreakdownChip(icon: Icons.error_outline_rounded, color: AppColors.warning, label: 'Need review', count: session.needsReviewCount),
        _BreakdownChip(icon: Icons.close_rounded, color: AppColors.danger, label: 'Invalid', count: session.invalidCount),
      ],
    );
  }
}

class _BreakdownChip extends StatelessWidget {
  const _BreakdownChip({required this.icon, required this.color, required this.label, required this.count});
  final IconData icon;
  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text('$count $label', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ReviewRowCard extends StatelessWidget {
  const _ReviewRowCard({
    required this.index,
    required this.result,
    required this.decision,
    required this.dateFormat,
    required this.onDecision,
  });

  final int index;
  final TransactionIngestionResult result;
  final CsvRowDecision decision;
  final DateFormat dateFormat;
  final ValueChanged<CsvRowDecision> onDecision;

  bool get _canCorrectDirection => !result.record.metadata.containsKey('unparseableDateText');

  @override
  Widget build(BuildContext context) {
    final record = result.record;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.description ?? record.merchant ?? 'Transaction',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '${record.dateTime != null ? dateFormat.format(record.dateTime!) : 'Unknown date'} · ₹${record.amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            result.duplicateReason ?? 'This row needs your input.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (_canCorrectDirection) ...[
                _DecisionButton(
                  label: 'Income',
                  selected: decision == CsvRowDecision.markIncome,
                  onTap: () => onDecision(CsvRowDecision.markIncome),
                ),
                _DecisionButton(
                  label: 'Expense',
                  selected: decision == CsvRowDecision.markExpense,
                  onTap: () => onDecision(CsvRowDecision.markExpense),
                ),
              ],
              _DecisionButton(
                label: 'Skip',
                selected: decision == CsvRowDecision.skip,
                onTap: () => onDecision(CsvRowDecision.skip),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.accent.withValues(alpha: 0.15) : null,
        side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: Text(label, style: TextStyle(color: selected ? AppColors.accent : AppColors.textSecondary)),
    );
  }
}

class _InvalidRowCard extends StatelessWidget {
  const _InvalidRowCard({required this.description, required this.reason});
  final String description;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(reason, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger)),
        ],
      ),
    );
  }
}
