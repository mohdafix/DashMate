import 'package:flutter/material.dart';

/// Semantic colour tokens shared by the phone app (mirrors design/tokens.json).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.ok,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color ok;

  static const light = AppTokens(
    bg: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    ink: Color(0xFF0F172A),
    ink2: Color(0xFF475569),
    ink3: Color(0xFF64748B),
    accent: Color(0xFF0F766E),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFDC2626),
    ok: Color(0xFF15803D),
  );

  static const dark = AppTokens(
    bg: Color(0xFF0F1115),
    surface: Color(0xFF181B21),
    surface2: Color(0xFF20242B),
    border: Color(0xFF2A2F37),
    ink: Color(0xFFF1F5F9),
    ink2: Color(0xFFA3ACB9),
    ink3: Color(0xFF7C8594),
    accent: Color(0xFF2DD4BF),
    onAccent: Color(0xFF042F2E),
    danger: Color(0xFFF87171),
    ok: Color(0xFF4ADE80),
  );

  bool get isDark => bg.computeLuminance() < 0.5;

  /// The single soft card shadow (day only; night uses the border alone).
  List<BoxShadow> get cardShadow => isDark
      ? const []
      : const [
          BoxShadow(color: Color(0x0F0F172A), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, 4)),
        ];

  @override
  AppTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? border,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? accent,
    Color? onAccent,
    Color? danger,
    Color? ok,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
      ok: ok ?? this.ok,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
    );
  }
}

extension AppTokensX on BuildContext {
  /// The current theme's tokens (falls back to light if none attached).
  AppTokens get tokens => Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}
