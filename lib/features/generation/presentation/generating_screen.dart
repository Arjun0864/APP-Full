import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ads/ad_manager.dart';
import '../../../core/ads/admob_manager.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../models/app_models.dart';
import '../providers/generation_provider.dart';

class GeneratingScreen extends ConsumerStatefulWidget {
  const GeneratingScreen({super.key});

  @override
  ConsumerState<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends ConsumerState<GeneratingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _pulseController;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Keep screen awake during generation
    WakelockPlus.enable();
    
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // Preload ad for after generation
    AdMobManager.instance.loadInterstitialAd();
  }

  @override
  void dispose() {
    // Allow screen to turn off again
    WakelockPlus.disable();
    _rotateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generationProvider);

    // Handle completion - show interstitial ad then navigate to result
    if (state.step == GenerationStep.completed && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final user = ref.read(authProvider).user;
        final isPro = user?.plan != PlanType.free;
        final shouldShowAd = AdManager.instance.shouldShowPostResultAd(isPro);

        if (shouldShowAd && AdMobManager.instance.isInterstitialAdReady) {
          // Show post-generation interstitial, then go to result
          await AdMobManager.instance.showInterstitialAd(
            onDismissed: () {
              if (mounted) context.go('/result');
            },
          );
        } else {
          // No ad or pro user — go directly to result
          if (mounted) context.go('/result');
        }
      });
    }

    // Handle failure - show error and go back to dashboard
    if (state.step == GenerationStep.failed && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 24),
                  const SizedBox(width: 10),
                  Text('Generation Failed', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
                ],
              ),
              content: Text(
                state.error ?? 'Something went wrong. Please try again.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(generationProvider.notifier).reset();
                    context.go('/dashboard');
                  },
                  child: Text('OK', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          );
        }
      });
    }

    // Handle idle state (navigated here without starting generation)
    if (state.step == GenerationStep.idle && !_navigated) {
      // Show minimal loader while generation starts
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Stack(
          children: [
            _buildParticles(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    _buildProgressRing(state.progress),
                    const SizedBox(height: 48),
                    _buildStatusText(state.statusMessage),
                    const SizedBox(height: 24),
                    _buildSteps(state.step),
                    const Spacer(),
                    _buildPromptPreview(state.prompt),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticles() {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(_rotateController.value),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildProgressRing(double progress) {
    final genState = ref.watch(generationProvider);
    final isImage = genState.isImageGeneration;
    final progressColor = isImage ? AppColors.accent : AppColors.primary;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: progressColor.withValues(alpha: 0.3 + _pulseController.value * 0.2),
                blurRadius: 40 + _pulseController.value * 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: CircularPercentIndicator(
            radius: 90,
            lineWidth: 8,
            percent: progress.clamp(0.0, 1.0),
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (b) => (isImage
                          ? AppColors.accentGradient
                          : AppColors.primaryGradient)
                      .createShader(b),
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  isImage ? 'rendering' : 'complete',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
            progressColor: progressColor,
            backgroundColor: AppColors.surfaceLight,
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 500,
          ),
        );
      },
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8));
  }

  Widget _buildStatusText(String message) {
    final state = ref.watch(generationProvider);
    final title = state.isImageGeneration
        ? 'Generating Your Image'
        : 'Generating Your Video';

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            title,
            key: ValueKey(title),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            message,
            key: ValueKey(message),
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSteps(GenerationStep currentStep) {
    final genState = ref.watch(generationProvider);
    final isImage = genState.isImageGeneration;

    final steps = isImage
        ? [
            const _StepInfo('Understanding prompt', GenerationStep.understanding, Icons.psychology_outlined),
            const _StepInfo('Preparing composition', GenerationStep.preparing, Icons.palette_outlined),
            const _StepInfo('Generating image', GenerationStep.generating, Icons.image_outlined),
            const _StepInfo('Finalizing', GenerationStep.finalizing, Icons.check_circle_outline),
          ]
        : [
            const _StepInfo('Understanding prompt', GenerationStep.understanding, Icons.psychology_outlined),
            const _StepInfo('Preparing visuals', GenerationStep.preparing, Icons.palette_outlined),
            const _StepInfo('Generating video', GenerationStep.generating, Icons.movie_creation_outlined),
            const _StepInfo('Finalizing', GenerationStep.finalizing, Icons.check_circle_outline),
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final step = entry.value;
          final index = entry.key;
          final stepIndex = GenerationStep.values.indexOf(currentStep);
          final thisIndex = GenerationStep.values.indexOf(step.step);
          final isDone = stepIndex > thisIndex;
          final isActive = stepIndex == thisIndex;

          return Padding(
            padding: EdgeInsets.only(bottom: index < steps.length - 1 ? 16 : 0),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: isDone || isActive ? AppColors.primaryGradient : null,
                    color: isDone || isActive ? null : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDone ? Icons.check : step.icon,
                    color: isDone || isActive ? Colors.white : AppColors.textMuted,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  step.label,
                  style: TextStyle(
                    color: isDone || isActive ? AppColors.textPrimary : AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const Spacer(),
                if (isActive)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                if (isDone)
                  const Icon(Icons.check_circle, color: AppColors.success, size: 18),
              ],
            ),
          ).animate().fadeIn(delay: (index * 100).ms);
        }).toList(),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3);
  }

  Widget _buildPromptPreview(String prompt) {
    if (prompt.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.format_quote, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              prompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }
}

class _StepInfo {
  final String label;
  final GenerationStep step;
  final IconData icon;
  const _StepInfo(this.label, this.step, this.icon);
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 3 + 1;
      final opacity = (sin(progress * 2 * pi + i) * 0.5 + 0.5) * 0.3;

      paint.color = (i % 3 == 0
              ? AppColors.primary
              : i % 3 == 1
                  ? AppColors.secondary
                  : AppColors.accent)
          .withValues(alpha: opacity);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
