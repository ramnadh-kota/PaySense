import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/services/analytics_service.dart';
import 'package:paysense/shared/utils/financial_data_exporter.dart';
import 'package:share_plus/share_plus.dart';

/// DATA EXPORT / BACKUP — PART J. Local-only export with an explicit
/// scope choice and confirmation before sharing. Never uploads anything
/// itself — [SharePlus] only opens the OS share sheet; the destination is
/// entirely the user's choice.
class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

const _scopeLabels = {
  ExportScope.transactions: 'Transactions',
  ExportScope.wallets: 'Wallets',
  ExportScope.budgets: 'Budgets',
  ExportScope.goals: 'Goals',
  ExportScope.loans: 'Loans',
  ExportScope.recurringTransactions: 'Subscriptions & recurring payments',
  ExportScope.bills: 'Bills',
  ExportScope.financialSummary: 'Financial summaries',
};

class _DataExportScreenState extends State<DataExportScreen> {
  final Set<ExportScope> _selected = {};
  ExportFormat _format = ExportFormat.json;
  bool _isExporting = false;

  // CSV format only ever applies to a single scope — enforced below by
  // disabling the CSV option whenever more than one is selected.
  bool get _canUseCsv => _selected.length <= 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Export My Data'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Your data stays on your device until you choose where to share it.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Text(
              'What would you like to export?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            for (final scope in _scopeLabels.keys)
              CheckboxListTile(
                value: _selected.contains(scope),
                title: Text(_scopeLabels[scope]!, style: TextStyle(color: AppColors.textPrimary)),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _selected.add(scope);
                  } else {
                    _selected.remove(scope);
                  }
                  if (!_canUseCsv) _format = ExportFormat.json;
                }),
              ),
            OutlinedButton(
              onPressed: () => setState(() => _selected.addAll(_scopeLabels.keys)),
              child: const Text('Select everything'),
            ),
            const SizedBox(height: 20),
            Text(
              'Format',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('JSON'),
                  selected: _format == ExportFormat.json,
                  onSelected: (_) => setState(() => _format = ExportFormat.json),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('CSV'),
                  selected: _format == ExportFormat.csv,
                  onSelected: _canUseCsv ? (_) => setState(() => _format = ExportFormat.csv) : null,
                ),
              ],
            ),
            if (!_canUseCsv)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'CSV export is available for one data type at a time.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty || _isExporting ? null : () => _handleExportAndShare(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isExporting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Export'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExportAndShare(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share this export?'),
        content: Text(
          'This will create a ${_format == ExportFormat.json ? 'JSON' : 'CSV'} file with '
          '${_selected.length} data section${_selected.length == 1 ? '' : 's'} and let you choose where to send it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Continue')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isExporting = true);
    try {
      AnalyticsService.instance.log(
        AnalyticsEvent.dataExportRequested,
        metadata: {'scopeCount': _selected.length, 'format': _format.name},
      );

      final path = _format == ExportFormat.json
          ? await FinancialDataExporter.instance.exportScopedToJsonFile(_selected)
          : await FinancialDataExporter.instance.exportScopedToCsvFile(_selected.first);

      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], subject: 'PaySense data export'),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("We couldn't prepare the export. Please try again.")),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
