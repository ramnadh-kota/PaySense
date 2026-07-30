import 'package:flutter/material.dart';
import 'package:paysense/core/constants/app_colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final Color? color;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius ?? 24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius ?? 24),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color ?? AppColors.surface,
            borderRadius: BorderRadius.circular(radius ?? 24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
