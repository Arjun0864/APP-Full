import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/secure_http_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Image tool state
// ─────────────────────────────────────────────────────────────────────────────

enum ImageToolStatus { idle, loading, done, error }

class ImageToolState {
  final ImageToolStatus status;
  final String? resultBase64;   // base64 encoded image
  final String? resultUrl;      // URL (fallback)
  final String? error;
  final double progress;
  final int? creditsRemaining;

  const ImageToolState({
    this.status = ImageToolStatus.idle,
    this.resultBase64,
    this.resultUrl,
    this.error,
    this.progress = 0,
    this.creditsRemaining,
  });

  ImageToolState copyWith({
    ImageToolStatus? status,
    String? resultBase64,
    String? resultUrl,
    String? error,
    double? progress,
    int? creditsRemaining,
  }) =>
      ImageToolState(
        status: status ?? this.status,
        resultBase64: resultBase64 ?? this.resultBase64,
        resultUrl: resultUrl ?? this.resultUrl,
        error: error ?? this.error,
        progress: progress ?? this.progress,
        creditsRemaining: creditsRemaining ?? this.creditsRemaining,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ImageToolNotifier extends StateNotifier<ImageToolState> {
  ImageToolNotifier() : super(const ImageToolState());

  Timer? _progressTimer;

  /// Animate progress from current to ~85% over time
  void _animateProgress() {
    _progressTimer?.cancel();
    double current = 0.15;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (state.status != ImageToolStatus.loading) {
        timer.cancel();
        return;
      }
      current += 0.05;
      if (current >= 0.85) {
        timer.cancel();
        return;
      }
      state = state.copyWith(progress: current);
    });
  }

  /// Text-to-image generation
  Future<void> generateImage({
    required String prompt,
    String negativePrompt = '',
    String aspectRatio = '1:1',
    String model = 'core',
    String stylePreset = '',
  }) async {
    state = const ImageToolState(status: ImageToolStatus.loading, progress: 0.1);

    // Start progress animation
    _animateProgress();

    final response = await SecureHttpClient.instance.post(
      AppConfig.endpointImageGenerate,
      body: {
        'prompt': prompt,
        if (negativePrompt.isNotEmpty) 'negative_prompt': negativePrompt,
        'aspect_ratio': aspectRatio,
        'model': model,
        if (stylePreset.isNotEmpty) 'style_preset': stylePreset,
      },
    );

    if (!response.success) {
      state = state.copyWith(
        status: ImageToolStatus.error,
        progress: 0,
        error: response.isNoCredits
            ? 'Not enough credits. Please purchase more.'
            : response.errorMessage ?? 'Image generation failed. Please try again.',
      );
      return;
    }

    // Jump to 95% before showing result
    state = state.copyWith(progress: 0.95);
    await Future.delayed(const Duration(milliseconds: 200));

    final data = response.data;
    
    // Handle different response formats
    if (data is Map<String, dynamic>) {
      state = ImageToolState(
        status: ImageToolStatus.done,
        resultBase64: data['image_base64'] as String?,
        resultUrl: data['image_url'] as String? ?? data['result_url'] as String?,
        progress: 1.0,
        creditsRemaining: data['credits_remaining'] as int?,
      );
    } else if (data is List<int>) {
      // Binary response
      state = ImageToolState(
        status: ImageToolStatus.done,
        resultBase64: base64Encode(data),
        progress: 1.0,
      );
    } else if (data is List) {
      state = ImageToolState(
        status: ImageToolStatus.done,
        resultBase64: base64Encode(List<int>.from(data)),
        progress: 1.0,
      );
    } else {
      state = state.copyWith(
        status: ImageToolStatus.error,
        error: 'Unexpected response from server.',
      );
    }
  }

  /// Remove background — image bytes chahiye
  Future<void> removeBackground({required List<int> imageBytes}) async {
    state = const ImageToolState(status: ImageToolStatus.loading, progress: 0.2);

    final response = await SecureHttpClient.instance.postMultipart(
      AppConfig.endpointImageRemoveBg,
      fields: {},
      files: {'image': imageBytes},
    );

    _handleBinaryResponse(response);
  }

  /// Sketch to image
  Future<void> sketchToImage({
    required List<int> imageBytes,
    required String prompt,
    double controlStrength = 0.7,
  }) async {
    state = const ImageToolState(status: ImageToolStatus.loading, progress: 0.2);

    final response = await SecureHttpClient.instance.postMultipart(
      AppConfig.endpointImageSketch,
      fields: {
        'prompt': prompt,
        'control_strength': controlStrength.toString(),
      },
      files: {'image': imageBytes},
    );

    _handleBinaryResponse(response);
  }

  /// Generic run method — tool name se dispatch karo
  Future<void> run({
    required String tool,
    required String prompt,
    String? imageBase64,
  }) async {
    final imageBytes = imageBase64 != null
        ? base64Decode(imageBase64)
        : <int>[];

    switch (tool) {
      case 'generate':
        await generateImage(prompt: prompt);
        break;
      case 'remove_bg':
        if (imageBytes.isNotEmpty) {
          await removeBackground(imageBytes: imageBytes);
        } else {
          state = state.copyWith(
            status: ImageToolStatus.error,
            error: 'Image upload karo',
          );
        }
        break;
      case 'sketch':
        if (imageBytes.isNotEmpty) {
          await sketchToImage(imageBytes: imageBytes, prompt: prompt);
        } else {
          state = state.copyWith(
            status: ImageToolStatus.error,
            error: 'Sketch image upload karo',
          );
        }
        break;
      default:
        await generateImage(prompt: prompt);
    }
  }

  // ── Binary response handler (image bytes) ─────────────────────────────────
  void _handleBinaryResponse(ApiResponse response) {
    if (!response.success) {
      state = state.copyWith(
        status: ImageToolStatus.error,
        error: response.isNoCredits
            ? 'Not enough credits. Please purchase more.'
            : response.errorMessage ?? 'Operation failed. Please try again.',
      );
      return;
    }

    // Response can be binary bytes or JSON with base64
    final data = response.data;
    String? base64Result;
    int? credits;

    if (data is Map<String, dynamic>) {
      // JSON response with base64 image
      base64Result = data['image_base64'] as String?;
      credits = data['credits_remaining'] as int?;
      final imageUrl = data['image_url'] as String? ?? data['result_url'] as String?;
      
      state = ImageToolState(
        status: ImageToolStatus.done,
        resultBase64: base64Result,
        resultUrl: imageUrl,
        progress: 1.0,
        creditsRemaining: credits,
      );
    } else if (data is List<int>) {
      base64Result = base64Encode(data);
      state = ImageToolState(
        status: ImageToolStatus.done,
        resultBase64: base64Result,
        progress: 1.0,
      );
    } else if (data is List) {
      base64Result = base64Encode(List<int>.from(data));
      state = ImageToolState(
        status: ImageToolStatus.done,
        resultBase64: base64Result,
        progress: 1.0,
      );
    } else {
      state = state.copyWith(
        status: ImageToolStatus.error,
        error: 'Unexpected response format from server.',
      );
    }
  }

  void reset() => state = const ImageToolState();
}

final imageToolProvider =
    StateNotifierProvider.autoDispose<ImageToolNotifier, ImageToolState>((ref) {
  return ImageToolNotifier();
});
