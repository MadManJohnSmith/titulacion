import 'package:flutter/material.dart';

/// Colores tomados del diseño de LoboApp.
class LoboColors {
  static const navy = Color(0xFF0B233A);
  static const deepBlue = Color(0xFF002D4C);
  static const steelBlue = Color(0xFF496D83);
  static const inkBlue = Color(0xFF083b5b);
  static const teal = Color(0xFF033d5e);
  static const parchment = Color(0xFFD9B98A);
  static const parchmentLight = Color(0xFFEBD3B0);
  static const ink = Color(0xFF032433);
  static const gold = Color(0xFFE0A93B);
}

ThemeData buildLoboTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: LoboColors.steelBlue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: LoboColors.steelBlue,
      secondary: LoboColors.gold,
      surface: LoboColors.navy,
    ),
    scaffoldBackgroundColor: LoboColors.navy,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    // Tipografías del diseño (ver la sección `fonts:` de pubspec.yaml).
    textTheme: base.textTheme.apply(
      fontFamily: 'Poppins',
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: LoboColors.deepBlue.withValues(alpha: 0.85),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: LoboColors.ink,
      contentTextStyle: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Tipografía de display del diseño: para títulos de pantalla y pergaminos.
const loboDisplay = TextStyle(
  fontFamily: 'Bungee',
  letterSpacing: 0.5,
);

/// Texto corrido del diseño, más leggible que Poppins para párrafos largos.
const loboCuerpo = TextStyle(
  fontFamily: 'Tajawal',
  letterSpacing: 0.2,
);
