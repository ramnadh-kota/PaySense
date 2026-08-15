import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:uuid/uuid.dart';

/// Suggested account types for the type selector below — the underlying
/// `Wallet.type` field is a free string with no enum/controlled vocabulary
/// anywhere in the app, so this list is a curated set of sensible defaults
/// (matching real-world account kinds), not an exhaustive constraint.
const List<String> walletTypeOptions = [
  'Bank',
  'Cash',
  'Savings',
  'Credit Card',
  'UPI/Wallet',
];

/// Creates a new wallet, or edits name/bank/type of an existing one.
///
/// Editing never changes [Wallet.id], [Wallet.createdAt], or the balance
/// fields — those are preserved exactly so existing transactions/transfers
/// referencing this wallet stay valid and its balance history stays
/// accurate.
class AddEditWalletScreen extends ConsumerStatefulWidget {
  const AddEditWalletScreen({super.key, this.wallet});

  /// Null to create a new wallet; non-null to edit an existing one.
  final Wallet? wallet;

  @override
  ConsumerState<AddEditWalletScreen> createState() => _AddEditWalletScreenState();
}

class _AddEditWalletScreenState extends ConsumerState<AddEditWalletScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _openingBalanceController;
  late String _type;
  bool _saving = false;

  bool get _isEditing => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    final wallet = widget.wallet;
    _nameController = TextEditingController(text: wallet?.name ?? '');
    _bankNameController = TextEditingController(text: wallet?.bankName ?? '');
    _openingBalanceController = TextEditingController(
      text: wallet == null ? '' : wallet.openingBalance.toStringAsFixed(0),
    );
    _type = wallet?.type ?? walletTypeOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an account name.')));
      return;
    }

    final existing = widget.wallet;
    final Wallet wallet;
    if (existing != null) {
      wallet = existing.copyWith(
        name: name,
        bankName: _bankNameController.text.trim(),
        type: _type,
      );
    } else {
      final openingBalance = double.tryParse(_openingBalanceController.text.trim()) ?? 0;
      if (openingBalance < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening balance cannot be negative.')),
        );
        return;
      }
      wallet = Wallet(
        id: const Uuid().v4(),
        name: name,
        bankName: _bankNameController.text.trim(),
        type: _type,
        openingBalance: openingBalance,
        currentBalance: openingBalance,
        createdAt: DateTime.now(),
      );
    }

    setState(() => _saving = true);
    if (existing != null) {
      await WalletRepository.instance.update(wallet);
    } else {
      await WalletRepository.instance.add(wallet);
    }
    await ref.read(walletsProvider.notifier).reload();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(_isEditing ? 'Edit Account' : 'Add Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(context, label: 'Account name', controller: _nameController),
              const SizedBox(height: 12),
              _field(context, label: 'Bank name (optional)', controller: _bankNameController),
              const SizedBox(height: 16),
              Text(
                'Account type',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: walletTypeOptions.map((type) {
                  return ChoiceChip(
                    label: Text(type),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                    selectedColor: AppColors.lightTeal,
                    labelStyle: TextStyle(
                      color: _type == type ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.surface,
                  );
                }).toList(),
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                _field(
                  context,
                  label: 'Opening balance',
                  controller: _openingBalanceController,
                  prefixText: '₹ ',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(_isEditing ? 'Save Changes' : 'Add Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    String? prefixText,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
