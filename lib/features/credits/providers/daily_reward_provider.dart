import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/secure_http_client.dart';
import '../../auth/providers/auth_provider.dart';

class DailyRewardState {
  final bool isLoading;
  final bool claimable;
  final DateTime? lastClaimTime;
  final DateTime? nextClaimTime;
  final String? error;

  const DailyRewardState({
    this.isLoading = false,
    this.claimable = true,
    this.lastClaimTime,
    this.nextClaimTime,
    this.error,
  });

  DailyRewardState copyWith({
    bool? isLoading,
    bool? claimable,
    DateTime? lastClaimTime,
    DateTime? nextClaimTime,
    String? error,
  }) {
    return DailyRewardState(
      isLoading: isLoading ?? this.isLoading,
      claimable: claimable ?? this.claimable,
      lastClaimTime: lastClaimTime ?? this.lastClaimTime,
      nextClaimTime: nextClaimTime ?? this.nextClaimTime,
      error: error,
    );
  }
}

class DailyRewardNotifier extends StateNotifier<DailyRewardState> {
  final Ref _ref;
  DailyRewardNotifier(this._ref) : super(const DailyRewardState());

  Future<void> fetchStatus() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await SecureHttpClient.instance.get('/credits/daily-reward/status');
      if (!resp.success || resp.data == null) {
        state = state.copyWith(isLoading: false, error: resp.errorMessage ?? 'Failed to fetch status');
        return;
      }

      final data = resp.data as Map<String, dynamic>;
      final claimable = data['claimable'] as bool? ?? true;
      final last = data['last_claim_time'] as String?;
      final next = data['next_claim_time'] as String?;

      state = state.copyWith(
        isLoading: false,
        claimable: claimable,
        lastClaimTime: last != null ? DateTime.parse(last).toLocal() : null,
        nextClaimTime: next != null ? DateTime.parse(next).toLocal() : null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Network error');
    }
  }

  Future<bool> claim(BuildContext context) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await SecureHttpClient.instance.post('/credits/daily-reward');
      if (!resp.success || resp.data == null) {
        state = state.copyWith(isLoading: false, error: resp.errorMessage ?? 'Claim failed');
        return false;
      }

      final data = resp.data as Map<String, dynamic>;
      final granted = data['reward_granted'] as bool? ?? false;
      final next = data['next_claim_time'] as String?;

      state = state.copyWith(
        isLoading: false,
        claimable: !granted,
        nextClaimTime: next != null ? DateTime.parse(next).toLocal() : null,
      );

      // Refresh user data (so credits update immediately)
      await _ref.read(authProvider.notifier).refreshUserData();

      // Show success dialog if granted
      if (granted && context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Daily Reward'),
            content: const Text('You received 2 credits!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      return granted;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Network error');
      return false;
    }
  }
}

final dailyRewardProvider = StateNotifierProvider<DailyRewardNotifier, DailyRewardState>((ref) {
  return DailyRewardNotifier(ref);
});
