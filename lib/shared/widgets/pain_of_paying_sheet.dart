import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/pain_of_paying_result.dart';

/// PAIN-OF-PAYING ENGINE — a compact, non-blocking awareness sheet shown
/// AFTER a transaction is saved (the "Think Before You Pay" dialog
/// already gates BEFORE save — this is a lighter-touch follow-up, never
/// another confirm/cancel gate). Reuses the app's existing card/sheet
/// styling; never shames — copy stays neutral regardless of [result.level].
Future<void> showPainOfPayingSheet(BuildContext context, PainOfPayingResult result) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _PainOfPayingSheetContent(result: result),
  );
}

class _PainOfPayingSheetContent extends StatelessWidget {
  const _PainOfPayingSheetContent({required this.result});
  final PainOfPayingResult result;

  Color _levelColor() {
    switch (result.level) {
      case PainOfPayingLevel.veryHigh:
        return AppColors.danger;
      case PainOfPayingLevel.high:
        return AppColors.warning;
      case PainOfPayingLevel.moderate:
        return AppColors.primary;
      case PainOfPayingLevel.low:
        return AppColors.success;
    }
  }

  String _levelLabel() {
    switch (result.level) {
      case PainOfPayingLevel.veryHigh:
        return 'Worth a closer look';
      case PainOfPayingLevel.high:
        return 'Worth noting';
      case PainOfPayingLevel.moderate:
        return 'Good to know';
      case PainOfPayingLevel.low:
        return 'All good';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    _levelLabel(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              result.headline,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            for (final signal in result.signals) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  signal.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            ],
            if (result.suggestedAction != null) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                child: Text(
                  result.suggestedAction!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
