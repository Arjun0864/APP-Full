import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/ads/admob_manager.dart';
import '../../../core/network/secure_http_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/app_models.dart';
import '../../auth/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Credits Provider
//
// Manages:
//   - Transaction history
//   - Rewarded ad credits
//   - Razorpay payment flow
//   - Credit balance sync with backend
// ─────────────────────────────────────────────────────────────────────────────

class CreditsState {
  final bool isLoading;
  final List<Transaction> transactions;
  final String? error;
  final RazorpayOrderInfo? pendingOrder;

  const CreditsState({
    this.isLoading = false,
    this.transactions = const [],
    this.error,
    this.pendingOrder,
  });

  CreditsState copyWith({
    bool? isLoading,
    List<Transaction>? transactions,
    String? error,
    RazorpayOrderInfo? pendingOrder,
  }) {
    return CreditsState(
      isLoading: isLoading ?? this.isLoading,
      transactions: transactions ?? this.transactions,
      error: error,
      pendingOrder: pendingOrder ?? this.pendingOrder,
    );
  }
}

class RazorpayOrderInfo {
  final String orderId;
  final int amount;
  final String currency;
  final String key;
  final CreditPackage package;

  const RazorpayOrderInfo({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.key,
    required this.package,
  });
}

class CreditsNotifier extends StateNotifier<CreditsState> {
  final Ref _ref;

  CreditsNotifier(this._ref) : super(const CreditsState()) {
    loadTransactions();
  }

  // ── Load transaction history ──────────────────────────────────────────────

  Future<void> loadTransactions() async {
    try {
      final response = await SecureHttpClient.instance.get(
        '/credits/transactions',
        queryParams: {'limit': '20'},
      );
      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final txList = (data['transactions'] as List<dynamic>? ?? [])
            .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
            .toList();
        state = state.copyWith(transactions: txList);
      }
    } catch (_) {
      // Non-critical — silently fail
    }
  }

  // ── Razorpay payment flow ─────────────────────────────────────────────────
  //
  // Step 1: createRazorpayOrder() — backend creates Razorpay order, returns order_id
  // Step 2: Flutter opens Razorpay checkout (handled in the screen)
  // Step 3: verifyRazorpayPayment() — backend verifies signature, adds credits
  //
  // The backend verifies the HMAC-SHA256 signature before adding credits,
  // so even if someone bypasses the UI, they can't get free credits.

  Future<RazorpayOrderInfo?> createRazorpayOrder(CreditPackage pkg) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SecureHttpClient.instance.post(
        '/credits/razorpay/create-order',
        body: {
          'package_id': pkg.id,
          'credits': pkg.credits,
          'amount_paise': pkg.amountPaise,
        },
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final order = RazorpayOrderInfo(
          orderId: data['order_id'] as String,
          amount: data['amount'] as int,
          currency: data['currency'] as String,
          key: data['key'] as String,
          package: pkg,
        );
        state = state.copyWith(isLoading: false, pendingOrder: order);
        return order;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.errorMessage ?? 'Failed to create payment order.',
        );
        return null;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Payment initiation failed. Check your connection.',
      );
      return null;
    }
  }

  Future<bool> verifyRazorpayPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required CreditPackage pkg,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SecureHttpClient.instance.post(
        '/credits/razorpay/verify',
        body: {
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
          'package_id': pkg.id,
          'credits': pkg.credits,
        },
      );

      if (response.success) {
        await _ref.read(authProvider.notifier).refreshUserData();
        await loadTransactions();
        state = state.copyWith(isLoading: false, pendingOrder: null);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.errorMessage ?? 'Payment verification failed.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Verification failed. Contact support if credits were deducted.',
      );
      return false;
    }
  }

  void clearPendingOrder() {
    state = state.copyWith(pendingOrder: null);
  }

  Future<void> _sendRewardEvent(
    String requestId,
    String eventType, {
    String? errorCode,
    String? message,
  }) async {
    try {
      final response = await SecureHttpClient.instance.post(
        '/credits/reward-event',
        body: {
          'request_id': requestId,
          'event_type': eventType,
          'source': 'rewarded_ad',
          if (errorCode != null) 'error_code': errorCode,
          if (message != null) 'message': message,
        },
      );
      if (kDebugMode && !response.success) {
        debugPrint('[RewardEvent] failed to log $eventType: ${response.errorMessage}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RewardEvent] error logging $eventType: $e');
      }
    }
  }

  Future<void> _showRewardedAdFailure(
    BuildContext context,
    String message,
  ) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ad unavailable'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ── Watch rewarded ad for free credits ────────────────────────────────────

  Future<void> watchRewardedAd(BuildContext context) async {
    final adManager = AdMobManager.instance;
    final requestId = const Uuid().v4();

    await _sendRewardEvent(requestId, 'attempt');

    final creditsEarned = await adManager.showRewardedAd(
      creditsReward: 2,
      onEvent: (eventType, {errorCode, message}) async {
        await _sendRewardEvent(requestId, eventType,
            errorCode: errorCode, message: message);

        if (context.mounted && eventType == 'load_failure') {
          await _showRewardedAdFailure(
            context,
            message ??
                'Rewarded ads are currently unavailable. Please try again later.',
          );
        }
      },
    );

    if (creditsEarned <= 0) {
      return;
    }

    final rewardResponse = await SecureHttpClient.instance.post(
      '/credits/reward',
      body: {
        'credits': creditsEarned,
        'source': 'rewarded_ad',
        'request_id': requestId,
      },
    );

    if (rewardResponse.success) {
      await _ref.read(authProvider.notifier).refreshUserData();
      await loadTransactions();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('You earned $creditsEarned free credits!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rewardResponse.errorMessage ??
                  'Unable to claim your reward right now. Please try again.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}

final creditsProvider =
    StateNotifierProvider<CreditsNotifier, CreditsState>((ref) {
  return CreditsNotifier(ref);
});
