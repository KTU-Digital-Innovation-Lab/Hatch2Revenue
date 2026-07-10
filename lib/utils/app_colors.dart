import 'package:flutter/material.dart';

/// App palette — FarmNest design language.
///
/// Accent colors are identical in day and night mode and stay `const`.
/// Neutral tokens (backgrounds, borders, text) switch with [isDark],
/// which is managed by [ThemeProvider] — do not set it directly.
class AppColors {
  static bool isDark = false;

  // ── Accents (FarmNest brand) ──────────────────────────────────────
  /// Primary brand green (kept under its historic name — this is the
  /// main accent used across the app).
  static const Color amber  = Color(0xFF2E7D32);
  static const Color green  = Color(0xFF43A047); // success
  static const Color cyan   = Color(0xFF00897B);
  static const Color teal   = Color(0xFF00897B); // alias
  static const Color purple = Color(0xFF7E57C2);
  static const Color red    = Color(0xFFE53935); // danger
  static const Color blue   = Color(0xFF1E88E5);

  // ── Neutrals (theme-dependent) ────────────────────────────────────
  static Color get background    => isDark ? _dBackground   : _lBackground;
  static Color get surface       => isDark ? _dSurface      : _lSurface;
  static Color get surfaceLight  => isDark ? _dSurfaceLight : _lSurfaceLight;
  static Color get border        => isDark ? _dBorder       : _lBorder;
  static Color get textPrimary   => isDark ? _dTextPrimary  : _lTextPrimary;
  static Color get textSecondary => isDark ? _dTextSecondary: _lTextSecondary;
  static Color get textMuted     => isDark ? _dTextMuted    : _lTextMuted;

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
