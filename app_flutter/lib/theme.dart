import 'package:flutter/material.dart';

/// Design system de Samou Mbeymi : agricole, premium et lisible.
class AppColors {
  static const primary = Color(0xFF174A3A);
  static const primaryLight = Color(0xFF2D6A53);
  static const primaryDark = Color(0xFF0E3026);
  static const accent = Color(0xFFF2B84B);
  static const accentSoft = Color(0xFFFFF1CF);
  static const success = Color(0xFF2E8B57);
  static const successSoft = Color(0xFFE6F4EC);
  static const loss = Color(0xFFD05A3A);
  static const lossSoft = Color(0xFFFBE8E2);
  static const bg = Color(0xFFF6F7F2);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF17221D);
  static const inkSoft = Color(0xFF64736B);
  static const border = Color(0xFFE3E9E4);
}

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    error: AppColors.loss,
  ),
  fontFamily: 'Roboto',
  visualDensity: VisualDensity.standard,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(22)),
      side: BorderSide(color: AppColors.border),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.7),
    ),
    labelStyle: const TextStyle(color: AppColors.inkSoft),
    floatingLabelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size.fromHeight(54),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      minimumSize: const Size.fromHeight(50),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 72,
    backgroundColor: Colors.white,
    elevation: 0,
    indicatorColor: AppColors.successSoft,
    labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
      fontSize: 11,
      fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
      color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.inkSoft,
    )),
  ),
  textTheme: const TextTheme(
    displaySmall: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: -1.2),
    headlineMedium: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: -0.7),
    titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
    titleMedium: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
    bodyLarge: TextStyle(color: AppColors.ink, height: 1.45),
    bodyMedium: TextStyle(color: AppColors.inkSoft, height: 1.45),
  ),
);
