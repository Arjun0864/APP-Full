import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/ads/admob_manager.dart';
import '../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BannerAdWidget — Adaptive banner ad
//
// Usage:
//   const BannerAdWidget()
//
// Features:
//   - Adaptive banner size (fills available width)
//   - Graceful loading state (shimmer placeholder)
//   - Graceful failure (hides widget if ad fails to load)
//   - Auto-disposes ad on widget removal
// ─────────────────────────────────────────────────────────────────────────────

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _hasFailed = false;
  AdSize? _adSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final adSize = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);

    if (adSize == null) {
      setState(() => _hasFailed = true);
      return;
    }

    _adSize = adSize;

    final ad = BannerAd(
      adUnitId: AdMobManager.bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _hasFailed = true);
        },
      ),
    );

    await ad.load();
    if (mounted) {
      setState(() => _bannerAd = ad);
    } else {
      ad.dispose();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if ad failed
    if (_hasFailed) return const SizedBox.shrink();

    // Show placeholder while loading
    if (!_isLoaded || _bannerAd == null || _adSize == null) {
      return Container(
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation(AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Loading ad...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      alignment: Alignment.center,
      width: _adSize!.width.toDouble(),
      height: _adSize!.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
