import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Core palette
  static const Color accent = Color(0xFF6C63FF);
  static const Color accentGreen = Color(0xFF34C759);
  static const Color accentOrange = Color(0xFFFF9F0A);
  static const Color accentRed = Color(0xFFFF453A);
  static const Color accentBlue = Color(0xFF0A84FF);

  static const Color priorityHigh = Color(0xFFFF453A);
  static const Color priorityMedium = Color(0xFFFF9F0A);
  static const Color priorityLow = Color(0xFF34C759);

  static const Map<String, Color> categoryColors = {
    'cleaning': Color(0xFF0A84FF),
    'cooking': Color(0xFFFF9F0A),
    'dishwashing': Color(0xFF5AC8FA),
    'laundry': Color(0xFFBF5AF2),
    'gardening': Color(0xFF34C759),
    'shopping': Color(0xFFFF453A),
    'other': Color(0xFF8E8E93),
  };

  // Additional accents
  static const Color accentLight = Color(0xFF9B59FF);  // gradients

  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textMuted = Color(0xFF888888);

  // Border
  static const Color border = Color(0x0AFFFFFF); // white 4%

  // Dark surfaces — 3 elevation levels
  static const Color bg = Color(0xFF0F0F14);
  static const Color surfaceLow = Color(0xFF151519);
  static const Color surface = Color(0xFF1C1C24);
  static const Color surfaceHigh = Color(0xFF252533);
  static const Color surfaceVariant = Color(0xFF2A2A40);
  static const Color _bg = bg;
  static const Color _card = surface;
  static const Color _cardLight = surfaceHigh;

  // Border radius scale
  static const double radiusS = 8;   // badges, small chips
  static const double radiusM = 14;  // buttons, inputs, icons
  static const double radiusL = 18;  // cards, modals
  static const double radiusXL = 24; // pills, nav, filter chips

  // Typography scale
  static const double fontXS = 10;   // badges, tiny labels
  static const double fontS = 12;    // metadata, captions
  static const double fontM = 14;    // body, subtitles
  static const double fontL = 16;    // section headers, buttons
  static const double fontXL = 20;   // screen titles, names
  static const double fontXXL = 26;  // hero numbers

  // Shadows
  static List<BoxShadow> get shadowSmall => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4, offset: const Offset(0, 1)),
  ];
  static List<BoxShadow> get shadowMedium => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 3)),
  ];
  static List<BoxShadow> get shadowLarge => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 6)),
  ];

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        surface: _card,
        onSurface: Colors.white,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: _bg,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: accent, width: 1.5)),
        filled: true,
        fillColor: _card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: TextStyle(color: Colors.grey.shade600),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        backgroundColor: _card,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: Colors.grey.shade700),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // Keep lightTheme pointing to darkTheme since user removed light mode
  static ThemeData get lightTheme => darkTheme;
}
