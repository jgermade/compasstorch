import 'package:flutter/material.dart';

/// Colores compartidos por los dos temas de la aplicación.
class AppColors {
  const AppColors._();

  /// Acento del control de linterna (eje vertical del mando).
  static const Color torch = Color(0xFFFFB020);

  /// Acento del modo faro (eje horizontal del mando).
  static const Color beacon = Color(0xFF00B8D4);

  /// Superficie del mando: un plástico neutro, sin el tinte del color de
  /// acento que arrastra `surfaceContainerHighest`.
  static const Color darkPlastic = Color(0xFF171C22);
  static const Color lightPlastic = Color(0xFFDBE0E5);

  static const Color darkBackground = Color(0xFF07090C);
  static const Color darkSurface = Color(0xFF131A22);
  static const Color darkOutline = Color(0xFF2A3644);
}

/// Tema por defecto: oscuro, pensado para no deslumbrar de noche.
ThemeData buildDarkTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.torch,
        brightness: Brightness.dark,
      ).copyWith(
        surface: AppColors.darkBackground,
        primary: AppColors.torch,
        secondary: AppColors.beacon,
        outline: AppColors.darkOutline,
      );

  return _base(scheme)
      .copyWith(scaffoldBackgroundColor: AppColors.darkBackground);
}

/// Tema del "modo faro": blanco puro para que la pantalla emita el máximo
/// de luz posible cuando se combina con el brillo al 100 %.
ThemeData buildBeaconTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.beacon,
        brightness: Brightness.light,
      ).copyWith(
        surface: Colors.white,
        onSurface: const Color(0xFF10161C),
        // Mismos papeles que en el tema oscuro, oscurecidos para que contrasten
        // sobre blanco: primary es la linterna y secondary el modo faro.
        primary: const Color(0xFFB26A00),
        secondary: const Color(0xFF00778A),
        outline: const Color(0xFFB9C4CE),
      );

  return _base(scheme).copyWith(scaffoldBackgroundColor: Colors.white);
}

ThemeData _base(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: scheme.brightness,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.surfaceContainerHighest,
      contentTextStyle: TextStyle(color: scheme.onSurface),
    ),
  );
}
