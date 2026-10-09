import 'package:flutter/material.dart';

/// NexVault visual system: premium midnight navy with electric-blue and teal accents.
class AppColors {
  // Brand accents
  static const primary = Color(0xFF5687FF);
  static const primaryDark = Color(0xFF3569E8);
  static const accent = Color(0xFF39D6C5);
  static const gold = Color(0xFFFFC857); // retained for premium-content labels

  // Surfaces (darkest → lightest)
  static const background = Color(0xFF080D18);
  static const surface = Color(0xFF101827);
  static const surfaceHigh = Color(0xFF182338);
  static const bubble = Color(0xFF182338);
  static const border = Color(0xFF26344B);

  // Text
  static const text = Color(0xFFF4F7FC);
  static const muted = Color(0xFF9BAAC0);
  static const ink = Color(0xFF071225);

  // Status
  static const success = Color(0xFF39D6A0);
  static const warning = Color(0xFFFFC857);
  static const danger = Color(0xFFFF6878);
  static const successBg = Color(0xFF102A28);
  static const warningBg = Color(0xFF2B2618);
  static const dangerBg = Color(0xFF301A27);

  /// Brand gradient for splash screens, key actions, and visual highlights.
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3569E8), Color(0xFF5687FF), Color(0xFF39D6C5)],
  );

  /// App bars use a restrained midnight-blue glow.
  static const Gradient barGradient = RadialGradient(
    center: Alignment(1.1, -2.2),
    radius: 2.4,
    colors: [Color(0xFF1B3564), Color(0xFF080D18)],
    stops: [0, 0.75],
  );

  /// Subtle cool-toned fill for placeholders and raised surfaces.
  static const softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B2940), Color(0xFF101827)],
  );

  /// Low-contrast blue glow behind headers.
  static const glow = RadialGradient(
    center: Alignment(0.9, -1.2),
    radius: 1.3,
    colors: [Color(0x554F83FF), Color(0x004F83FF)],
  );

  /// Bottom fade over thumbnails so overlay text stays readable.
  static const scrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0xB3000000)],
  );
}

/// Spacing and radius scale used across screens.
class Gap {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
}

class Radii {
  static const card = 18.0;
  static const button = 14.0;
  static const chip = 20.0;
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.danger,
      ).copyWith(
        surfaceContainerLowest: AppColors.background,
        surfaceContainerLow: AppColors.surface,
        surfaceContainer: AppColors.surface,
        surfaceContainerHigh: AppColors.surfaceHigh,
        surfaceContainerHighest: AppColors.surfaceHigh,
        outline: AppColors.border,
        outlineVariant: AppColors.border,
        onSurfaceVariant: AppColors.muted,
      );

  final base = ThemeData(
    colorScheme: scheme,
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'Poppins',
  );
  final text = base.textTheme
      .merge(
        const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 15, height: 1.45),
          bodyMedium: TextStyle(fontSize: 14, height: 1.45),
          bodySmall: TextStyle(fontSize: 12),
          labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      )
      .apply(
        fontFamily: 'Poppins',
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      );

  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.button),
  );
  OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.button),
    borderSide: BorderSide(color: c, width: w),
  );

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    visualDensity: VisualDensity.compact,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 56,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.text,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.text,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.primary,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.muted,
      textColor: AppColors.text,
      minVerticalPadding: 8,
    ),
    iconTheme: const IconThemeData(color: AppColors.text),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.surfaceHigh,
        disabledForegroundColor: AppColors.muted,
        minimumSize: const Size(0, 50),
        elevation: 0,
        shape: rounded,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceHigh,
        foregroundColor: AppColors.text,
        shape: rounded,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size(0, 50),
        side: const BorderSide(color: AppColors.border, width: 1.2),
        shape: rounded,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.muted,
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.muted),
      labelStyle: const TextStyle(color: AppColors.muted),
      prefixIconColor: AppColors.muted,
      suffixIconColor: AppColors.muted,
      border: field(AppColors.border),
      enabledBorder: field(AppColors.border),
      focusedBorder: field(AppColors.primary, 1.6),
      errorBorder: field(AppColors.danger),
      focusedErrorBorder: field(AppColors.danger, 1.6),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHigh,
      selectedColor: AppColors.primary,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: AppColors.text,
        fontWeight: FontWeight.w500,
        fontSize: 12.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      checkmarkColor: Colors.white,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        height: 1.45,
        color: AppColors.muted,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: AppColors.text,
      ),
      actionTextColor: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.surfaceHigh,
      circularTrackColor: Colors.transparent,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: Color(0x40FFFFFF),
      thumbColor: Colors.white,
      trackHeight: 3,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.surfaceHigh,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.muted,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.transparent,
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0D1422),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 66,
      indicatorColor: const Color(0x263D75F5),
      overlayColor: const WidgetStatePropertyAll(Color(0x164F87FF)),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 24,
          color: s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.muted,
        ),
      ),
    ),
  );
}
