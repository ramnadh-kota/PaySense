import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/fun_funds_group.dart';
import 'package:paysense/shared/providers/fun_funds_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/fun_funds_calculator.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class FunFundsScreen extends ConsumerWidget {
  const FunFundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(funFundsResultProvider);
    final groupsAsync = ref.watch(funFundsGroupsProvider);
    final currencyCode = ref.watch(userProfileProvider).value?.currency.isNotEmpty == true
        ? ref.watch(userProfileProvider).value!.currency
        : 'INR';
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: CurrencyFormatter.symbolFor(currencyCode),
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Fun Funds'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            if (!result.hasSufficientData)
              _EmptyState(
                icon: Icons.celebration_outlined,
                message: 'Add your accounts to see how much you can safely '
                    'set aside for fun.',
              )
            else ...[
              _HeroSection(result: result, currencyFormatter: currencyFormatter),
              const SizedBox(height: 20),
              _BreakdownSection(result: result, currencyFormatter: currencyFormatter),
              const SizedBox(height: 20),
              const _DisclaimerCard(),
            ],
            const SizedBox(height: 28),
            _GroupsSection(groupsAsync: groupsAsync),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.result, required this.currencyFormatter});

  final FunFundsResult result;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    final isZeroOrShort = result.funFunds <= 0;
    return AppCard(
      padding: const EdgeInsets.all(24),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fun Funds',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            currencyFormatter.format(result.funFunds),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isZeroOrShort
                ? 'Your current commitments leave no safe discretionary '
                    'amount right now — focus on those first.'
                : 'Money you can enjoy without feeling guilty — your bills, '
                    'budgets, goals, and a safety buffer are already '
                    'accounted for.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({required this.result, required this.currencyFormatter});

  final FunFundsResult result;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How this was calculated',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _Row(label: 'Safe to Spend', value: currencyFormatter.format(result.safeToSpend)),
          const SizedBox(height: 10),
          _Row(
            label: 'Budget commitments',
            value: '-${currencyFormatter.format(result.budgetCommitments)}',
            valueColor: AppColors.danger,
          ),
          const SizedBox(height: 10),
          _Row(
            label: 'Goal contributions',
            value: '-${currencyFormatter.format(result.goalContributions)}',
            valueColor: AppColors.danger,
          ),
          const SizedBox(height: 10),
          _Row(
            label: 'Safety buffer (10%)',
            value: '-${currencyFormatter.format(result.safetyBuffer)}',
            valueColor: AppColors.danger,
          ),
          if (result.isShortfall) ...[
            const Divider(height: 24),
            _Row(
              label: 'Short by',
              value: currencyFormatter.format(result.shortfall),
              valueColor: AppColors.danger,
              bold: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor, this.bold = false});

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Text(
      'An app-generated estimate based on the financial information '
      'currently recorded in PaySense — never a recommendation to spend '
      'more than feels comfortable.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _GroupsSection extends ConsumerWidget {
  const _GroupsSection({required this.groupsAsync});

  final AsyncValue<List<FunFundsGroup>> groupsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = groupsAsync.value ?? const <FunFundsGroup>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Friends & Groups',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CreateGroupScreen()),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New group'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No groups yet. Create one to split a trip, a flat, or an '
              'outing with friends — equal split, settlement tracking, no '
              'real money moves through PaySense.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          )
        else
          ...groups.map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GroupTile(group: group),
            ),
          ),
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final FunFundsGroup group;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => GroupDetailScreen(groupId: group.id)),
        );
      },
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.groups_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${group.memberNames.length} member${group.memberNames.length == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
