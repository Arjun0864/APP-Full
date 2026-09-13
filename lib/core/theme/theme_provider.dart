import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

enum ThemePreset {
  gold(
    id: 'gold',
    name: 'Gold Luxury',
    primary: Color(0xFFD4AF37),
    primaryLight: Color(0xFFE5C158),
    secondary: Color(0xFFB8860B),
    accent: Color(0xFFFFD700),
  ),
  violet(
    id: 'violet',
    name: 'Cyber Violet',
    primary: Color(0xFF8B5CF6),
    primaryLight: Color(0xFFA78BFA),
    secondary: Color(0xFF6D28D9),
    accent: Color(0xFFC4B5FD),
  ),
  emerald(
    id: 'emerald',
    name: 'Emerald Mint',
    primary: Color(0xFF10B981),
    primaryLight: Color(0xFF34D399),
    secondary: Color(0xFF059669),
    accent: Color(0xFF6EE7B7),
  ),
  ocean(
    id: 'ocean',
    name: 'Ocean Neon',
    primary: Color(0xFF3B82F6),
    primaryLight: Color(0xFF60A5FA),
    secondary: Color(0xFF1D4ED8),
    accent: Color(0xFF93C5FD),
  );

  final String id;
  final String name;
  final Color primary;
  final Color primaryLight;
  final Color secondary;
  final Color accent;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.primary,
    required this.primaryLight,
    required this.secondary,
    required this.accent,
  });

  LinearGradient get primaryGradient => LinearGradient(
        colors: [primaryLight, secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get accentGradient => LinearGradient(
        colors: [accent, primary, secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

class ThemeState {
  final ThemeMode themeMode;
  final ThemePreset preset;

  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.preset = ThemePreset.gold,
  });

  bool get isLight {
    if (themeMode == ThemeMode.light) return true;
    if (themeMode == ThemeMode.dark) return false;
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.light;
  }

  ThemeState copyWith({
    ThemeMode? themeMode,
    ThemePreset? preset,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      preset: preset ?? this.preset,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  static const _keyMode = 'app_theme_mode';
  static const _keyPreset = 'app_theme_preset';

  ThemeNotifier() : super(const ThemeState()) {
    AppColors.updateCurrentTheme(state);
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_keyMode);
      final presetStr = prefs.getString(_keyPreset);

      ThemeMode mode = ThemeMode.system;
      if (modeStr == 'light') mode = ThemeMode.light;
      if (modeStr == 'dark') mode = ThemeMode.dark;

      ThemePreset preset = ThemePreset.gold;
      for (final p in ThemePreset.values) {
        if (p.id == presetStr) {
          preset = p;
          break;
        }
      }

      state = ThemeState(themeMode: mode, preset: preset);
      AppColors.updateCurrentTheme(state);
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    AppColors.updateCurrentTheme(state);
    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'system';
      if (mode == ThemeMode.light) val = 'light';
      if (mode == ThemeMode.dark) val = 'dark';
      await prefs.setString(_keyMode, val);
    } catch (_) {}
  }

  Future<void> setPreset(ThemePreset preset) async {
    state = state.copyWith(preset: preset);
    AppColors.updateCurrentTheme(state);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPreset, preset.id);
    } catch (_) {}
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
