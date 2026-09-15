import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../models/app_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../color_grade/models/color_grade_models.dart';
import '../../color_grade/providers/color_grade_provider.dart';

/// Platform-aware shell widget used by [ShellRoute].
///
/// On desktop (Windows / macOS / Linux): wraps [child] inside [DesktopShell],
/// providing the persistent top TabBar and full-screen desktop layout.
///
/// On mobile / web: passes [child] through unchanged so each screen can render
/// its own [Scaffold] with a [BottomNavigationBar].
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (isDesktop) {
      return DesktopShell(child: child);
    }
    return child;
  }
}

class DesktopShell extends ConsumerStatefulWidget {
  final Widget child;
  const DesktopShell({super.key, required this.child});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final routerState = GoRouterState.of(context);
    final currentRoute = routerState.uri.toString();
    final user = ref.watch(authProvider).user;
    final colorGradeState = ref.watch(colorGradeProvider);

    return Scaffold(
      backgroundColor: theme.background,
      body: Column(
        children: [
          // ── Sleek Desktop Studio Top TabBar Header ────────────────────────
          _buildDesktopTopTabBar(context, theme, currentRoute, user),

          // ── Main Workspace Body with Animated Route Transitions ───────────
          Expanded(
            child: Container(
              color: theme.background,
              child: widget.child,
            ),
          ),

          // ── Bottom Master Batch Progress (When Active) ────────────────────
          if (colorGradeState.status == ColorGradeStatus.processingBatch ||
              colorGradeState.batchItems.isNotEmpty)
            _buildMasterJobProgressFooter(context, theme, colorGradeState),
        ],
      ),
    );
  }

  Widget _buildDesktopTopTabBar(
    BuildContext context,
    AppCustomTheme theme,
    String currentRoute,
    UserModel? user,
  ) {
    final tabs = [
      const _DesktopTabItem(
        label: 'Color Grade',
        route: '/dashboard',
        icon: Icons.palette_outlined,
        activeIcon: Icons.palette_rounded,
      ),
      const _DesktopTabItem(
        label: 'Video Studio',
        route: '/video-generator',
        icon: Icons.movie_creation_outlined,
        activeIcon: Icons.movie_creation_rounded,
      ),
      const _DesktopTabItem(
        label: 'Image Hub',
        route: '/image-tools-hub',
        icon: Icons.auto_fix_high_outlined,
        activeIcon: Icons.auto_fix_high_rounded,
      ),
      const _DesktopTabItem(
        label: 'Projects',
        route: '/my-videos',
        icon: Icons.folder_copy_outlined,
        activeIcon: Icons.folder_copy_rounded,
      ),
      const _DesktopTabItem(
        label: 'Settings',
        route: '/settings',
        icon: Icons.tune_rounded,
        activeIcon: Icons.tune_rounded,
      ),
    ];

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.cardBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo & Studio Branding
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppColors.goldLinearGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldBase.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AIVista Studio',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Text(
                    'PRO EDITION',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.goldLight,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(width: 32),

          // Central Top TabBar with Smooth Animated Pill Indicator
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: tabs.map((tab) {
                    final isSelected = tab.route == currentRoute ||
                        (tab.route == '/dashboard' && (currentRoute == '/' || currentRoute.contains('/color-grade')));

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          if (!isSelected) {
                            context.go(tab.route);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.goldBase.withValues(alpha: 0.16)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.goldBase.withValues(alpha: 0.4)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? tab.activeIcon : tab.icon,
                                size: 16,
                                color: isSelected ? AppColors.goldLight : theme.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tab.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? theme.textPrimary : theme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Right Controls: Theme Toggle & User Workspace
          Row(
            children: [
              Consumer(builder: (context, ref, _) {
                final themeState = ref.watch(themeProvider);
                return IconButton(
                  tooltip: themeState.isLight ? 'Dark Mode' : 'Light Mode',
                  icon: Icon(
                    themeState.isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    size: 18,
                    color: theme.textSecondary,
                  ),
                  onPressed: () {
                    ref.read(themeProvider.notifier).setThemeMode(
                          themeState.isLight ? ThemeMode.dark : ThemeMode.light,
                        );
                  },
                  splashRadius: 16,
                );
              }),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.cardBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: AppColors.goldBase.withValues(alpha: 0.2),
                      child: Text(
                        user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'C',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.goldLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user?.name ?? 'Creator',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildMasterJobProgressFooter(
    BuildContext context,
    AppCustomTheme theme,
    ColorGradeState state,
  ) {
    final total = state.batchItems.length;
    final completed = state.batchItems.where((i) => i.status == ColorGradeItemStatus.completed).length;
    final failed = state.batchItems.where((i) => i.status == ColorGradeItemStatus.failed).length;
    final progress = total > 0 ? (completed + failed) / total : 0.0;
    final isProcessing = state.status == ColorGradeStatus.processingBatch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.cardBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isProcessing ? AppColors.goldBase.withValues(alpha: 0.15) : AppColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isProcessing ? Icons.sync : Icons.check_circle_outline,
              size: 16,
              color: isProcessing ? AppColors.goldLight : AppColors.success,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isProcessing
                          ? 'Processing Master Batch ($completed/$total images completed)'
                          : 'Master Batch Ready: $completed completed, $failed failed ($total total)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: theme.cardBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.goldBase),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isProcessing) ...[
            OutlinedButton.icon(
              onPressed: () {
                ref.read(colorGradeProvider.notifier).cancelBatch();
              },
              icon: const Icon(Icons.close, size: 14, color: AppColors.error),
              label: const Text('Cancel', style: TextStyle(fontSize: 11, color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopTabItem {
  final String label;
  final String route;
  final IconData icon;
  final IconData activeIcon;

  const _DesktopTabItem({
    required this.label,
    required this.route,
    required this.icon,
    required this.activeIcon,
  });
}
