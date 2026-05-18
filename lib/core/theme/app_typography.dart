import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  // Primary text theme — Inter for all Latin / French / English content.
  // [P-0119] bodyColor/displayColor MUST be set from scheme.onSurface so every
  // style (bodyMedium, titleSmall, ...) renders with correct contrast in dark
  // theme. Without this, GoogleFonts returns Material-2 defaults (near-black)
  // and text becomes invisible on dark surfaces (e.g. SelectableText transcript).
  static TextTheme textTheme(ColorScheme scheme) =>
      GoogleFonts.interTextTheme()
          .apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          )
          .copyWith(
            displaySmall: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          );

  // Arabic / Darija content (transcripts and summaries that contain Arabic).
  static TextStyle cairo({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
}
