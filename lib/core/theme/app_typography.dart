import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static TextTheme textTheme = GoogleFonts.poppinsTextTheme(
    const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w700),
      displayMedium: TextStyle(fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(fontWeight: FontWeight.w500),
      bodySmall: TextStyle(fontWeight: FontWeight.w400),
    ),
  );
}
