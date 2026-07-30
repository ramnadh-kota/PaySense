import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/widgets/app_card.dart';
import 'widgets/asset_card.dart';
import 'widgets/bank_account_card.dart';
import 'widgets/credit_card_widget.dart';
import 'widgets/investment_card.dart';
import 'widgets/section_header.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
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
                          'My Wallet',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Net worth overview',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AppCard(
                padding: const EdgeInsets.all(24),
                color: AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total Net Worth',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '+8.2%',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₹1,24,560',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryPill(title: 'Assets', value: '₹1,68,000'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryPill(title: 'Liabilities', value: '₹43,440'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const WalletSectionHeader(title: 'Bank Accounts'),
              const SizedBox(height: 12),
              const BankAccountCard(
                bankName: 'HDFC Bank',
                accountType: 'Savings Account',
                balance: '₹82,430',
                lastUpdated: '2 mins ago',
                icon: Icons.account_balance_rounded,
              ),
              const SizedBox(height: 12),
              const BankAccountCard(
                bankName: 'ICICI Bank',
                accountType: 'Salary Account',
                balance: '₹48,200',
                lastUpdated: '10 mins ago',
                icon: Icons.account_balance_wallet_rounded,
              ),
              const SizedBox(height: 12),
              const BankAccountCard(
                bankName: 'SBI',
                accountType: 'Current Account',
                balance: '₹24,900',
                lastUpdated: '1 hr ago',
                icon: Icons.business_rounded,
              ),
              const SizedBox(height: 24),
              const WalletSectionHeader(title: 'Credit Cards'),
              const SizedBox(height: 12),
              const CreditCardWidget(
                bankName: 'HDFC Credit Card',
                cardNumber: '5624',
                availableLimit: '₹85,000',
                cardColor: AppColors.primary,
                creditLimit: '₹1,20,000',
              ),
              const SizedBox(height: 12),
              const CreditCardWidget(
                bankName: 'ICICI Amazon Pay',
                cardNumber: '8845',
                availableLimit: '₹40,000',
                cardColor: Color(0xFF111827),
                creditLimit: '₹60,000',
              ),
              const SizedBox(height: 24),
              const WalletSectionHeader(title: 'UPI Accounts'),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(child: InvestmentCard(title: 'Google Pay', value: '₹12,340', subtitle: 'Linked', icon: Icons.phone_android_rounded)),
                  SizedBox(width: 12),
                  Expanded(child: InvestmentCard(title: 'PhonePe', value: '₹8,760', subtitle: 'Linked', icon: Icons.payment_rounded)),
                  SizedBox(width: 12),
                  Expanded(child: InvestmentCard(title: 'Paytm', value: '₹6,540', subtitle: 'Linked', icon: Icons.wallet_rounded)),
                ],
              ),
              const SizedBox(height: 24),
              const WalletSectionHeader(title: 'Investments'),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(child: InvestmentCard(title: 'Mutual Funds', value: '₹36,500', subtitle: 'Growth +12%', icon: Icons.trending_up_rounded)),
                  SizedBox(width: 12),
                  Expanded(child: InvestmentCard(title: 'Stocks', value: '₹21,800', subtitle: 'Active', icon: Icons.show_chart_rounded)),
                  SizedBox(width: 12),
                  Expanded(child: InvestmentCard(title: 'FD', value: '₹15,000', subtitle: 'Safe', icon: Icons.savings_rounded)),
                ],
              ),
              const SizedBox(height: 24),
              const WalletSectionHeader(title: 'Assets'),
              const SizedBox(height: 12),
              Column(
                children: const [
                  AssetCard(title: 'Gold', value: '₹18,000', icon: Icons.scatter_plot_rounded),
                  SizedBox(height: 12),
                  AssetCard(title: 'Real Estate', value: '₹42,00,000', icon: Icons.home_rounded),
                  SizedBox(height: 12),
                  AssetCard(title: 'Cash', value: '₹8,400', icon: Icons.money_rounded),
                ],
              ),
              const SizedBox(height: 24),
              const WalletSectionHeader(title: 'Recent Activity'),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: const [
                    _ActivityRow(title: 'UPI Received', subtitle: 'From Riya', amount: '+₹1,200'),
                    _ActivityRow(title: 'Card Payment', subtitle: 'Amazon', amount: '-₹1,299'),
                    _ActivityRow(title: 'Transfer', subtitle: 'To savings', amount: '-₹5,000'),
                    _ActivityRow(title: 'Investment', subtitle: 'Mutual fund SIP', amount: '-₹2,000'),
                    _ActivityRow(title: 'Cashback', subtitle: 'PhonePe reward', amount: '+₹150'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryPill({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;

  const _ActivityRow({required this.title, required this.subtitle, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}
