import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
// import 'terms_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _navigated = false;
  bool _minTimeElapsed = false;
  AuthStatus? _resolvedStatus;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Start minimum splash timer
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        _minTimeElapsed = true;
        _tryNavigate();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _tryNavigate() {
    if (_navigated || !_minTimeElapsed) return;
    _navigated = true;
    _navigate(_resolvedStatus ?? AuthStatus.authenticated);
  }

  void _navigate(AuthStatus status) async {
    // ── TEMPORARILY COMMENTED OUT FOR TESTING DIRECT APP ACCESS ──
    // final termsAccepted = await TermsScreen.hasAccepted();
    // if (!termsAccepted) {
    //   if (mounted) context.go('/terms');
    //   return;
    // }
    //
    // // Navigate based on auth status
    // if (status == AuthStatus.authenticated) {
    //   if (mounted) context.go('/dashboard');
    // } else {
    //   if (mounted) context.go('/login');
    // }
    // ─────────────────────────────────────────────────────────────

    // Direct access to dashboard after initialization animation
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state — once it resolves from 'initial', store and try navigate
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status != AuthStatus.initial && next.status != AuthStatus.loading) {
        _resolvedStatus = next.status;
        _tryNavigate();
      }
    });

    // Also handle if already resolved on first build (e.g. Firebase auth state
    // resolved before this widget was built — the main auth persistence fix)
    final authState = ref.watch(authProvider);
    if (authState.status != AuthStatus.initial && authState.status != AuthStatus.loading) {
      if (_resolvedStatus == null) {
        _resolvedStatus = authState.status;
        // Schedule navigation attempt after this frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryNavigate();
        });
      }
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              left: -100,
              child: _buildOrb(300, AppColors.primary.withValues(alpha: 0.3)),
            ),
            Positioned(
              bottom: -80,
              right: -80,
              child: _buildOrb(250, AppColors.secondary.withValues(alpha: 0.25)),
            ),
            Positioned(
              top: 200,
              right: -60,
              child: _buildOrb(180, AppColors.accent.withValues(alpha: 0.2)),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 32),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.accentGradient.createShader(bounds),
                    child: const Text(
                      'VisionAI',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 800.ms)
                      .slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 8),
                  Text(
                    'Create stunning videos with AI',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ).animate().fadeIn(delay: 900.ms, duration: 600.ms),
                  const SizedBox(height: 60),
                  _buildLoadingIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 50),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1, 1),
          curve: Curves.elasticOut,
        )
        .then()
        .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.3));
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        SizedBox(
          width: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              backgroundColor: AppColors.cardBg,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ).animate().fadeIn(delay: 1200.ms, duration: 400.ms),
        const SizedBox(height: 16),
        Text(
          'Initializing AI Engine...',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ).animate().fadeIn(delay: 1400.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildOrb(double size, Color color) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: size + (_pulseController.value * 20),
          height: size + (_pulseController.value * 20),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        );
      },
    );
  }
}
