import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

typedef RewardedAdEventCallback = void Function(
  String eventType, {
  String? errorCode,
  String? message,
});

// ─────────────────────────────────────────────────────────────────────────────
// AdMobManager — Production Google Ads integration
//
// App IDs (hardcoded — these go in AndroidManifest.xml / Info.plist too):
//   Android App ID: ca-app-pub-8917206938698127~6142739695
//   iOS App ID:     (add your iOS App ID here)
//
// Production Ad Unit IDs:
//   Banner:       ca-app-pub-8917206938698127/7064663453
//   Interstitial: ca-app-pub-8917206938698127/4673314150
//   Rewarded:     ca-app-pub-8917206938698127/9945822132
// ─────────────────────────────────────────────────────────────────────────────

class AdMobManager {
  AdMobManager._();
  static final AdMobManager instance = AdMobManager._();

  bool _initialized = false;

  // ── Ad Unit IDs ───────────────────────────────────────────────────────────

  /// Banner ad unit ID
  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    }
    // Production IDs
    return Platform.isAndroid
        ? 'ca-app-pub-8917206938698127/7064663453'
        : 'ca-app-pub-8917206938698127/7064663453'; // Replace with iOS ID
  }

  /// Interstitial ad unit ID
  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910';
    }
    return Platform.isAndroid
        ? 'ca-app-pub-8917206938698127/4673314150'
        : 'ca-app-pub-8917206938698127/4673314150'; // Replace with iOS ID
  }

  /// Rewarded ad unit ID
  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
    }
    return Platform.isAndroid
        ? 'ca-app-pub-8917206938698127/9945822132'
        : 'ca-app-pub-8917206938698127/9945822132'; // Replace with iOS ID
  }

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    try {
      final initStatus = await MobileAds.instance.initialize();
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[AdMob] Initialized');
        for (final entry in initStatus.adapterStatuses.entries) {
          debugPrint('[AdMob] Adapter ${entry.key}: ${entry.value.state}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AdMob] Init failed: $e');
    }
  }

  // ── Interstitial Ad ───────────────────────────────────────────────────────

  InterstitialAd? _interstitialAd;
  bool _interstitialLoading = false;
  Completer<void>? _interstitialLoadCompleter;

  Future<void> loadInterstitialAd() async {
    if (_interstitialLoading || _interstitialAd != null) return;
    _interstitialLoading = true;
    _interstitialLoadCompleter = Completer<void>();

    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoading = false;
          if (kDebugMode) debugPrint('[AdMob] Interstitial loaded');
          if (_interstitialLoadCompleter?.isCompleted == false) {
            _interstitialLoadCompleter!.complete();
          }
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          if (kDebugMode) debugPrint('[AdMob] Interstitial load failed: ${error.message}');
          if (_interstitialLoadCompleter?.isCompleted == false) {
            _interstitialLoadCompleter!.complete();
          }
        },
      ),
    );

    await _interstitialLoadCompleter!.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _interstitialLoading = false;
        if (kDebugMode) debugPrint('[AdMob] Interstitial load timed out');
      },
    );
  }

  /// Show interstitial ad. Calls [onDismissed] when user closes it (or on failure).
  /// Returns true if the ad was shown, false if not available.
  Future<bool> showInterstitialAd({VoidCallback? onDismissed}) async {
    if (_interstitialAd == null) {
      await loadInterstitialAd();
      if (_interstitialAd == null) {
        onDismissed?.call(); // continue even if no ad
        return false;
      }
    }

    final ad = _interstitialAd!;
    _interstitialAd = null; // Clear before show to prevent double-show

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadInterstitialAd(); // Preload next
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (kDebugMode) debugPrint('[AdMob] Interstitial show failed: ${error.message}');
        loadInterstitialAd();
        onDismissed?.call(); // Continue even if ad fails
      },
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) debugPrint('[AdMob] Interstitial showing');
      },
    );

    await ad.show();
    return true;
  }

  // ── Rewarded Ad ───────────────────────────────────────────────────────────

  RewardedAd? _rewardedAd;
  bool _rewardedLoading = false;
  Completer<void>? _rewardedLoadCompleter;

  Future<bool> loadRewardedAd({
    RewardedAdEventCallback? onEvent,
  }) async {
    if (_rewardedLoading || _rewardedAd != null) return _rewardedAd != null;
    _rewardedLoading = true;
    _rewardedLoadCompleter = Completer<void>();
    var callbackFired = false;

    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoading = false;
          callbackFired = true;
          if (kDebugMode) debugPrint('[AdMob] Rewarded ad loaded');
          onEvent?.call('load_success');
          if (_rewardedLoadCompleter?.isCompleted == false) {
            _rewardedLoadCompleter!.complete();
          }
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          callbackFired = true;
          if (kDebugMode) debugPrint('[AdMob] Rewarded load failed: ${error.message}');
          onEvent?.call(
            'load_failure',
            errorCode: error.code.toString(),
            message: error.message,
          );
          if (_rewardedLoadCompleter?.isCompleted == false) {
            _rewardedLoadCompleter!.complete();
          }
        },
      ),
    );

    await _rewardedLoadCompleter!.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _rewardedLoading = false;
        if (!_rewardedLoadCompleter!.isCompleted) {
          _rewardedLoadCompleter!.complete();
        }
        if (!callbackFired) {
          if (kDebugMode) debugPrint('[AdMob] Rewarded load timed out');
          onEvent?.call('load_failure', message: 'Rewarded ad load timed out');
        }
      },
    );

    return _rewardedAd != null;
  }

  /// Show rewarded ad. Returns credits earned (0 if ad not shown or user skipped).
  Future<int> showRewardedAd({
    int creditsReward = 2,
    RewardedAdEventCallback? onEvent,
  }) async {
    if (_rewardedAd == null) {
      await loadRewardedAd(onEvent: onEvent);
      if (_rewardedAd == null) {
        onEvent?.call('load_failure', message: 'Rewarded ad is not available');
        return 0;
      }
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;

    final completer = Completer<int>();
    var errorReported = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardedAd(); // Preload next
        if (!completer.isCompleted) completer.complete(0);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (kDebugMode) debugPrint('[AdMob] Rewarded show failed: ${error.message}');
        loadRewardedAd();
        if (!errorReported) {
          errorReported = true;
          onEvent?.call(
            'load_failure',
            errorCode: 'show_failed',
            message: error.message,
          );
        }
        if (!completer.isCompleted) completer.complete(0);
      },
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) debugPrint('[AdMob] Rewarded ad showing');
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        if (kDebugMode) debugPrint('[AdMob] User earned reward: ${reward.amount} ${reward.type}');
        if (!completer.isCompleted) {
          onEvent?.call('earned');
          completer.complete(creditsReward);
        }
      },
    );

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        if (!errorReported) {
          onEvent?.call('load_failure', message: 'Rewarded ad show timed out');
        }
        return 0;
      },
    );
  }

  bool get isRewardedAdReady => _rewardedAd != null;
  bool get isInterstitialAdReady => _interstitialAd != null;

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
  }
}
