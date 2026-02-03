import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class NeuwsPalette extends ThemeExtension<NeuwsPalette> {
  const NeuwsPalette({
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceElevated,
    required this.surfaceCard,
    required this.border,
    required this.muted,
    required this.imagePlaceholder,
    required this.progressBg,
    required this.eventsChip,
  });

  final Color surface;
  final Color surfaceAlt;
  final Color surfaceElevated;
  final Color surfaceCard;
  final Color border;
  final Color muted;
  final Color imagePlaceholder;
  final Color progressBg;
  final Color eventsChip;

  @override
  NeuwsPalette copyWith({
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceElevated,
    Color? surfaceCard,
    Color? border,
    Color? muted,
    Color? imagePlaceholder,
    Color? progressBg,
    Color? eventsChip,
  }) {
    return NeuwsPalette(
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      border: border ?? this.border,
      muted: muted ?? this.muted,
      imagePlaceholder: imagePlaceholder ?? this.imagePlaceholder,
      progressBg: progressBg ?? this.progressBg,
      eventsChip: eventsChip ?? this.eventsChip,
    );
  }

  @override
  NeuwsPalette lerp(ThemeExtension<NeuwsPalette>? other, double t) {
    if (other is! NeuwsPalette) {
      return this;
    }
    return NeuwsPalette(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      imagePlaceholder: Color.lerp(imagePlaceholder, other.imagePlaceholder, t)!,
      progressBg: Color.lerp(progressBg, other.progressBg, t)!,
      eventsChip: Color.lerp(eventsChip, other.eventsChip, t)!,
    );
  }
}

TextTheme _buildTextTheme(Color textColor) {
  return GoogleFonts.workSansTextTheme().copyWith(
    displayLarge: GoogleFonts.libreBaskerville(
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    displayMedium: GoogleFonts.libreBaskerville(
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    headlineMedium: GoogleFonts.libreBaskerville(
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    headlineSmall: GoogleFonts.libreBaskerville(
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    titleLarge: GoogleFonts.workSans(
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    titleMedium: GoogleFonts.workSans(
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    bodyLarge: GoogleFonts.workSans(
      fontWeight: FontWeight.w400,
      color: textColor,
    ),
    bodyMedium: GoogleFonts.workSans(
      fontWeight: FontWeight.w400,
      color: textColor,
    ),
    labelLarge: GoogleFonts.workSans(
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
  );
}

ThemeData buildNeuwsDarkTheme() {
  const background = Color(0xFF0F0F0F);
  const accent = Color(0xFFF29D38);

  const palette = NeuwsPalette(
    surface: Color(0xFF1C1C1C),
    surfaceAlt: Color(0xFF171717),
    surfaceElevated: Color(0xFF1E1E1E),
    surfaceCard: Color(0xFF1A1A1A),
    border: Color(0xFF2A2A2A),
    muted: Color(0xFF9A9A9A),
    imagePlaceholder: Color(0xFF272727),
    progressBg: Color(0xFF2C2C2C),
    eventsChip: Color(0xFF4CC9F0),
  );

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accent,
      surface: Color(0xFF1C1C1C),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.white),
      foregroundColor: Colors.white,
    ),
    textTheme: _buildTextTheme(Colors.white),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF121212),
      selectedItemColor: Colors.white,
      unselectedItemColor: Color(0xFF9A9A9A),
      type: BottomNavigationBarType.fixed,
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF1C1C1C),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerColor: palette.border,
    extensions: const [palette],
  );
}

ThemeData buildNeuwsLightTheme() {
  const background = Color(0xFFF7F4EE);
  const accent = Color(0xFFF29D38);
  const textColor = Color(0xFF1B1B1B);

  const palette = NeuwsPalette(
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0EAE0),
    surfaceElevated: Color(0xFFF8F3EA),
    surfaceCard: Color(0xFFFDFBF7),
    border: Color(0xFFE2D8C9),
    muted: Color(0xFF6C645B),
    imagePlaceholder: Color(0xFFE5DED3),
    progressBg: Color(0xFFE8DFD2),
    eventsChip: Color(0xFF118AB2),
  );

  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      primary: accent,
      secondary: accent,
      surface: Color(0xFFFFFFFF),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: textColor),
      foregroundColor: textColor,
    ),
    textTheme: _buildTextTheme(textColor),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFFDFBF7),
      selectedItemColor: Color(0xFF1B1B1B),
      unselectedItemColor: Color(0xFF6C645B),
      type: BottomNavigationBarType.fixed,
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFFFFFFFF),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerColor: palette.border,
    extensions: const [palette],
  );
}
