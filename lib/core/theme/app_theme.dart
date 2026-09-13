import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_provider.dart';

/// Professional Desktop Golden-Black Color Tokens & Studio Metrics
class AppColors {
  static ThemeState _currentState = const ThemeState();

  static void updateCurrentTheme(ThemeState state) {
    _currentState = state;
  }

  static bool get isLight => _currentState.isLight;

  // ── Studio Gold Accents ────────────────────────────────────────────────────
  static const Color goldBase = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF3D270);
  static const Color goldDark = Color(0xFFA67C1E);
  static const Color goldGlow = Color(0x33D4AF37);

  // ── Desktop Obsidian Dark Palette ──────────────────────────────────────────
  static const Color studioBgDark = Color(0xFF0C0D10);
  static const Color studioPanelDark = Color(0xFF13151A);
  static const Color studioSurfaceDark = Color(0xFF191B22);
  static const Color studioElevatedDark = Color(0xFF22252F);
  static const Color studioBorderDark = Color(0xFF2B2E3A);
  static const Color studioBorderHighlightDark = Color(0xFF424758);

  // ── Desktop Studio Light Palette ───────────────────────────────────────────
  static const Color studioBgLight = Color(0xFFF1F3F7);
  static const Color studioPanelLight = Color(0xFFFFFFFF);
  static const Color studioSurfaceLight = Color(0xFFE8EBF0);
  static const Color studioElevatedLight = Color(0xFFDFE3EB);
  static const Color studioBorderLight = Color(0xFFD0D5E0);
  static const Color studioBorderHighlightLight = Color(0xFFB4BCCB);

  // ── Active Dynamic Preset Colors ───────────────────────────────────────────
  static Color get primary => _currentState.preset.primary;
  static Color get primaryLight => _currentState.preset.primaryLight;
  static Color get secondary => _currentState.preset.secondary;
  static Color get accent => _currentState.preset.accent;

  // ── Adaptive Surfaces ──────────────────────────────────────────────────────
  static Color get background => isLight ? studioBgLight : studioBgDark;
  static Color get surface => isLight ? studioPanelLight : studioPanelDark;
  static Color get surfaceLight => isLight ? studioSurfaceLight : studioSurfaceDark;
  static Color get cardBg => isLight ? studioPanelLight : studioElevatedDark;
  static Color get cardBorder => isLight ? studioBorderLight : studioBorderDark;
  static Color get borderHighlight => isLight ? studioBorderHighlightLight : studioBorderHighlightDark;

  // ── Typography ─────────────────────────────────────────────────────────────
  static Color get textPrimary => isLight ? const Color(0xFF11141A) : const Color(0xFFF4F5F8);
  static Color get textSecondary => isLight ? const Color(0xFF4A5162) : const Color(0xFFA1A7B8);
  static Color get textMuted => isLight ? const Color(0xFF7E879B) : const Color(0xFF6B7285);
  static Color get textDisabled => isLight ? const Color(0xFFADB5C4) : const Color(0xFF484D5C);

  // ── Status Indicators ──────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color processing = Color(0xFF8B5CF6);

  // ── Gradients ──────────────────────────────────────────────────────────────
  static LinearGradient get primaryGradient => _currentState.preset.primaryGradient;
  static LinearGradient get accentGradient => _currentState.preset.accentGradient;

  static LinearGradient get goldLinearGradient => const LinearGradient(
        colors: [Color(0xFFF5D77F), Color(0xFFD4AF37), Color(0xFFA67C1E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get backgroundGradient => isLight
      ? const LinearGradient(
          colors: [Color(0xFFF7F8FA), Color(0xFFEDEFF4)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )
      : const LinearGradient(
          colors: [Color(0xFF0A0B0E), Color(0xFF121419)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );

  static LinearGradient get cardGradient => isLight
      ? const LinearGradient(
          colors: [Colors.white, Color(0xFFF4F6F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
          colors: [studioSurfaceDark, studioPanelDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
}

@immutable
class AppCustomTheme extends ThemeExtension<AppCustomTheme> {
  final ThemePreset preset;
  final bool isLight;
  final Color primary;
  final Color primaryLight;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color cardBg;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final LinearGradient primaryGradient;
  final LinearGradient accentGradient;
  final LinearGradient backgroundGradient;
  final LinearGradient cardGradient;

  const AppCustomTheme({
    required this.preset,
    required this.isLight,
    required this.primary,
    required this.primaryLight,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.cardBg,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primaryGradient,
    required this.accentGradient,
    required this.backgroundGradient,
    required this.cardGradient,
  });

  @override
  AppCustomTheme copyWith({
    ThemePreset? preset,
    bool? isLight,
    Color? primary,
    Color? primaryLight,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? surfaceLight,
    Color? cardBg,
    Color? cardBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    LinearGradient? primaryGradient,
    LinearGradient? accentGradient,
    LinearGradient? backgroundGradient,
    LinearGradient? cardGradient,
  }) {
    return AppCustomTheme(
      preset: preset ?? this.preset,
      isLight: isLight ?? this.isLight,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceLight: surfaceLight ?? this.surfaceLight,
      cardBg: cardBg ?? this.cardBg,
      cardBorder: cardBorder ?? this.cardBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      accentGradient: accentGradient ?? this.accentGradient,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      cardGradient: cardGradient ?? this.cardGradient,
    );
  }

  @override
  AppCustomTheme lerp(ThemeExtension<AppCustomTheme>? other, double t) {
    if (other is! AppCustomTheme) return this;
    return AppCustomTheme(
      preset: t < 0.5 ? preset : other.preset,
      isLight: t < 0.5 ? isLight : other.isLight,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primaryGradient: LinearGradient.lerp(primaryGradient, other.primaryGradient, t)!,
      accentGradient: LinearGradient.lerp(accentGradient, other.accentGradient, t)!,
      backgroundGradient: LinearGradient.lerp(backgroundGradient, other.backgroundGradient, t)!,
      cardGradient: LinearGradient.lerp(cardGradient, other.cardGradient, t)!,
    );
  }
}

class AppTheme {
  static AppCustomTheme get fallbackDarkTheme => const AppCustomTheme(
        preset: ThemePreset.gold,
        isLight: false,
        primary: Color(0xFFD4AF37),
        primaryLight: Color(0xFFF3D270),
        secondary: Color(0xFFA67C1E),
        accent: Color(0xFFFFD700),
        background: AppColors.studioBgDark,
        surface: AppColors.studioPanelDark,
        surfaceLight: AppColors.studioSurfaceDark,
        cardBg: AppColors.studioElevatedDark,
        cardBorder: AppColors.studioBorderDark,
        textPrimary: Color(0xFFF4F5F8),
        textSecondary: Color(0xFFA1A7B8),
        textMuted: Color(0xFF6B7285),
        primaryGradient: LinearGradient(
          colors: [Color(0xFFF3D270), Color(0xFFA67C1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentGradient: LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFD4AF37), Color(0xFF996515)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        backgroundGradient: LinearGradient(
          colors: [Color(0xFF0A0B0E), Color(0xFF121419)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        cardGradient: LinearGradient(
          colors: [AppColors.studioSurfaceDark, AppColors.studioPanelDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );

  static ThemeData get darkTheme => getDarkTheme(ThemePreset.gold);
  static ThemeData get lightTheme => getLightTheme(ThemePreset.gold);

  static ThemeData getDarkTheme(ThemePreset preset) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.studioBgDark,
      colorScheme: ColorScheme.dark(
        primary: preset.primary,
        secondary: preset.secondary,
        surface: AppColors.studioPanelDark,
        error: AppColors.error,
        onPrimary: Colors.black,
        onSurface: const Color(0xFFF4F5F8),
      ),
      extensions: [
        AppCustomTheme(
          preset: preset,
          isLight: false,
          primary: preset.primary,
          primaryLight: preset.primaryLight,
          secondary: preset.secondary,
          accent: preset.accent,
          background: AppColors.studioBgDark,
          surface: AppColors.studioPanelDark,
          surfaceLight: AppColors.studioSurfaceDark,
          cardBg: AppColors.studioElevatedDark,
          cardBorder: AppColors.studioBorderDark,
          textPrimary: const Color(0xFFF4F5F8),
          textSecondary: const Color(0xFFA1A7B8),
          textMuted: const Color(0xFF6B7285),
          primaryGradient: preset.primaryGradient,
          accentGradient: preset.accentGradient,
          backgroundGradient: const LinearGradient(
            colors: [Color(0xFF0A0B0E), Color(0xFF121419)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          cardGradient: const LinearGradient(
            colors: [AppColors.studioSurfaceDark, AppColors.studioPanelDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ],
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFF4F5F8),
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFF4F5F8),
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF4F5F8),
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF4F5F8),
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: const Color(0xFFF4F5F8),
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: const Color(0xFFA1A7B8),
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF6B7285),
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF4F5F8),
          letterSpacing: 0.2,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.studioBorderHighlightDark),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(6),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData getLightTheme(ThemePreset preset) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.studioBgLight,
      colorScheme: ColorScheme.light(
        primary: preset.primary,
        secondary: preset.secondary,
        surface: AppColors.studioPanelLight,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSurface: const Color(0xFF11141A),
      ),
      extensions: [
        AppCustomTheme(
          preset: preset,
          isLight: true,
          primary: preset.primary,
          primaryLight: preset.primaryLight,
          secondary: preset.secondary,
          accent: preset.accent,
          background: AppColors.studioBgLight,
          surface: AppColors.studioPanelLight,
          surfaceLight: AppColors.studioSurfaceLight,
          cardBg: AppColors.studioPanelLight,
          cardBorder: AppColors.studioBorderLight,
          textPrimary: const Color(0xFF11141A),
          textSecondary: const Color(0xFF4A5162),
          textMuted: const Color(0xFF7E879B),
          primaryGradient: preset.primaryGradient,
          accentGradient: preset.accentGradient,
          backgroundGradient: const LinearGradient(
            colors: [Color(0xFFF7F8FA), Color(0xFFEDEFF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          cardGradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFF4F6F9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ],
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF11141A),
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF11141A),
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF11141A),
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF11141A),
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF11141A),
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF4A5162),
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF7E879B),
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF11141A),
          letterSpacing: 0.2,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.studioBorderHighlightLight),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(6),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

extension AppThemeContext on BuildContext {
  AppCustomTheme get appTheme =>
      Theme.of(this).extension<AppCustomTheme>() ?? AppTheme.fallbackDarkTheme;
}
