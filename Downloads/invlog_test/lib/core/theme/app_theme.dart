import 'package:flutter/material.dart';

class AppTheme {
  // Dark theme colors
  static const Color _darkPrimaryColor = Color(0xFF405DE6);
  static const Color _darkAccentColor = Color(0xFF833AB4);
  static const Color _darkBackgroundColor = Color(0xFF121212);
  static const Color _darkSurfaceColor = Color(0xFF1E1E1E);
  static const Color _darkTextColor = Color(0xFFFFFFFF);
  static const Color _darkSecondaryTextColor = Color(0xFF8E8E8E);

  // Light theme colors
  static const Color _lightPrimaryColor = Color(0xFF405DE6);
  static const Color _lightAccentColor = Color(0xFF833AB4);
  static const Color _lightBackgroundColor = Color(0xFFF8F8F8);
  static const Color _lightSurfaceColor = Color(0xFFFFFFFF);
  static const Color _lightTextColor = Color(0xFF262626);
  static const Color _lightSecondaryTextColor = Color(0xFF8E8E8E);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: _lightPrimaryColor,
      scaffoldBackgroundColor: _lightBackgroundColor,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimaryColor,
        secondary: _lightAccentColor,
        surface: _lightSurfaceColor,
        onPrimary: _lightSurfaceColor,
        onSecondary: _lightSurfaceColor,
        onSurface: _lightTextColor,
      ),
      
      // Card Theme
      cardTheme: CardTheme(
        color: _lightSurfaceColor,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: _lightPrimaryColor,
        foregroundColor: _lightSurfaceColor,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: _lightSurfaceColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(
          color: _lightSurfaceColor,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: _lightSurfaceColor,
          size: 24,
        ),
      ),

      // Text Theme
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: _lightTextColor,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: _lightTextColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: _lightTextColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: _lightTextColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: _lightTextColor,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: _lightSecondaryTextColor,
          fontSize: 14,
        ),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPrimaryColor,
          foregroundColor: _lightSurfaceColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Icon Theme
      iconTheme: IconThemeData(
        color: _lightTextColor,
        size: 24,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _lightSurfaceColor,
        selectedItemColor: _lightPrimaryColor,
        unselectedItemColor: _lightSecondaryTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightSecondaryTextColor.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightSecondaryTextColor.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightPrimaryColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarTheme(
        labelColor: _lightPrimaryColor,
        unselectedLabelColor: _lightSecondaryTextColor,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: _lightPrimaryColor, width: 2),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: _darkPrimaryColor,
      scaffoldBackgroundColor: _darkBackgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimaryColor,
        secondary: _darkAccentColor,
        surface: _darkSurfaceColor,
        onPrimary: _darkTextColor,
        onSecondary: _darkTextColor,
        onSurface: _darkTextColor,
      ),
      
      // Card Theme
      cardTheme: CardTheme(
        color: _darkSurfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: _darkSurfaceColor,
        foregroundColor: _darkTextColor,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: _darkTextColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(
          color: _darkTextColor,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: _darkTextColor,
          size: 24,
        ),
      ),

      // Text Theme
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: _darkTextColor,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: _darkTextColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: _darkTextColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: _darkTextColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: _darkTextColor,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: _darkSecondaryTextColor,
          fontSize: 14,
        ),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimaryColor,
          foregroundColor: _darkTextColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Icon Theme
      iconTheme: IconThemeData(
        color: _darkTextColor,
        size: 24,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _darkSurfaceColor,
        selectedItemColor: _darkTextColor,
        unselectedItemColor: _darkSecondaryTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkPrimaryColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarTheme(
        labelColor: _darkTextColor,
        unselectedLabelColor: _darkSecondaryTextColor,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: _darkPrimaryColor, width: 2),
        ),
      ),
    );
  }
} 