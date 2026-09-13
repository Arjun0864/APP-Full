import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ads/ad_manager.dart';
import '../../../core/ads/admob_manager.dart';
import '../../../widgets/glass_card.dart';
import '../providers/generation_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../models/app_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PreGenerationAdsScreen
//
// Shows N real AdMob interstitial ads before generation starts.
// Ad count is based on the operation credit cost (see ad_manager.dart).
//
// Flow:
//   1. Show ad counter UI briefly (300ms)
//   2. Show real AdMob interstitial
//   3. When dismissed → move to next ad or start generation
//   4. If AdMob unavailable → show 8-second fallback countdown
//   5. User cancels → go back to dashboard
// ─────────────────────────────────────────────────────────────────────────────

class PreGenerationAdsScreen extends ConsumerStatefulWidget {
  final String prompt;
  final GenerationType generationType;

  const PreGenerationAdsScreen({
    super.key,
    required this.prompt,
    this.generationType = GenerationType.video,
  });

  @override
  ConsumerState<PreGenerationAdsScreen> createState() =>
      _PreGenerationAdsScreenState();
}

class _PreGenerationAdsScreenState
    extends ConsumerState<PreGenerationAdsScreen> {
  late int _totalAds;
  int _currentAd = 0; // 0-based index
  bool _allAdsComplete = false;
  bool _isShowingAd = false;
  bool _generationStarted = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    final isPro = user?.plan != PlanType.free;
    _totalAds = AdManager.instance.getPreAdCount(widget.generationType, isPro);

    WidgetsBinding.instance.addPostFrameCallback((_) => _showNextAd());
  }

  Future<void> _showNextAd() async {
    if (!mounted) return;

    if (_currentAd >= _totalAds) {
      // All ads done — start generation
      setState(() => _allAdsComplete = true);
      await _startGeneration();
      return;
    }

    setState(() => _isShowingAd = true);

    // Ensure AdMob is initialized and an ad is loaded
    await AdMobManager.instance.initialize();

    if (!AdMobManager.instance.isInterstitialAdReady) {
      // Load with timeout
      await AdMobManager.instance.loadInterstitialAd();
    }

    if (!mounted) return;

    if (AdMobManager.instance.isInterstitialAdReady) {
      // Show real AdMob interstitial
      await AdMobManager.instance.showInterstitialAd(
        onDismissed: _onAdDismissed,
      );
    } else {
      // AdMob not available — show a brief "preparing" screen then continue
      // (We don't block the user indefinitely if ads fail to load)
      await Future.delayed(const Duration(seconds: 3));
      _onAdDismissed();
    }
  }

  void _onAdDismissed() {
    if (!mounted) return;
    setState(() {
      _currentAd++;
      _isShowingAd = false;
    });

    if (_currentAd < _totalAds) {
      // Preload next ad while showing between-ads UI
      AdMobManager.instance.loadInterstitialAd();
      // Brief pause between ads
      Future.delayed(const Duration(milliseconds: 500), _showNextAd);
    } else {
      setState(() => _allAdsComplete = true);
      _startGeneration();
    }
  }

  Future<void> _startGeneration() async {
    if (_generationStarted) return;
    _generationStarted = true;

    // Start generation — provider handles async work
    final genFuture = ref.read(generationProvider.notifier).generate(
      widget.prompt,
      type: widget.generationType,
    );

    if (mounted) context.go('/generating');

    await genFuture;
  }

  void _cancelAndGoBack() {
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _cancelAndGoBack(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _allAdsComplete
                    ? _buildAllCompleteUI()
                    : _buildProgressUI(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAllCompleteUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 24,
              ),
            ],
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 40),
        ).animate().scale(begin: const Offset(0, 0), curve: Curves.elasticOut),
        const SizedBox(height: 20),
        Text(
          'Ready!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.generationType == GenerationType.video
              ? 'Starting video generation...'
              : 'Starting image generation...',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildProgressUI() {
    final completedCount = _currentAd;
    final isLastAd = _currentAd == _totalAds - 1;

    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Credit cost badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: AppColors.warning, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${creditCostFor(widget.generationType)} credits • $_totalAds ad${_totalAds == 1 ? '' : 's'} required',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Ad progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalAds, (i) {
              final isDone = i < completedCount;
              final isCurrent = i == completedCount;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isDone ? AppColors.primaryGradient : null,
                  color: isDone
                      ? null
                      : isCurrent
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.surfaceLight,
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : isCurrent
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(AppColors.primary),
                              ),
                            )
                          : Icon(
                              Icons.play_arrow,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          if (_isShowingAd) ...[
            Text(
              'Ad ${completedCount + 1} of $_totalAds',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please watch the ad to continue',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ] else if (completedCount > 0) ...[
            Text(
              'Ad $completedCount/$_totalAds complete',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLastAd ? 'Starting generation...' : 'Loading next ad...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ] else ...[
            Text(
              'Preparing ads...',
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: 20),
          LinearProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
            backgroundColor: AppColors.surfaceLight,
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _cancelAndGoBack,
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }
}
