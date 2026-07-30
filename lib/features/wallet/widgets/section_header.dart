import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';

class WalletSectionHeader extends StatelessWidget {
  final String title;

  const WalletSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
    );
  }
}
