import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'package:paysense/shared/widgets/section_header.dart';
import 'widgets/credit_card_widget.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wallet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 16),
              AppCard(
                color: AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total net worth',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹1,24,560',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Bank accounts'),
              const SizedBox(height: 16),
              _bankCard(bank: 'HDFC Bank', type: 'Savings account', amount: '₹82,430'),
              const SizedBox(height: 16),
              _bankCard(bank: 'SBI Bank', type: 'Salary account', amount: '₹28,950'),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Credit cards'),
              const SizedBox(height: 16),
              const CreditCardWidget(
                bankName: 'HDFC Millennia',
                cardNumber: '5624',
                availableLimit: '₹85,000',
                cardColor: AppColors.primary,
              ),
              const CreditCardWidget(
                bankName: 'Slice Card',
                cardNumber: '8845',
                availableLimit: '₹40,000',
                cardColor: Color(0xFF111827),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _bankCard({
    required String bank,
    required String type,
    required String amount,
  }) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: const Icon(Icons.account_balance, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bank,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  type,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
