import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/routes/app_router.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../features/splash/splash_screen.dart';

class PaySenseApp extends StatelessWidget {
  const PaySenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PaySense',
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const SplashScreen(),
      ),
    );
  }
}
