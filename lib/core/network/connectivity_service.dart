import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Connectivity Service
//
// Internet check strategy:
//   1. Try to connect to Google DNS (8.8.8.8:53) — fast, reliable
//   2. Fallback: try api.stability.ai
//   3. Cache result for 5 seconds to avoid hammering
//
// Offline rules:
//   ✅ PDF View — works offline (local file)
//   ❌ PDF Edit/Merge/Compress — needs internet (show alert)
//   ❌ AI Video Generation — needs internet
//   ❌ AI Image Tools — needs internet
//   ❌ Login/Auth — needs internet
//   ❌ My Videos (cloud sync) — needs internet
// ─────────────────────────────────────────────────────────────────────────────

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _isOnline = true;
  DateTime? _lastCheck;
  static const _cacheDuration = Duration(seconds: 5);

  /// Check if internet is available (cached for 5s)
  Future<bool> isOnline() async {
    final now = DateTime.now();
    if (_lastCheck != null &&
        now.difference(_lastCheck!) < _cacheDuration) {
      return _isOnline;
    }

    _isOnline = await _checkConnectivity();
    _lastCheck = now;
    return _isOnline;
  }

  /// Force fresh check (ignores cache)
  Future<bool> checkNow() async {
    _isOnline = await _checkConnectivity();
    _lastCheck = DateTime.now();
    return _isOnline;
  }

  Future<bool> _checkConnectivity() async {
    if (kIsWeb) return true;
    try {
      // Try Google DNS — fastest check
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Show no-internet dialog and return false if offline
  /// Returns true if online (proceed), false if offline (blocked)
  Future<bool> requireInternet(
    BuildContext context, {
    String? featureName,
    bool showDialog = true,
  }) async {
    final online = await isOnline();
    if (!online && showDialog && context.mounted) {
      await showNoInternetDialog(context, featureName: featureName);
    }
    return online;
  }

  /// Show the no-internet bottom sheet
  static Future<void> showNoInternetDialog(
    BuildContext context, {
    String? featureName,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _NoInternetSheet(featureName: featureName),
    );
  }

  /// Show PDF edit requires internet dialog
  static Future<bool> showPdfEditInternetRequired(
      BuildContext context) async {
    bool proceed = false;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PdfInternetSheet(
        onProceed: () {
          proceed = true;
          Navigator.pop(ctx);
        },
      ),
    );
    return proceed;
  }
}

// ── No Internet Bottom Sheet ──────────────────────────────────────────────────

class _NoInternetSheet extends StatelessWidget {
  final String? featureName;
  const _NoInternetSheet({this.featureName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2D2D4E)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Icon
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFEF4444),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Internet Connection',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            featureName != null
                ? '$featureName requires an internet connection.\n\nYou can still view local PDF files while offline.'
                : 'This feature requires an internet connection.\n\nYou can still view local PDF files while offline.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // What works offline
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: Color(0xFF10B981), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PDF Viewer works offline — open any local PDF file',
                    style: TextStyle(
                        color: Color(0xFF10B981), fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'OK, Got It',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── PDF Edit Internet Required Sheet ─────────────────────────────────────────

class _PdfInternetSheet extends StatefulWidget {
  final VoidCallback onProceed;
  const _PdfInternetSheet({required this.onProceed});

  @override
  State<_PdfInternetSheet> createState() => _PdfInternetSheetState();
}

class _PdfInternetSheetState extends State<_PdfInternetSheet> {
  bool _checking = false;

  Future<void> _retryAndProceed() async {
    setState(() => _checking = true);
    final online = await ConnectivityService.instance.checkNow();
    setState(() => _checking = false);

    if (online) {
      widget.onProceed();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still no internet. Check your connection.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2D2D4E)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.edit_document,
              color: Color(0xFFF97316),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Internet Required',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'PDF editing, merging, and compression require an internet connection to sync and process your files.\n\nPDF viewing works offline.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _checking ? null : _retryAndProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _checking
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Retry',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<bool> {
  ConnectivityNotifier() : super(true) {
    _startMonitoring();
  }

  Timer? _timer;

  void _startMonitoring() {
    // Check every 30 seconds (less aggressive)
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final online = await ConnectivityService.instance.checkNow();
      // Only update if changed AND confirmed with a second check
      if (online != state) {
        // Double-check to avoid false negatives from background
        await Future.delayed(const Duration(seconds: 2));
        final confirmed = await ConnectivityService.instance.checkNow();
        if (confirmed != state) state = confirmed;
      }
    });
    // Initial check — assume online until proven otherwise
    ConnectivityService.instance.isOnline().then((v) {
      if (!v) {
        // Recheck before showing offline
        Future.delayed(const Duration(seconds: 3), () async {
          final recheck = await ConnectivityService.instance.checkNow();
          state = recheck;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
