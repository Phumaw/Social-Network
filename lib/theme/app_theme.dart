import 'package:flutter/material.dart';

class AppTheme {
  static const Color backgroundColor = Colors.white;
  static const Color primaryColor = Color(0xFF26374D);
  static const Color accentColor = Color(0xFF68A9FF);
  static const Color borderColor = Color(0xFFE1E5EA);
  static const Color textDark = Color(0xFF1F2933);
  static const Color surfaceColor = Colors.white;
  static const Color raisedSurfaceColor = Color(0xFFF3F5F7);
  static const Color mutedTextColor = Color(0xFF697586);
  static const Color authBackground = backgroundColor;
  static const Color authSurface = surfaceColor;
  static const Color authInput = raisedSurfaceColor;
  static const Color authText = textDark;
  static const Color authMuted = mutedTextColor;

  static ThemeData authTheme(ThemeData base) => base.copyWith(
    brightness: Brightness.light,
    textTheme: base.textTheme.apply(
      bodyColor: authText,
      displayColor: authText,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: authBackground,
      foregroundColor: authText,
    ),
  );

  static ThemeData get themeData {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
      surface: surfaceColor,
    ).copyWith(
      primary: accentColor,
      onPrimary: const Color(0xFF071321),
      secondary: const Color(0xFF79D4C6),
      onSecondary: const Color(0xFF071A17),
      surface: surfaceColor,
      onSurface: textDark,
      outline: borderColor,
    );
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: accentColor,
      canvasColor: backgroundColor,
      cardColor: surfaceColor,
      dividerColor: borderColor,
      fontFamily: 'THSarabunNew',
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textDark,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: accentColor,
        unselectedItemColor: mutedTextColor,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raisedSurfaceColor,
        hintStyle: const TextStyle(color: mutedTextColor),
        labelStyle: const TextStyle(color: mutedTextColor),
        prefixIconColor: mutedTextColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentColor, width: 1.5),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: raisedSurfaceColor,
        contentTextStyle: TextStyle(color: textDark),
      ),
    );
  }
}

class SocialNetworkMark extends StatelessWidget {
  final double size;

  const SocialNetworkMark({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'โลโก้ Social Network',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.authSurface,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(
          Icons.hub_rounded,
          size: size * 0.54,
          color: AppTheme.accentColor,
        ),
      ),
    );
  }
}
