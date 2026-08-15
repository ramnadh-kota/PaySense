import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';

/// Moves money between two of the user's own wallets. This is intentionally
/// separate from Add Expense/Add Income: a transfer is recorded via
/// [WalletsNotifier.transfer], which tags both legs `transactionType:
/// 'transfer'` so it is never counted as income or an expense anywhere
/// (Analytics, Financial Health, Safe-to-Spend, Cash Flow, Monthly Review).
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _fromWalletId;
  String? _toWalletId;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Wallet> wallets) async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (_fromWalletId == null || _toWalletId == null) {
      _showMessage('Choose both accounts to transfer between.');
      return;
    }
    if (_fromWalletId == _toWalletId) {
      _showMessage('Choose two different accounts.');
      return;
    }
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid amount greater than zero.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(walletsProvider.notifier).transfer(
        fromWalletId: _fromWalletId!,
        toWalletId: _toWalletId!,
        amount: amount,
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on WalletTransferException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Transfer'),
      ),
      body: SafeArea(
        child: walletsAsync.when(
          data: (allWallets) {
            final wallets = allWallets.where((w) => !w.isArchived).toList();
            if (wallets.length < 2) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'You need at least two accounts to transfer money between them.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }

            final fromWalletMatches = wallets.where((w) => w.id == _fromWalletId);
            final fromWallet = fromWalletMatches.isEmpty ? null : fromWalletMatches.first;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _walletDropdown(
                    context,
                    label: 'From account',
                    wallets: wallets,
                    value: _fromWalletId,
                    onChanged: (value) => setState(() => _fromWalletId = value),
                  ),
                  if (fromWallet != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        'Available: ₹${fromWallet.currentBalance.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _walletDropdown(
                    context,
                    label: 'To account',
                    wallets: wallets.where((w) => w.id != _fromWalletId).toList(),
                    value: _toWalletId,
                    onChanged: (value) => setState(() => _toWalletId = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : () => _submit(wallets),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Transfer'),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load accounts right now.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _walletDropdown(
    BuildContext context, {
    required String label,
    required List<Wallet> wallets,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final validValue = wallets.any((w) => w.id == value) ? value : null;
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
          return DropdownMenuItem<String>(value: wallet.id, child: Text(wallet.name));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
