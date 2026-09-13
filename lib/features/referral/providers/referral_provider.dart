import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/secure_http_client.dart';
import '../../auth/providers/auth_provider.dart';

final referralProvider = StateNotifierProvider<ReferralNotifier, ReferralState>((ref) {
  return ReferralNotifier(ref);
});

class ReferralState {
  final bool loading;
  final String? referralCode;
  final String? referredBy;
  final int totalReferrals;
  final int totalCreditsEarned;
  final List<Map<String, dynamic>> history;
  final String? error;
  final bool applied;

  ReferralState({
    this.loading = false,
    this.referralCode,
    this.referredBy,
    this.totalReferrals = 0,
    this.totalCreditsEarned = 0,
    this.history = const [],
    this.error,
    this.applied = false,
  });

  ReferralState copyWith({
    bool? loading,
    String? referralCode,
    String? referredBy,
    int? totalReferrals,
    int? totalCreditsEarned,
    List<Map<String, dynamic>>? history,
    String? error,
    bool? applied,
  }) {
    return ReferralState(
      loading: loading ?? this.loading,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      totalReferrals: totalReferrals ?? this.totalReferrals,
      totalCreditsEarned: totalCreditsEarned ?? this.totalCreditsEarned,
      history: history ?? this.history,
      error: error,
      applied: applied ?? this.applied,
    );
  }
}

class ReferralNotifier extends StateNotifier<ReferralState> {
  final Ref _ref;
  ReferralNotifier(this._ref) : super(ReferralState()) {
    _loadReferralInfo();
  }

  Future<void> _loadReferralInfo() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final resp = await SecureHttpClient.instance.get('/referral/me');
      if (!resp.success) throw Exception(resp.errorMessage);
      final data = resp.data as Map<String, dynamic>;
      state = state.copyWith(
        referralCode: data['referral_code'] as String?,
        referredBy: data['referred_by'] as String?,
        totalReferrals: data['total_referrals'] as int? ?? 0,
        applied: data['referred_by'] != null,
      );

      // Load history and compute total credits earned
      await _loadHistory();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final resp = await SecureHttpClient.instance.get('/referral/history');
      if (!resp.success) return;
      final data = resp.data as Map<String, dynamic>;
      final items = (data['history'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

      var total = 0;
      for (final it in items) {
        total += (it['credits_awarded'] as int? ?? 0);
      }

      state = state.copyWith(history: items, totalCreditsEarned: total);
    } catch (_) {
      // Non-fatal
    }
  }

  Future<void> applyReferralCode(String code) async {
    if (state.applied) return; // already applied
    state = state.copyWith(loading: true, error: null);
    try {
      final resp = await SecureHttpClient.instance.post('/referral/apply', body: {'referral_code': code.trim().toUpperCase()});
      if (!resp.success) {
        state = state.copyWith(error: resp.errorMessage ?? 'Failed to apply referral code');
        return;
      }
      final data = resp.data as Map<String, dynamic>;
      state = state.copyWith(
        referralCode: data['referral_code'] as String?,
        referredBy: data['referred_by'] as String?,
        totalReferrals: data['total_referrals'] as int? ?? 0,
        applied: true,
      );
      await _ref.read(authProvider.notifier).refreshUserData();
      // Refresh history
      await _loadHistory();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }
}
