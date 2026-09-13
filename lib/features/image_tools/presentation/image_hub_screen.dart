import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../dashboard/presentation/bottom_nav_bar.dart';

class ImageHubScreen extends StatelessWidget {
  const ImageHubScreen({super.key});

  static const _tools = [
    _Tool('generate', 'Generate Image', 'Create from text prompt', Icons.image_outlined, Color(0xFF7C3AED)),
    _Tool('remove_bg', 'Remove BG', 'Clean background removal', Icons.layers_clear_outlined, Color(0xFFEC4899)),
    _Tool('relight', 'Relight', 'Remove BG & add lighting', Icons.wb_sunny_outlined, Color(0xFFF59E0B)),
    _Tool('sketch', 'Sketch to Image', 'Turn sketches to photos', Icons.draw_outlined, Color(0xFF6366F1)),
    _Tool('color_grade', 'AI Color Grade', 'Apply reference grade to RAWs', Icons.palette_outlined, Color(0xFF10B981)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Scaffold(
      backgroundColor: theme.background,
      body: Container(
        decoration: BoxDecoration(gradient: theme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
                      child: const Icon(Icons.image, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AI Image Tools',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Create, edit, and enhance images with AI',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
              // Tools grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _tools.length,
                  itemBuilder: (context, index) {
                    final tool = _tools[index];
                    return GestureDetector(
                      onTap: () {
                        if (tool.id == 'color_grade') {
                          context.push('/color-grade');
                        } else {
                          context.push('/image-tools', extra: tool.id);
                        }
                      },
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: tool.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(tool.icon, color: tool.color, size: 26),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              tool.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tool.subtitle,
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: (index * 70).ms, duration: 300.ms).slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 300.ms, curve: Curves.easeOutCubic);
                  },
                ),
              ),
              const BottomNavBar(currentIndex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tool {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _Tool(this.id, this.title, this.subtitle, this.icon, this.color);
}
