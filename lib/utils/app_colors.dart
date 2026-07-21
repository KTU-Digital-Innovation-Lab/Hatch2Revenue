import 'package:flutter/material.dart';

/// How accent colours are chosen — normal vision, or a palette that
/// stays distinguishable for the common forms of colour blindness.
///
/// Red/green is the app's most loaded signal pair (healthy vs danger),
/// and it is exactly the pair deuteranopia and protanopia collapse, so
/// those modes swap to the Okabe-Ito blue/vermillion pairing instead.
enum ColorVisionMode { normal, deuteranopia, protanopia, tritanopia }

extension ColorVisionModeLabel on ColorVisionMode {
  String get label => switch (this) {
        ColorVisionMode.normal => 'Standard colours',
        ColorVisionMode.deuteranopia => 'Green-weak (deuteranopia)',
        ColorVisionMode.protanopia => 'Red-weak (protanopia)',
        ColorVisionMode.tritanopia => 'Blue-weak (tritanopia)',
      };

  String get hint => switch (this) {
        ColorVisionMode.normal => 'The default farm palette',
        ColorVisionMode.deuteranopia => 'Blue and orange replace green and red',
        ColorVisionMode.protanopia => 'Blue and orange replace green and red',
        ColorVisionMode.tritanopia => 'Pink replaces the blue-green tones',
      };
}

/// App palette — FarmNest design language.
///
/// Neutral tokens switch with [isDark]; accent tokens additionally
/// respond to [visionMode] and [highContrast]. Both are managed by
/// SettingsProvider — do not set them directly.
class AppColors {
  static bool isDark = false;
  static ColorVisionMode visionMode = ColorVisionMode.normal;
  static bool highContrast = false;

  static bool get _rgSafe =>
      visionMode == ColorVisionMode.deuteranopia ||
      visionMode == ColorVisionMode.protanopia;
  static bool get _byS => visionMode == ColorVisionMode.tritanopia;

  // ── Accents ───────────────────────────────────────────────────────
  // Historic names kept so ~280 call sites stay untouched; the VALUES
  // adapt to the selected vision mode.

  /// Primary brand accent.
  static Color get amber {
    if (_rgSafe) return const Color(0xFF0072B2); // Okabe-Ito blue
    return const Color(0xFF2E7D32);
  }

  /// Success / positive.
  static Color get green {
    if (_rgSafe) return const Color(0xFF009E73); // bluish green
    if (_byS) return const Color(0xFF2E7D32);
    return const Color(0xFF43A047);
  }

  /// Danger / negative.
  static Color get red {
    if (_rgSafe || _byS) return const Color(0xFFD55E00); // vermillion
    return const Color(0xFFE53935);
  }

  static Color get cyan {
    if (_rgSafe) return const Color(0xFF56B4E9); // sky blue
    if (_byS) return const Color(0xFFCC79A7); // pink (blue is unsafe)
    return const Color(0xFF00897B);
  }

  static Color get teal => cyan;

  static Color get purple {
    if (_rgSafe) return const Color(0xFFCC79A7);
    if (_byS) return const Color(0xFFAA4499);
    return const Color(0xFF7E57C2);
  }

  static Color get blue {
    if (_byS) return const Color(0xFF882255); // dark magenta
    return const Color(0xFF1E88E5);
  }

  // ── Neutrals (theme + contrast dependent) ─────────────────────────
  static Color get background => isDark
      ? (highContrast ? const Color(0xFF000000) : _dBackground)
      : (highContrast ? const Color(0xFFFFFFFF) : _lBackground);

  static Color get surface => isDark
      ? (highContrast ? const Color(0xFF0D0D0D) : _dSurface)
      : (highContrast ? const Color(0xFFFFFFFF) : _lSurface);

  static Color get surfaceLight => isDark
      ? (highContrast ? const Color(0xFF1A1A1A) : _dSurfaceLight)
      : (highContrast ? const Color(0xFFF0F0F0) : _lSurfaceLight);

  static Color get border => isDark
      ? (highContrast ? const Color(0xFF7A7A7A) : _dBorder)
      : (highContrast ? const Color(0xFF4A4A4A) : _lBorder);

  static Color get textPrimary => isDark
      ? (highContrast ? const Color(0xFFFFFFFF) : _dTextPrimary)
      : (highContrast ? const Color(0xFF000000) : _lTextPrimary);

  static Color get textSecondary => isDark
      ? (highContrast ? const Color(0xFFE0E0E0) : _dTextSecondary)
      : (highContrast ? const Color(0xFF2A2A2A) : _lTextSecondary);

  static Color get textMuted => isDark
      ? (highContrast ? const Color(0xFFC4C4C4) : _dTextMuted)
      : (highContrast ? const Color(0xFF3F3F3F) : _lTextMuted);

  // Night — FarmNest dark: deep green-tinted surfaces.
  static const Color _dBackground    = Color(0xFF10160F);
  static const Color _dSurface       = Color(0xFF1A231A);
  static const Color _dSurfaceLight  = Color(0xFF24301F);
  static const Color _dBorder        = Color(0xFF2E3B2E);
  static const Color _dTextPrimary   = Color(0xFFF1F5F0);
  static const Color _dTextSecondary = Color(0xFF9CA3AF);
  static const Color _dTextMuted     = Color(0xFF6B7280);

  // Day — FarmNest light: soft green-white with white cards.
  static const Color _lBackground    = Color(0xFFF7FAF7);
  static const Color _lSurface       = Color(0xFFFFFFFF);
  static const Color _lSurfaceLight  = Color(0xFFEEF4EE);
  static const Color _lBorder        = Color(0xFFE5E7EB);
  static const Color _lTextPrimary   = Color(0xFF1F2937);
  static const Color _lTextSecondary = Color(0xFF6B7280);
  static const Color _lTextMuted     = Color(0xFF9CA3AF);
}
