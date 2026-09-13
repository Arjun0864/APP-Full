import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/ads/admob_manager.dart';
import '../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdGate — Shows a real AdMob interstitial ad with fallback to mock countdown.
//
// Strategy:
//   1. On mount, immediately try to show a real AdMob interstitial.
//   2. Wait up to 3 s for the ad to be ready (preloaded by AdMobManager).
//   3. If the real ad shows → onAdCompleted fires when the user dismisses it.
//   4. If AdMob is unavailable / times out → fallback 30-s countdown mock UI.
//   5. Back button is blocked until the ad completes (PopScope canPop: false).
//
// The widget also handles the edge-case where the interstitial fires its
// onAdDismissedFullScreenContent callback BEFORE the widget is mounted
// (very rare, but guarded with _mounted checks).
// ─────────────────────────────────────────────────────────────────────────────

enum AdContext {
  beforeVideoGeneration,
  beforeImageGeneration,
  afterVideoResult,
  afterImageResult,
  pdfTool,
}

class AdGate extends StatefulWidget {
  final VoidCallback onAdCompleted;
  final VoidCallback onAdSkipped;
  final int durationSeconds;
  final AdContext adContext;
  final int adNumber;
  final int totalAds;

  const AdGate({
    super.key,
    required this.onAdCompleted,
    required this.onAdSkipped,
    this.durationSeconds = 8,
    this.adContext = AdContext.afterVideoResult,
    this.adNumber = 1,
    this.totalAds = 1,
  });

  @override
  State<AdGate> createState() => _AdGateState();
}

class _AdGateState extends State<AdGate> with TickerProviderStateMixin {
  // ── Real AdMob state ──────────────────────────────────────────────────────
  /// Whether we have already attempted to show a real ad (prevents double-fire).
  bool _adMobAttempted = false;

  /// True once the real interstitial has been shown (waiting for dismiss).
  bool _adMobShowing = false;

  /// True once the real interstitial was dismissed — triggers onAdCompleted.
  bool _adMobDismissed = false;

  /// True when we give up on AdMob and fall back to the mock UI.
  bool _useFallback = false;

  // ── Fallback countdown state ──────────────────────────────────────────────
  late int _remaining;
  Timer? _countdownTimer;
  bool _completed = false;
  bool _userTriedToSkip = false;

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _ringController;
  late AnimationController _pulseController;
  late AnimationController _bgController;
  late AnimationController _shakeController;

  int _adIndex = 0;

  // ── Mock ad content (used only in fallback) ───────────────────────────────
  static const _ads = [
    _AdContent(
      brand: 'ProCreate Studio',
      tagline: 'Design without limits',
      cta: 'Try Free for 7 Days',
      emoji: '🎨',
      colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
    ),
    _AdContent(
      brand: 'CloudRender Pro',
      tagline: 'Render 10x faster in the cloud',
      cta: 'Start Rendering Now',
      emoji: '☁️',
      colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    ),
    _AdContent(
      brand: 'MotionKit AI',
      tagline: 'Animate anything with AI',
      cta: 'Get Early Access',
      emoji: '🚀',
      colors: [Color(0xFFEC4899), Color(0xFF7C3AED)],
    ),
    _AdContent(
      brand: 'PixelForge',
      tagline: 'Professional photo editing',
      cta: 'Download Free',
      emoji: '✨',
      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
    _AdContent(
      brand: 'SoundWave AI',
      tagline: 'Generate music with AI',
      cta: 'Try Now',
      emoji: '🎵',
      colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
    ),
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _remaining = widget.durationSeconds;
    _adIndex = Random().nextInt(_ads.length);

    _ringController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Kick off real-ad attempt after first frame so context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryRealAd());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ringController.dispose();
    _pulseController.dispose();
    _bgController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Real AdMob interstitial ───────────────────────────────────────────────

  Future<void> _tryRealAd() async {
    if (_adMobAttempted || !mounted) return;
    _adMobAttempted = true;

    final adManager = AdMobManager.instance;

    // Ensure AdMob SDK is initialised.
    await adManager.initialize();

    // Trigger a load if not already in flight.
    if (!adManager.isInterstitialAdReady) {
      await adManager.loadInterstitialAd();
    }

    // Poll for up to 8 s (80 × 100 ms) — gives enough time for ad networks.
    int waited = 0;
    while (!adManager.isInterstitialAdReady && waited < 80) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
    }

    if (!mounted) return;

    if (adManager.isInterstitialAdReady) {
      if (kDebugMode) debugPrint('[AdGate] Showing real AdMob interstitial');

      setState(() => _adMobShowing = true);

      final shown = await adManager.showInterstitialAd(
        onDismissed: _onRealAdDismissed,
      );

      if (!shown) {
        // show() failed immediately — fall back.
        if (mounted) _activateFallback();
      }
      // If shown == true, we wait for _onRealAdDismissed callback.
    } else {
      // Timed out waiting for ad — fall back.
      if (kDebugMode) debugPrint('[AdGate] AdMob not ready after 3 s — using fallback');
      if (mounted) _activateFallback();
    }
  }

