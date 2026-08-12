import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            builder: (context, child) =>
                AppLockGate(child: child ?? const SizedBox.shrink()),
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
