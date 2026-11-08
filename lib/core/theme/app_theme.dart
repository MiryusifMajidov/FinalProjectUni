// CupertinoPageTransitionsBuilder moved out of material.dart into cupertino.dart
// in newer Flutter. Imported narrowly so material/cupertino names cannot clash.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_theme_extension.dart';
import 'moulded.dart';

/// One dark scheme, the club table (see app_colors.dart). Material components
/// are themed rather than replaced: filled and outlined buttons are moulded
/// tokens, inputs and cards are tone steps on the felt with no hairlines.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => forAccent(AppColors.amber);

  static final _byAccent = <int, ThemeData>{};

  /// The app theme in the colour of the selected game ([AppColors.accent]):
  /// buttons, switches, focus outlines and selections take [accent].
  static ThemeData forAccent(Color accent) =>
      _byAccent[accent.toARGB32()] ??= _build(accent);

  static ThemeData _build(Color accent) {
    final accentGlow = accent.withValues(alpha: 0.15);
    final accentSoft = Color.lerp(accent, const Color(0xFFFFFFFF), 0.3)!;
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      colorScheme: ColorScheme.dark(
        surface: AppColors.surface,
        primary: accent,
        onPrimary: AppColors.onAmber,
        primaryContainer: accentGlow,
        onPrimaryContainer: accentSoft,
        secondary: AppColors.checkers,
        onSecondary: AppColors.ink,
        tertiary: AppColors.domino,
        error: AppColors.loss,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.inkDim,
        onError: AppColors.onAmber,
        surfaceContainerLowest: AppColors.background,
        surfaceContainerLow: AppColors.surface,
        surfaceContainer: AppColors.card,
        surfaceContainerHigh: AppColors.card,
        surfaceContainerHighest: AppColors.cardElevated,
        outline: AppColors.borderStrong,
        outlineVariant: AppColors.border,
      ),
      textTheme: AppFonts.textTheme(base.textTheme).apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      primaryTextTheme: AppFonts.textTheme(base.primaryTextTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.background,
        ),
        iconTheme: const IconThemeData(color: AppColors.ink),
        titleTextStyle: AppFonts.ui(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: mouldedPrimary(fill: accent, )),
      filledButtonTheme: FilledButtonThemeData(style: mouldedPrimary(fill: accent, )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: mouldedTonal()),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(48, 44),
          textStyle: AppFonts.ui(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(44, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.loss, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.loss, width: 2),
        ),
        hintStyle: AppFonts.ui(color: AppColors.inkMute, fontSize: 15),
        labelStyle: AppFonts.ui(
          color: AppColors.inkDim,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: AppColors.inkMute,
        suffixIconColor: AppColors.inkMute,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.inkDim,
        textColor: AppColors.ink,
        titleTextStyle: AppFonts.ui(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
        subtitleTextStyle: AppFonts.ui(fontSize: 13, color: AppColors.inkMute),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // Sheets across the app draw their own handle in their content.
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: AppFonts.ui(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        contentTextStyle: AppFonts.ui(
          fontSize: 15,
          height: 1.45,
          color: AppColors.inkDim,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.cardElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: AppFonts.ui(fontSize: 15, color: AppColors.ink),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardElevated,
        contentTextStyle: AppFonts.ui(
          color: AppColors.ink,
          fontSize: 14,
          height: 1.4,
        ),
        actionTextColor: accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: AppColors.cardElevated,
        circularTrackColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: AppColors.cardElevated,
        thumbColor: accent,
        overlayColor: accentGlow,
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.onAmber;
          return AppColors.inkDim;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return AppColors.cardElevated;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.onAmber),
        side: const BorderSide(color: AppColors.inkMute, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? accent
                : AppColors.inkMute),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: accentGlow,
        side: BorderSide.none,
        labelStyle: AppFonts.ui(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.inkMute,
        indicatorColor: accent,
        dividerColor: AppColors.border,
        labelStyle: AppFonts.ui(fontSize: 15, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            AppFonts.ui(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: accentGlow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppFonts.ui(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.ink : AppColors.inkMute,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? accent : AppColors.inkMute,
            size: 24,
          );
        }),
      ),
      extensions: const [AppThemeExtension.dark],
    );
  }

  /// The app has one scheme; kept so older call sites still resolve.
  static ThemeData get light => dark;
}
