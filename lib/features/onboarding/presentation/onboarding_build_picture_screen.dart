import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/widgets/app_card.dart';

const List<(IconData, String, String)> _buildingBlocks = [
  (Icons.account_balance_wallet_rounded, 'Wallet', 'Where your money lives — bank accounts, cash, cards.'),
  (Icons.arrow_downward_rounded, 'Income', 'What comes in, so PaySense knows your real starting point.'),
  (Icons.arrow_upward_rounded, 'Expenses', "What goes out — the more you add, the sharper your picture."),
  (Icons.account_balance_rounded, 'Loans', 'Any EMIs or debt, so we can factor them in honestly.'),
  (Icons.flag_rounded, 'Goals', "What you're working toward."),
];

/// CONSUMER MONETIZATION FOUNDATION (PHASE 1, Screen 4) — explains what the
/// user CAN add, without forcing them to complete everything before seeing
/// value (PHASE 8/12's "don't force completion" rule).
class OnboardingBuildPictureScreen extends ConsumerStatefulWidget {
  const OnboardingBuildPictureScreen({super.key});

  @override
  ConsumerState<OnboardingBuildPictureScreen> createState() => _OnboardingBuildPictureScreenState();
}

class _OnboardingBuildPictureScreenState extends ConsumerState<OnboardingBuildPictureScreen> {
  Future<void> _continue() async {
    await AppSettingsRepository.instance.setOnboardingBuildPictureAcknowledged();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.financialSnapshot, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Let's build your financial picture",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You don't have to add everything now — even a little data helps PaySense start understanding your money.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: _buildingBlocks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final (icon, title, subtitle) = _buildingBlocks[index];
                    return AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.lightTeal, borderRadius: BorderRadius.circular(14)),
                            child: Icon(icon, color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  subtitle,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('See my Financial Snapshot'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
