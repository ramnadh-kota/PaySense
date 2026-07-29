import 'package:flutter/material.dart';
import 'features/splash/splash_screen.dart';

void main() {
  runApp(const PaySenseApp());
}

class PaySenseApp extends StatelessWidget {
  const PaySenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PaySense',
      home: const SplashScreen(),
    );
  }
}