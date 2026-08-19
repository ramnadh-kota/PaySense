import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/routes/app_router.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../features/app_lock/presentation/app_lock_gate.dart';
import '../features/splash/splash_screen.dart';
import '../shared/models/app_settings.dart';
import '../shared/providers/settings_provider.dart';

class PaySenseApp extends StatelessWidget {
  const PaySenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          final appThemeMode =
              ref.watch(settingsProvider).value?.themeMode ??
              AppThemeMode.system;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'PaySense',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _toThemeMode(appThemeMode),
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: const SplashScreen(),
            builder: (context, child) {
              // AppColors' color getters read this to resolve
              // light/dark — the single choke point that makes the whole
              // app dark-mode-reactive without every screen needing to
              // switch from `AppColors.x` to `Theme.of(context)`. The
              // ValueKey forces a full subtree remount on a brightness
              // flip so screens that don't otherwise depend on Theme (and
              // so wouldn't normally rebuild) still repaint with the new
              // colors immediately, not just on next navigation.
              final brightness = Theme.of(context).brightness;
              AppColors.currentBrightness = brightness;
              return KeyedSubtree(
                key: ValueKey(brightness),
                child: AppLockGate(child: child ?? const SizedBox.shrink()),
              );
            },
          );
        },
      ),
    );
  }

  ThemeMode _toThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
