import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografia Pediatria360 — Nunito (arredondada, pediátrica/premium).
class AppTypography {
  const AppTypography._();

  static TextStyle display(Color color) => GoogleFonts.nunito(
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: color,
      );

  static TextStyle data(
    Color color, {
    double size = 16,
    FontWeight weight = FontWeight.w600,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        height: 1.2,
        color: color,
        letterSpacing: -0.1,
      );

  static TextStyle eyebrow(Color color) => GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: color,
      );

  static TextTheme textTheme(Color ink, Color muted) {
    final TextTheme base = GoogleFonts.nunitoTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.nunito(
        fontSize: 34,
        height: 1.1,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      displayMedium: GoogleFonts.nunito(
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      displaySmall: GoogleFonts.nunito(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      headlineMedium: GoogleFonts.nunito(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      headlineSmall: GoogleFonts.nunito(
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleLarge: GoogleFonts.nunito(
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: GoogleFonts.nunito(
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleSmall: GoogleFonts.nunito(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: GoogleFonts.nunito(
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      bodyMedium: GoogleFonts.nunito(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      bodySmall: GoogleFonts.nunito(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
      labelLarge: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      labelMedium: GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: muted,
      ),
      labelSmall: GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: muted,
      ),
    );
  }
}
