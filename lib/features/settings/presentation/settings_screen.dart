import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../models/app_models.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/shining_button.dart';
import '../../../widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/presentation/bottom_nav_bar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final themeState = ref.watch(themeProvider);
    final theme = context.appTheme;

    String themeSubtitle = 'System';
    if (themeState.themeMode == ThemeMode.dark) themeSubtitle = 'Dark';
    if (themeState.themeMode == ThemeMode.light) themeSubtitle = 'Light';
    themeSubtitle += ' • ${themeState.preset.name}';

    return Scaffold(
      backgroundColor: theme.background,
      body: Container(
        decoration: BoxDecoration(gradient: theme.backgroundGradient),
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildAppBar(context)),
                    SliverToBoxAdapter(child: _buildProfile(context, user)),
                    SliverToBoxAdapter(
                      child: _buildSection(context, 'Account', [
                        _SettingItem(
                          Icons.person_outline,
                          'Edit Profile',
                          null,
                          () => context.push('/edit-profile'),
                          gradient: [AppColors.primary, AppColors.secondary],
                        ),
                        _SettingItem(
                          Icons.notifications_outlined,
                          'Notifications',
                          null,
                          () => context.push('/notifications'),
                          gradient: [const Color(0xFFEC4899), const Color(0xFF7C3AED)],
                        ),
                        _SettingItem(
                          Icons.lock_outline,
                          'Privacy & Security',
                          null,
                          () {},
                          gradient: [const Color(0xFF10B981), const Color(0xFF3B82F6)],
                        ),
                      ]),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSection(context, 'Creation Tools', [
                        _SettingItem(
                          Icons.videocam_outlined,
                          'AI Video Generator',
                          'Cinematic Videos',
                          () => context.push('/video-generator'),
                          gradient: [const Color(0xFF3B82F6), const Color(0xFF7C3AED)],
                        ),
                        _SettingItem(
                          Icons.image_outlined,
                          'AI Image Tools',
                          'Generate, BG & RAW Grade',
                          () => context.push('/image-tools-hub'),
                          gradient: [const Color(0xFF10B981), const Color(0xFF3B82F6)],
                        ),
                      ]),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSection(context, 'App Customization', [
                        _SettingItem(
                          Icons.palette_outlined,
                          'Appearance & Themes',
                          themeSubtitle,
                          () => _showAppearanceSheet(context, ref),
                          gradient: [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                        ),
                        _SettingItem(
                          Icons.star_outline,
                          'Rate the App',
                          null,
                          () => _showRateDialog(context),
                          gradient: [const Color(0xFFF59E0B), const Color(0xFFEC4899)],
                        ),
                      ]),
                    ),
                    SliverToBoxAdapter(child: _buildLogout(context, ref)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 8),
                        child: Center(
                          child: Text(
                            'VisionAI v1.0.0 • Premium Edition',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),
            ),
            if (!_isDesktop(context)) const BottomNavBar(currentIndex: 3),
          ],
        ),
      ),
    );
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux ||
        MediaQuery.of(context).size.width >= 800;
  }

  // ── Sub-widgets ─────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Text(
            'Settings',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildProfile(BuildContext context, UserModel? user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            UserAvatar(
              user: user,
              radius: 28,
              showBorder: true,
              onTap: () => context.push('/edit-profile'),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'Creator',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/edit-profile'),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.edit_outlined,
                    color: AppColors.textSecondary, size: 16),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildSection(
      BuildContext context, String title, List<_SettingItem> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isLast = index == items.length - 1;

                return Column(
                  children: [
                    ListTile(
                      onTap: item.onTap,
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: item.gradient != null
                              ? LinearGradient(colors: item.gradient!)
                              : null,
                          color: item.gradient == null
                              ? AppColors.surfaceLight
                              : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, color: Colors.white, size: 18),
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.value != null)
                            Text(
                              item.value!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: item.valueColor ?? AppColors.textMuted),
                            ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              color: AppColors.textMuted, size: 16),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(
                          height: 1,
                          color: AppColors.cardBorder,
                          indent: 64),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms);
  }

  // ── Appearance Sheet ────────────────────────────────────────────────────

  void _showAppearanceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, refSheet, _) {
            final themeState = refSheet.watch(themeProvider);

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.textMuted.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Appearance & Theme',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose your display mode and accent theme',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 20),

                      // Display Mode Section
                      Text(
                        'DISPLAY MODE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildModeChip(
                            label: 'System',
                            icon: Icons.brightness_auto,
                            isSelected: themeState.themeMode == ThemeMode.system,
                            onTap: () => refSheet
                                .read(themeProvider.notifier)
                                .setThemeMode(ThemeMode.system),
                          ),
                          const SizedBox(width: 8),
                          _buildModeChip(
                            label: 'Dark',
                            icon: Icons.dark_mode,
                            isSelected: themeState.themeMode == ThemeMode.dark,
                            onTap: () => refSheet
                                .read(themeProvider.notifier)
                                .setThemeMode(ThemeMode.dark),
                          ),
                          const SizedBox(width: 8),
                          _buildModeChip(
                            label: 'Light',
                            icon: Icons.light_mode,
                            isSelected: themeState.themeMode == ThemeMode.light,
                            onTap: () => refSheet
                                .read(themeProvider.notifier)
                                .setThemeMode(ThemeMode.light),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Color Themes Section
                      Text(
                        'COLOR THEMES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...ThemePreset.values.map((preset) {
                        final isSelected = themeState.preset == preset;
                        return GestureDetector(
                          onTap: () => refSheet
                              .read(themeProvider.notifier)
                              .setPreset(preset),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? preset.primary.withValues(alpha: 0.15)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? preset.primary
                                    : AppColors.cardBorder,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    gradient: preset.primaryGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: preset.primary
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  preset.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  Icon(Icons.check_circle,
                                      color: preset.primary, size: 20),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                      ShiningButton(
                        text: 'Apply & Save Theme',
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Theme applied: ${themeState.preset.name} (${themeState.themeMode == ThemeMode.system ? "System" : themeState.themeMode == ThemeMode.light ? "Light" : "Dark"}) ✨'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                        height: 48,
                        width: double.infinity,
                        gradientColors: [themeState.preset.primary, themeState.preset.secondary],
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildModeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rate VisionAI', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Enjoying the app? Please leave us a 5-star review — it helps us continuous innovation!',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Later', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Rate Now ⭐', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildLogout(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GestureDetector(
        onTap: () async {
          await ref.read(authProvider.notifier).logout();
          if (context.mounted) context.go('/login');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: AppColors.error, size: 20),
              SizedBox(width: 10),
              Text('Sign Out',
                  style: TextStyle(
                      color: AppColors.error,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 350.ms);
  }
}

class _SettingItem {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final List<Color>? gradient;
  final Color? valueColor;

  const _SettingItem(
    this.icon,
    this.label,
    this.value,
    this.onTap, {
    this.gradient,
  }) : valueColor = null;
}
