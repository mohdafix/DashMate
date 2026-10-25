import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Material 3 themes built from [AppTokens]. White and clean by day, soft
/// charcoal by night; one teal accent, hairline borders, no glows.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppTokens.light, Brightness.light);
  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  static const double cardRadius = 16;
  static const double buttonRadius = 12;

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: t.onAccent,
      primaryContainer: Color.alphaBlend(t.accent.withValues(alpha: 0.12), t.surface),
      onPrimaryContainer: t.ink,
      secondary: t.accent,
      onSecondary: t.onAccent,
      secondaryContainer: t.surface2,
      onSecondaryContainer: t.ink,
      tertiary: t.ok,
      onTertiary: t.onAccent,
      error: t.danger,
      onError: brightness == Brightness.light ? t.surface : t.bg,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.ink2,
      surfaceContainerLowest: t.surface,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surface2,
      surfaceContainerHigh: t.surface2,
      surfaceContainerHighest: t.surface2,
      outline: t.border,
      outlineVariant: t.border,
      shadow: t.ink,
      scrim: t.ink,
      inverseSurface: t.ink,
      onInverseSurface: t.bg,
      inversePrimary: t.accent,
      surfaceTint: Colors.transparent,
    );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cardRadius),
      side: BorderSide(color: t.border),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Roboto',
      colorScheme: scheme,
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.bg,
      dividerColor: t.border,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: t.ink,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: t.ink),
      ),
      iconTheme: IconThemeData(color: t.ink2),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.ink2,
        textColor: t.ink,
        tileColor: Colors.transparent,
        subtitleTextStyle: TextStyle(color: t.ink2, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.onAccent : t.ink3,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.accent : t.surface2,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.accent : t.border,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.accent,
        inactiveTrackColor: t.border,
        thumbColor: t.accent,
        overlayColor: t.accent.withValues(alpha: 0.12),
        valueIndicatorColor: t.accent,
        valueIndicatorTextStyle: TextStyle(color: t.onAccent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surface2,
        selectedColor: t.accent,
        disabledColor: t.surface2,
        labelStyle: TextStyle(color: t.ink, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: t.onAccent, fontSize: 13),
        side: BorderSide(color: t.border),
        shape: const StadiumBorder(),
        checkmarkColor: t.onAccent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface2,
        hintStyle: TextStyle(color: t.ink3),
        labelStyle: TextStyle(color: t.ink2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: t.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          shape: buttonShape,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          elevation: 0,
          shape: buttonShape,
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          side: BorderSide(color: t.border),
          shape: buttonShape,
          minimumSize: const Size(48, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: t.accent, shape: buttonShape),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: t.ink2),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.surface,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: t.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(fontFamily: 'Roboto', color: t.ink2, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.ink,
        contentTextStyle: TextStyle(color: t.bg),
        actionTextColor: t.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
      ),
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.border,
        circularTrackColor: t.border,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.accent,
        unselectedLabelColor: t.ink2,
        indicatorColor: t.accent,
        dividerColor: t.border,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: t.surface2,
          foregroundColor: t.ink2,
          selectedBackgroundColor: t.accent,
          selectedForegroundColor: t.onAccent,
          side: BorderSide(color: t.border),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.accent,
        selectionHandleColor: t.accent,
        selectionColor: t.accent.withValues(alpha: 0.25),
      ),
      extensions: <ThemeExtension<dynamic>>[t],
    );
  }
}
