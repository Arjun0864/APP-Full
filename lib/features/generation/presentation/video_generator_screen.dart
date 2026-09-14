import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/animated_input.dart';
import '../../../widgets/shining_button.dart';
import '../../dashboard/presentation/bottom_nav_bar.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/ads/ad_manager.dart';

class VideoGeneratorScreen extends ConsumerStatefulWidget {
  const VideoGeneratorScreen({super.key});

  @override
  ConsumerState<VideoGeneratorScreen> createState() =>
      _VideoGeneratorScreenState();
}

class _VideoGeneratorScreenState extends ConsumerState<VideoGeneratorScreen> {
  final _promptController = TextEditingController();
  String _selectedAspectRatio = '16:9';

  static const _aspectRatios = [
    {'ratio': '16:9', 'label': 'Landscape (16:9)', 'icon': Icons.crop_16_9},
    {'ratio': '9:16', 'label': 'Portrait (9:16)', 'icon': Icons.crop_portrait},
    {'ratio': '1:1', 'label': 'Square (1:1)', 'icon': Icons.crop_square},
  ];

  static const _samplePrompts = [
    'Cinematic drone shot of cyber metropolis in neon rain at night',
    'Hyper-realistic slow motion wave crashing on golden sand beach',
    'Mystical glowing forest with floating crystal butterflies',
    'Futuristic sports car speeding across a desert highway at dusk',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _onGenerate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a video prompt first'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final online = await ConnectivityService.instance.requireInternet(
      context,
      featureName: 'AI Video Generation',
    );
    if (!online || !mounted) return;

    _promptController.clear();

    // Navigate to pre-gen ad or directly to generating
    context.push(
      '/pre-gen-ads',
      extra: {
        'prompt': prompt,
        'generationType': GenerationType.video,
        'aspectRatio': _selectedAspectRatio,
      },
    );
  }

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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.videocam_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Video Generator',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Transform text ideas into cinematic videos',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Prompt Box
                      Text(
                        'PROMPT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedInput(
                        hint: 'Describe the scene, motion, lighting and style in detail...',
                        controller: _promptController,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 20),

                      // Aspect Ratio Selector
                      Text(
                        'ASPECT RATIO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: _aspectRatios.map((item) {
                          final isSelected = item['ratio'] == _selectedAspectRatio;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() =>
                                  _selectedAspectRatio = item['ratio'] as String),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF3B82F6),
                                            Color(0xFF7C3AED)
                                          ],
                                        )
                                      : null,
                                  color: isSelected ? null : AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : AppColors.cardBorder,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      item['icon'] as IconData,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item['ratio'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Inspiration prompts
                      Text(
                        'INSPIRATION IDEAS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._samplePrompts.map((p) => GestureDetector(
                            onTap: () => setState(() => _promptController.text = p),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.auto_awesome,
                                      size: 14, color: AppColors.primaryLight),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      p,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                      const SizedBox(height: 24),

                      // Shining CTA Button
                      ShiningButton(
                        text: 'Generate AI Video',
                        onPressed: _onGenerate,
                        height: 52,
                        width: double.infinity,
                        gradientColors: const [
                          Color(0xFF3B82F6),
                          Color(0xFF7C3AED)
                        ],
                        icon: const Icon(Icons.videocam_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              if (!_isDesktop(context)) const BottomNavBar(currentIndex: 1),
            ],
          ),
        ),
      ),
    );
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux ||
        MediaQuery.of(context).size.width >= 800;
  }
}
