import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ad Manager — Credit-cost aware ad system
//
// Stability AI credit costs (real pricing):
//   Image Core:    3 credits  → 1 ad (30s)
//   Image Ultra:   8 credits  → 2 ads (30s each)
//   Image SD3:     7 credits  → 2 ads
//   Remove BG:     2 credits  → 1 ad
//   Relight:      10 credits  → 2 ads
//   Sketch:        3 credits  → 1 ad
//   Video (img2vid): 20 credits → 3 ads BEFORE + 1 AFTER
//   Video (txt2vid): 20 credits → 3 ads BEFORE + 1 AFTER
//
// REVENUE PROTECTION:
//   Video generation costs 20 credits on Stability AI.
//   We show 3 ads (30s each = 90s total) before video generation
//   and 1 ad after to reveal the result.
//   Image tools show 1-2 ads based on credit cost.
//   This ensures we never run at a loss on Stability AI calls.
// ─────────────────────────────────────────────────────────────────────────────

const _kPdfUseCountKey = 'pdf_use_count_v2';

/// Generation type — determines how many ads to show
enum GenerationType {
  /// Text-to-video or image-to-video (20 credits) → 3 pre-ads + 1 post-ad
  video,

  /// Free image generation → 1 pre-ad + 1 post-ad
  imageFree,

  /// Image generation (3-8 credits) → 1-2 pre-ads + 1 post-ad
  imageGenerate,

  /// Remove background (2 credits) → 1 pre-ad + 1 post-ad
  imageRemoveBg,

  /// Relight (10 credits) → 2 pre-ads + 1 post-ad
  imageRelight,

  /// Sketch (3 credits) → 1 pre-ad + 1 post-ad
  imageEdit,

  /// Image Ultra (8 credits) → 2 pre-ads + 1 post-ad
  imageUltra,
}

/// Credit cost for each generation type (Stability AI pricing)
int creditCostFor(GenerationType type) {
  switch (type) {
    case GenerationType.imageFree:
      return 0;
    case GenerationType.video:
      return 20;
    case GenerationType.imageGenerate:
      return 3;
    case GenerationType.imageRemoveBg:
      return 2;
    case GenerationType.imageRelight:
      return 10;
    case GenerationType.imageEdit:
      return 3;
    case GenerationType.imageUltra:
      return 8;
  }
}

/// How many PRE-generation ads to show based on generation type
/// Rule: we must show enough ads to cover the Stability AI credit cost
/// MINIMUM 1 ad always shown for free users (even cheap operations)
int preAdsFor(GenerationType type) {
  switch (type) {
    case GenerationType.imageFree:
      return 1;
    case GenerationType.video:
      return 3; // 20 credits — max ads
    case GenerationType.imageRelight:
      return 2; // 10 credits
    case GenerationType.imageUltra:
      return 2; // 8 credits
    case GenerationType.imageGenerate:
      return 1; // 3 credits
    case GenerationType.imageRemoveBg:
      return 1; // 2 credits
    case GenerationType.imageEdit:
      return 1; // 3 credits
  }
}

/// Whether to show a POST-result ad (to reveal the result)
/// Always true for free users — minimum 1 ad per operation
bool showPostAdFor(GenerationType type) {
  // Show post-ad for all operations (minimum 1 ad rule)
  return true;
}

/// How many ads to show based on credit cost (legacy helper)
int adsForCreditCost(int credits) {
  if (credits <= 1) return 0;
  if (credits <= 3) return 1;
  if (credits <= 8) return 2;
  return 3;
}

class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  // ── Should show ad? ───────────────────────────────────────────────────────

  /// Video generation: always show 3 ads before starting (20 credit cost)
  bool shouldShowPreGenerationAds(bool isPro) => !isPro;

  /// After video/image result: always show 1 ad before revealing
  bool shouldShowPostResultAd(bool isPro) => !isPro;

  /// Get pre-ad count for a generation type (free users only)
  int getPreAdCount(GenerationType type, bool isPro) {
    if (isPro) return 0;
    return preAdsFor(type);
  }

  /// Get whether to show post-result ad
  bool getShowPostAd(GenerationType type, bool isPro) {
    if (isPro) return false;
    return showPostAdFor(type);
  }

  /// PDF tools: show ad every 3rd use
  Future<bool> shouldShowPdfAd(bool isPro) async {
    if (isPro) return false;
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_kPdfUseCountKey) ?? 0;
    final newCount = count + 1;
    await prefs.setInt(_kPdfUseCountKey, newCount);
    // Show ad on 1st, 4th, 7th use etc. (every 3rd)
    return newCount % 3 == 1;
  }

  /// Reset PDF use count (on logout)
  Future<void> resetPdfCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPdfUseCountKey);
  }
}

// ── Ad reward state ───────────────────────────────────────────────────────────

enum AdRewardStatus {
  idle,           // No ad running
  watching,       // Ad is playing
  completed,      // Full ad watched — reward granted
  skipped,        // User skipped/closed — no reward
}

class AdRewardNotifier extends StateNotifier<AdRewardStatus> {
  AdRewardNotifier() : super(AdRewardStatus.idle);

  void startWatching() => state = AdRewardStatus.watching;
  void complete() => state = AdRewardStatus.completed;
  void skip() => state = AdRewardStatus.skipped;
  void reset() => state = AdRewardStatus.idle;
}

final adRewardProvider =
    StateNotifierProvider<AdRewardNotifier, AdRewardStatus>((ref) {
  return AdRewardNotifier();
});

// ── Pre-generation ad queue state ─────────────────────────────────────────────

class PreGenAdState {
  final int totalAds;       // How many ads to show (3 for video)
  final int completedAds;   // How many completed so far
  final bool allCompleted;  // All ads done → can proceed

  const PreGenAdState({
    this.totalAds = 3,
    this.completedAds = 0,
    this.allCompleted = false,
  });

  PreGenAdState copyWith({int? completedAds, bool? allCompleted}) {
    return PreGenAdState(
      totalAds: totalAds,
      completedAds: completedAds ?? this.completedAds,
      allCompleted: allCompleted ?? this.allCompleted,
    );
  }

  double get progress => totalAds > 0 ? completedAds / totalAds : 0;
  int get remaining => totalAds - completedAds;
}

class PreGenAdNotifier extends StateNotifier<PreGenAdState> {
  PreGenAdNotifier() : super(const PreGenAdState());

  void start({int totalAds = 3}) {
    state = PreGenAdState(totalAds: totalAds, completedAds: 0);
  }

  void completeOne() {
    final newCompleted = state.completedAds + 1;
    state = state.copyWith(
      completedAds: newCompleted,
      allCompleted: newCompleted >= state.totalAds,
    );
  }

  void reset() => state = const PreGenAdState();
}

final preGenAdProvider =
    StateNotifierProvider<PreGenAdNotifier, PreGenAdState>((ref) {
  return PreGenAdNotifier();
});
