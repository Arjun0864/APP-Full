import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/secure_http_client.dart';
import '../../../models/app_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Videos Provider — User-scoped, auto-clears on logout
//
// Data isolation:
//   - Provider is family-keyed by userId so each user gets their own state
//   - On logout, auth provider clears the container → fresh state for next user
//   - Backend also enforces JWT-based scoping (server-side)
// ─────────────────────────────────────────────────────────────────────────────

class VideosNotifier extends StateNotifier<List<VideoModel>> {
  final String userId;

  VideosNotifier(this.userId) : super([]) {
    if (userId.isNotEmpty) loadHistory();
  }

  bool _loading = false;

  /// Backend se video history load karo (only for current user via JWT)
  Future<void> loadHistory() async {
    if (_loading) return;
    _loading = true;

    try {
      final response = await SecureHttpClient.instance.get(
        AppConfig.endpointVideoHistory,
        queryParams: {'limit': '50', 'offset': '0'},
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final videos = (data['videos'] as List<dynamic>? ?? [])
            .map((v) => _videoFromJson(v as Map<String, dynamic>))
            .toList();
        state = videos;
      }
    } catch (_) {
      // Silently fail — empty list
    } finally {
      _loading = false;
    }
  }

  /// Naya generated video add karo (optimistic)
  void addVideo(VideoModel video) {
    // Don't add duplicates
    if (state.any((v) => v.id == video.id)) return;
    state = [video, ...state];
  }

  /// Video delete karo (backend + local state)
  Future<void> removeVideo(String id) async {
    // Optimistic remove from local state first
    state = state.where((v) => v.id != id).toList();
    // Then delete from backend (fire and forget)
    try {
      await SecureHttpClient.instance.delete('/video/history/$id');
    } catch (_) {
      // If backend fails, re-load to sync state
      await loadHistory();
    }
  }

  /// Saari history clear karo (backend + local)
  Future<void> clearAll() async {
    state = [];
    try {
      await SecureHttpClient.instance.delete('/video/history');
    } catch (_) {
      // Ignore — local state is already cleared
    }
  }

  VideoModel _videoFromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'completed';
    VideoStatus status;
    switch (statusStr) {
      case 'processing':
        status = VideoStatus.generating;
        break;
      case 'failed':
        status = VideoStatus.failed;
        break;
      case 'pending':
        status = VideoStatus.pending;
        break;
      default:
        status = VideoStatus.completed;
    }

    DateTime createdAt;
    try {
      createdAt = json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now();
    } catch (_) {
      createdAt = DateTime.now();
    }

    final id = json['id'] as String? ?? '';
    final resultUrl = json['result_url'] as String? ?? '';
    final isImageOnly = resultUrl == 'image_result';
    final resultBase64 = json['result_base64'] as String?;

    // Use thumbnail if available, otherwise a placeholder
    String thumbnailUrl = json['thumbnail_url'] as String? ?? '';
    if (thumbnailUrl.startsWith('data:image')) {
      // Data URI — don't use as Image.network source
      thumbnailUrl = '';
    }

    return VideoModel(
      id: id,
      prompt: json['prompt'] as String? ?? '',
      thumbnailUrl: thumbnailUrl,
      videoUrl: resultUrl,
      resultBase64: resultBase64,
      isImageOnly: isImageOnly,
      status: status,
      createdAt: createdAt,
      duration: isImageOnly ? Duration.zero : const Duration(seconds: 4),
      hasWatermark: false,
    );
  }
}

// Family provider — keyed by userId so each user gets isolated state
final videosProvider =
    StateNotifierProvider.family<VideosNotifier, List<VideoModel>, String>(
        (ref, userId) {
  return VideosNotifier(userId);
});

// Convenience provider — reads current Firebase user's videos
final currentUserVideosProvider =
    StateNotifierProvider<VideosNotifier, List<VideoModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  return VideosNotifier(uid);
});
