import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/providers/app_settings_provider.dart';
import 'package:paysense/shared/providers/auth_provider.dart';
import 'package:paysense/shared/providers/sms_automation_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) {
      return;
    }

    // Fire-and-forget: flushes whatever the native SMS receiver queued up
    // while the app wasn't running. Never awaited/blocking — a failure or
    // slow platform-channel round trip here must never delay app startup.
    // Only runs at all once the user has explicitly turned this on.
    if (AppSettingsRepository.instance.smsAutomationEnabled()) {
      unawaited(_flushPendingSms());
    }

    final isFirstLaunch = await ref.read(isFirstLaunchProvider.future);

    if (!mounted) {
      return;
    }

    if (isFirstLaunch) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      return;
    }

    final authState = await ref.read(authProvider.future);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      authState.isAuthenticated ? AppRoutes.navigation : AppRoutes.login,
    );
  }

  Future<void> _flushPendingSms() async {
    try {
      await ref.read(smsTransactionProcessorProvider).processPending();
    } catch (_) {
      // Best-effort — a failed flush here is retried the next time the
      // app initializes; it must never block or crash app startup.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 88,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'PaySense',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI powered personal finance',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
