import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/app_models.dart';
import '../../../widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final theme = context.appTheme;

    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.84,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.surface.withValues(alpha: theme.isLight ? 0.98 : 0.97),
                  theme.background.withValues(alpha: theme.isLight ? 0.99 : 0.99),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                right: BorderSide(color: theme.cardBorder),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, user),
                  Expanded(child: _buildMenuItems(context)),
                  _buildBottomSection(context, ref, user),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserModel? user) {
    final theme = context.appTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: theme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (b) => theme.primaryGradient.createShader(b),
            child: const Text(
              'VisionAI',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildMenuItems(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        _sectionLabel('Creation'),
        _menuItem(context, Icons.home_rounded, 'Home', '/dashboard', 0),
        _menuItem(context, Icons.videocam_rounded, 'AI Video Generator', '/video-generator', 1),
        _menuItem(context, Icons.image_rounded, 'AI Image Tools', '/image-tools-hub', 2),

        const SizedBox(height: 8),
        _sectionLabel('Image AI Tools'),
        _imageToolItem(context, Icons.image_outlined, 'Generate Image',
            'generate', const Color(0xFF7C3AED)),
        _imageToolItem(context, Icons.layers_clear_outlined, 'Remove Background',
            'remove_bg', const Color(0xFFEC4899)),
        _imageToolItem(context, Icons.wb_sunny_outlined, 'Remove BG & Relight',
            'relight', const Color(0xFFF59E0B)),
        _imageToolItem(context, Icons.draw_outlined, 'Sketch to Image',
            'sketch', const Color(0xFF6366F1)),
        _colorGradeItem(context),

        const SizedBox(height: 8),
        _sectionLabel('Account'),
        _menuItem(context, Icons.settings_rounded, 'Settings', '/settings', 3),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label,
      String route, int animIndex) {
    final isActive = GoRouterState.of(context).uri.path == route;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.secondary.withValues(alpha: 0.1),
                ])
              : null,
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: isActive ? AppColors.primaryGradient : null,
                color: isActive ? null : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                  size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (isActive) ...[
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: (animIndex * 50).ms).slideX(begin: -0.3);
  }

  Widget _imageToolItem(BuildContext context, IconData icon, String label,
      String tool, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        context.push('/image-tools', extra: tool);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400)),
            const Spacer(),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _colorGradeItem(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        context.push('/color-grade');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.palette_outlined, color: Color(0xFF10B981), size: 18),
            ),
            const SizedBox(width: 12),
            Text('AI Color Grade',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text('RAW + JPG',
                  style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(
      BuildContext context, WidgetRef ref, UserModel? user) {
    final theme = context.appTheme;
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withValues(alpha: theme.isLight ? 0.08 : 0.15),
            theme.secondary.withValues(alpha: theme.isLight ? 0.05 : 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: theme.isLight ? 0.04 : 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(user: user, radius: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'User',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout,
                      color: AppColors.error, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3);
  }
}
