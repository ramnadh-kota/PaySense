import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/budget.dart';
import 'package:paysense/shared/models/goal.dart';
import 'package:paysense/shared/models/pain_of_paying_result.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/budget_provider.dart';
import 'package:paysense/shared/providers/financial_planning_provider.dart';
import 'package:paysense/shared/providers/goal_provider.dart';
import 'package:paysense/shared/providers/safe_to_spend_provider.dart';
import 'package:paysense/shared/providers/transaction_provider.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';
import 'package:paysense/shared/utils/pain_of_paying_engine.dart';
import 'package:paysense/shared/utils/spending_decision_calculator.dart';
import 'package:paysense/shared/widgets/decision_coach_dialog.dart';
import 'package:paysense/shared/widgets/pain_of_paying_sheet.dart';
import 'package:paysense/shared/widgets/wallet_selector_field.dart';
import 'package:paysense/features/wallet/presentation/add_edit_wallet_screen.dart';
import 'package:uuid/uuid.dart';

/// A premium, fast-entry expense capture screen.
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedCategory;
  String? _selectedWalletId;

  /// PAIN-OF-PAYING AUDIT — "Save Expense" had no re-entrancy guard: a
  /// rapid double-tap could fire `_handleSave` twice before the first
  /// call's `await showDialog` (Decision Coach) even painted, stacking two
  /// dialogs and risking two saved transactions if both got confirmed.
  /// Guards the entire async save, not just the repository write, so a
  /// double-tap can never open a second Decision Coach dialog either.
  bool _isSaving = false;

  final List<String> _categories = const <String>[
    'Groceries',
    'Dining',
    'Shopping',
    'Travel',
    'Bills',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave(List<Wallet> wallets) async {
    // See _isSaving's doc comment — must be the very first thing checked,
    // before even validation, so a double-tap can never start a second
    // concurrent save (and therefore never open a second Decision Coach
    // dialog or create a second transaction).
    if (_isSaving) return;

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount.')));
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    final walletId = _selectedWalletId;
    if (walletId == null || wallets.every((w) => w.id != walletId)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please choose an account.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Phase 6C Spending Decision Integration: connects SpendingLimitCalculator,
      // AllowanceCalculator, AffordabilityCalculator, and PurchaseImpactCalculator
      // into the Decision Coach dialog before confirming a purchase.
      final planning = ref.read(financialPlanningProvider);
      final goals = ref.read(goalsProvider).value ?? const <Goal>[];
      final transactions = ref.read(transactionsProvider).value ?? const <Transaction>[];
      final budgets = ref.read(budgetsProvider).value ?? const <Budget>[];
      final safeToSpend = ref.read(safeToSpendProvider);
      final now = DateTime.now();

      final decision = SpendingDecisionCalculator.evaluate(
        SpendingDecisionInput(
          amount: amount,
          categoryId: _selectedCategory ?? 'uncategorized',
          itemDescription: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          safeToSpend: safeToSpend,
          planning: planning,
          budgets: budgets,
          goals: goals,
          transactions: transactions,
          now: now,
        ),
      );

      if (!mounted) {
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return DecisionCoachDialog(
            amount: decision.amount,
            emiPercentage: decision.impact.emiPercentage,
            savingsGoalPercentage: decision.impact.savingsGoalPercentage,
            comparisonMessage: decision.impact.perspectiveMessage,
            categorySpendingLimit: decision.categorySpendingLimit,
            allowance: decision.allowance,
            verdictLine: decision.verdictLine,
            guidanceLine: decision.guidanceLine,
          );
        },
      );

      if (confirmed != true) {
        return;
      }

      final transaction = Transaction(
        id: const Uuid().v4(),
        title: _selectedCategory ?? 'Expense',
        amount: amount,
        categoryId: _selectedCategory ?? 'uncategorized',
        // The real Wallet.id, never a display label — see
        // wallet_account_resolver.dart for why this matters.
        accountId: walletId,
        transactionType: 'expense',
        paymentMethod: 'card',
        note: _noteController.text.trim(),
        createdAt: DateTime.now(),
      );

      await TransactionRepository.instance.add(transaction);
      await WalletRepository.instance.decreaseBalance(walletId, amount);
      await ref.read(walletsProvider.notifier).reload();
      await ref.read(transactionsProvider.notifier).reload();

      if (!mounted) {
        return;
      }

      // PAIN-OF-PAYING ENGINE: a lighter-touch, non-blocking follow-up to
      // the "Think Before You Pay" dialog above — awareness after the
      // fact, never a second confirm/cancel gate. Only shown when there's
      // genuinely something to say (level != low), so a routine small
      // purchase never interrupts the flow.
      final painOfPaying = PainOfPayingEngine.evaluate(
        amount: amount,
        categoryId: transaction.categoryId,
        transactions: ref.read(transactionsProvider).value ?? const <Transaction>[],
        budgets: budgets,
        goals: goals,
        now: DateTime.now(),
        monthlyEmiBurden: planning.debt.monthlyEmiBurden,
        safeToSpend: safeToSpend,
        excludeTransactionId: transaction.id,
      );

      if (!mounted) {
        return;
      }
      if (painOfPaying.level != PainOfPayingLevel.low) {
        await showPainOfPayingSheet(context, painOfPaying);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsProvider);
    final wallets = (walletsAsync.value ?? const <Wallet>[])
        .where((w) => !w.isArchived)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: true,
        title: const Text('Add Expense'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Expense',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Capture the expense in seconds.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                context: context,
                label: 'Category',
                value: _selectedCategory,
                items: _categories,
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (wallets.isEmpty)
                NoWalletsMessage(
                  message: 'Add a wallet first to record where this expense comes from.',
                  onAddWallet: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddEditWalletScreen()),
                  ),
                )
              else
                WalletSelectorField(
                  label: 'Pay from',
                  wallets: wallets,
                  selectedWalletId: _selectedWalletId,
                  onChanged: (value) => setState(() => _selectedWalletId = value),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
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
                  onPressed: _isSaving ? null : () => _handleSave(wallets),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required BuildContext context,
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 8,
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