  /// Called by AdMobManager when the interstitial is dismissed (or fails to show).
  void _onRealAdDismissed() {
    if (_adMobDismissed) return; // guard against double-fire
    _adMobDismissed = true;
    if (kDebugMode) debugPrint('[AdGate] Real ad dismissed — completing');
    if (mounted) {
      widget.onAdCompleted();
    }
  }

  // ── Fallback countdown ────────────────────────────────────────────────────

  void _activateFallback() {
    if (!mounted) return;
    setState(() {
      _adMobShowing = false;
      _useFallback = true;
    });
    _ringController.forward();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        setState(() => _completed = true);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) widget.onAdCompleted();
        });
      }
    });
  }

  void _onBackAttempt() {
    if (_completed || _adMobDismissed) return;
    setState(() => _userTriedToSkip = true);
    _shakeController.forward(from: 0);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _userTriedToSkip = false);
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _unlockMessage {
    switch (widget.adContext) {
      case AdContext.beforeVideoGeneration:
        return 'Watch all ${widget.totalAds} ads to start generating video';
      case AdContext.beforeImageGeneration:
        return widget.totalAds == 1
            ? 'Watch this ad to generate your image'
            : 'Watch all ${widget.totalAds} ads to generate your image';
      case AdContext.afterVideoResult:
        return 'Watch full ad to see your video';
      case AdContext.afterImageResult:
        return 'Watch full ad to see your image';
      case AdContext.pdfTool:
        return 'Watch full ad to use this tool';
    }
  }

  String get _completedMessage {
    switch (widget.adContext) {
      case AdContext.beforeVideoGeneration:
        return widget.adNumber < widget.totalAds
            ? 'Ad ${widget.adNumber}/${widget.totalAds} done! Next ad...'
            : '✓ All ads complete — starting generation!';
      case AdContext.beforeImageGeneration:
        return widget.adNumber < widget.totalAds
            ? 'Ad ${widget.adNumber}/${widget.totalAds} done! Next ad...'
            : '✓ All ads complete — generating image!';
      case AdContext.afterVideoResult:
        return '✓ Ad complete — showing your video!';
      case AdContext.afterImageResult:
        return '✓ Ad complete — showing your image!';
      case AdContext.pdfTool:
        return '✓ Ad complete — opening tool!';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── State 1: Real ad is showing (full-screen overlay from AdMob SDK) ──
    // We render a minimal loading screen behind the AdMob overlay.
    if (_adMobShowing && !_adMobDismissed) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Container(
            decoration: BoxDecoration(
                gradient: AppColors.backgroundGradient),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation(AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loading ad…',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── State 2: Waiting for AdMob to respond (initial load) ──────────────
    if (!_useFallback && !_adMobShowing) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Container(
            decoration: BoxDecoration(
                gradient: AppColors.backgroundGradient),
            child: Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
        ),
      );
    }

    // ── State 3: Fallback mock countdown UI ───────────────────────────────
    final ad = _ads[_adIndex];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _onBackAttempt(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: BoxDecoration(
              gradient: AppColors.backgroundGradient),
          child: Stack(
            children: [
              _buildBackground(ad),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(ad),
                    if (widget.totalAds > 1) _buildAdProgress(),
                    Expanded(child: _buildAdContent(ad)),
                    _buildBottomBar(ad),
                  ],
                ),
              ),
              if (_userTriedToSkip) _buildSkipWarning(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Fallback UI helpers ───────────────────────────────────────────────────

  Widget _buildBackground(_AdContent ad) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (_, __) => Stack(
        children: [
          Positioned(
            top: -80 + _bgController.value * 40,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ad.colors[0].withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -60 + _bgController.value * 30,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ad.colors[1].withValues(alpha: 0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(_AdContent ad) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.campaign_outlined,
                    color: AppColors.textMuted, size: 13),
                const SizedBox(width: 4),
                Text('AD',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ],
            ),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _shakeController,
            builder: (_, child) {
              final shake =
                  sin(_shakeController.value * pi * 6) * 4;
              return Transform.translate(
                  offset: Offset(shake, 0), child: child);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _remaining <= 5
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _remaining <= 5
                      ? AppColors.success.withValues(alpha: 0.4)
                      : AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _remaining <= 0
                        ? Icons.check_circle
                        : Icons.lock_outline,
                    color: _remaining <= 5
                        ? AppColors.success
                        : AppColors.warning,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _remaining > 0 ? '${_remaining}s' : 'Done!',
                    style: TextStyle(
                      color: _remaining <= 5
                          ? AppColors.success
                          : AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildAdProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: List.generate(widget.totalAds, (i) {
          final isDone = i < widget.adNumber - 1;
          final isCurrent = i == widget.adNumber - 1;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                  right: i < widget.totalAds - 1 ? 6 : 0),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isDone
                    ? AppColors.success
                    : isCurrent
                        ? AppColors.primary
                        : AppColors.surfaceLight,
              ),
              child: isCurrent
                  ? AnimatedBuilder(
                      animation: _ringController,
                      builder: (_, __) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _ringController.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: AppColors.primaryGradient,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAdContent(_AdContent ad) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: ad.colors),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: ad.colors[0].withValues(
                        alpha: 0.25 + _pulseController.value * 0.15),
                    blurRadius: 28 + _pulseController.value * 12,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Center(
                child: Text(ad.emoji,
                    style: const TextStyle(fontSize: 50)),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(
                  begin: const Offset(0.7, 0.7),
                  curve: Curves.elasticOut),
          const SizedBox(height: 28),
          Text(ad.brand,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5),
              textAlign: TextAlign.center)
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3),
          const SizedBox(height: 8),
          Text(ad.tagline,
              style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.4),
              textAlign: TextAlign.center)
              .animate()
              .fadeIn(delay: 350.ms),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: ad.colors),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: ad.colors[0].withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(ad.cta,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
          const SizedBox(height: 32),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _remaining <= 0
                          ? Icons.lock_open
                          : Icons.lock_outline,
                      color: _remaining <= 0
                          ? AppColors.success
                          : AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _remaining <= 0
                            ? _completedMessage
                            : _unlockMessage,
                        style: TextStyle(
                          color: _remaining <= 0
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }

  Widget _buildBottomBar(_AdContent ad) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _ringController,
                      builder: (_, __) => CircularProgressIndicator(
                        value: _ringController.value,
                        strokeWidth: 4,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation(
                          _remaining <= 5
                              ? AppColors.success
                              : ad.colors[0],
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      _remaining > 0 ? '$_remaining' : '✓',
                      style: TextStyle(
                        color: _remaining <= 5
                            ? AppColors.success
                            : AppColors.textPrimary,
                        fontSize: _remaining > 0 ? 15 : 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _remaining > 0
                            ? '$_remaining seconds remaining'
                            : _completedMessage,
                        key: ValueKey(_remaining <= 0),
                        style: TextStyle(
                          color: _remaining <= 5
                              ? AppColors.success
                              : AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: AnimatedBuilder(
                        animation: _ringController,
                        builder: (_, __) => LinearProgressIndicator(
                          value: _ringController.value,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: AlwaysStoppedAnimation(
                            _remaining <= 5
                                ? AppColors.success
                                : ad.colors[0],
                          ),
                          minHeight: 5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: _remaining <= 0
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _remaining <= 0
                    ? AppColors.success.withValues(alpha: 0.35)
                    : AppColors.cardBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _remaining <= 0
                      ? Icons.check_circle
                      : Icons.lock_outline,
                  color: _remaining <= 0
                      ? AppColors.success
                      : AppColors.textMuted,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Text(
                  _remaining <= 0
                      ? 'Reward granted ✓'
                      : 'Skip not available',
                  style: TextStyle(
                    color: _remaining <= 0
                        ? AppColors.success
                        : AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipWarning() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _userTriedToSkip = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.7),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock,
                        color: AppColors.error, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text('Ad Not Complete',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(
                    'You must watch the full ad to receive your reward. Skipping will cancel the generation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _userTriedToSkip = false);
                            _countdownTimer?.cancel();
                            widget.onAdSkipped();
                          },
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.error
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Center(
                              child: Text('Cancel',
                                  style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _userTriedToSkip = false),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text('Keep Watching',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 200.ms).scale(
              begin: const Offset(0.9, 0.9)),
        ),
      ),
    );
  }
}

// ── Mock ad content model ─────────────────────────────────────────────────────

class _AdContent {
  final String brand;
  final String tagline;
  final String cta;
  final String emoji;
  final List<Color> colors;

  const _AdContent({
    required this.brand,
    required this.tagline,
    required this.cta,
    required this.emoji,
    required this.colors,
  });
}
