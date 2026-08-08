import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;
    final fullName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : 'Guest';
    final subtitle = profile?.occupation.isNotEmpty == true
        ? profile!.occupation
        : 'PaySense Member';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (profile != null) ...[
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: profile.email,
                      ),
                      const SizedBox(height: 12),
                      _ProfileRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: profile.phone,
                      ),
                      const SizedBox(height: 12),
                      _ProfileRow(
                        icon: Icons.cake_outlined,
                        label: 'Date of birth',
                        value: profile.dateOfBirth == null
                            ? ''
                            : '${profile.dateOfBirth!.day}/${profile.dateOfBirth!.month}/${profile.dateOfBirth!.year}',
                      ),
                      const SizedBox(height: 12),
                      _ProfileRow(
                        icon: Icons.wc_rounded,
                        label: 'Gender',
                        value: profile.gender,
                      ),
                      const SizedBox(height: 12),
                      _ProfileRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Monthly income',
                        value: profile.monthlyIncome > 0
                            ? '${profile.currency} ${profile.monthlyIncome.toStringAsFixed(0)}'
                            : '',
                      ),
                      const SizedBox(height: 12),
                      _ProfileRow(
                        icon: Icons.public_rounded,
                        label: 'Country',
                        value: profile.country,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not set' : value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
