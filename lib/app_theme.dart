
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Colores ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF0D47A1); // Un azul más oscuro y profesional
  static const Color primaryDark = Color(0xFF083A8A);
  static const Color accent = Color(0xFFE91E63);   // Un color de acento vibrante
  static const Color background = Color(0xFFF5F5F5); // Un gris claro para el fondo
  static const Color cardColor = Colors.white;

  // Colores para tarjetas del menú
  static const Color menuRed = Color(0xFFE53935);
  static const Color menuOrange = Color(0xFFFB8C00);
  static const Color menuYellow = Color(0xFFFFB300);
  static const Color menuLightBlue = Color(0xFF42A5F5);

  // Colores de texto
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);

  // ─── Tema Principal (Claro) ─────────────────────────────────────────────────

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      
      // Esquema de colores
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: cardColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        error: Colors.red,
      ),

      // Tipografía con Google Fonts (Manrope)
      textTheme: GoogleFonts.manropeTextTheme().copyWith(
        displayLarge: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 32, color: textPrimary),
        headlineMedium: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 24, color: textPrimary),
        titleLarge: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 18, color: textPrimary),
        bodyLarge: GoogleFonts.manrope(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.manrope(fontSize: 14, color: textSecondary),
        labelLarge: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
      ),

      // Estilo de AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold),
      ),

      // Estilo de Botones
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      
      // Estilo de Tarjetas
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 1.0,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Estilo de BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),

      // Estilo de FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
    );
  }
}
