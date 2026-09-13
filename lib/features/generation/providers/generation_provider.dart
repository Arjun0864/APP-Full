import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/secure_http_client.dart';
import '../../../core/ads/ad_manager.dart';
import '../../../models/app_models.dart';
import '../../auth/providers/auth_provider.dart';

enum GenerationStep {
  idle,
  understanding,
  preparing,
  generating,
  finalizing,
  completed,
  failed,
}

class GenerationState {
  final GenerationStep step;
  final String prompt;
  final double progress;
  final VideoModel? result;
  final String? error;
  final String statusMessage;
  final String? generationId;
  final GenerationType generationType;

  const GenerationState({
    this.step = GenerationStep.idle,
    this.prompt = '',
    this.progress = 0,
    this.result,
    this.error,
    this.statusMessage = '',
    this.generationId,
    this.generationType = GenerationType.video,
  });

  bool get isImageGeneration =>
      generationType == GenerationType.imageGenerate ||
      generationType == GenerationType.imageUltra;

  GenerationState copyWith({
    GenerationStep? step,
    String? prompt,
    double? progress,
    VideoModel? result,
    String? error,
    String? statusMessage,
    String? generationId,
    GenerationType? generationType,
  }) {
    return GenerationState(
      step: step ?? this.step,
      prompt: prompt ?? this.prompt,
      progress: progress ?? this.progress,
      result: result ?? this.result,
      error: error ?? this.error,
      statusMessage: statusMessage ?? this.statusMessage,
      generationId: generationId ?? this.generationId,
      generationType: generationType ?? this.generationType,
    );
  }
}

class GenerationNotifier extends StateNotifier<GenerationState> {
  final Ref _ref;

  GenerationNotifier(this._ref) : super(const GenerationState());

  Future<void> generate(String prompt, {GenerationType type = GenerationType.video}) async {
    state = GenerationState(
      step: GenerationStep.understanding,
      prompt: prompt,
      progress: 0.1,
      statusMessage: 'Analyzing your prompt...',
      generationType: type,
    );

    // Determine which endpoint to call based on generation type
    String endpoint;
    Map<String, dynamic> body = {'prompt': prompt};

    switch (type) {
      case GenerationType.video:
        endpoint = AppConfig.endpointVideoGenerate;
        break;
      case GenerationType.imageFree:
      case GenerationType.imageGenerate:
      case GenerationType.imageUltra:
        endpoint = AppConfig.endpointImageGenerate;
        if (type == GenerationType.imageFree) {
          body['model'] = 'free';
        } else {
          body['model'] = type == GenerationType.imageUltra ? 'ultra' : 'core';
        }
        break;
      default:
        endpoint = AppConfig.endpointVideoGenerate;
    }

    // Smooth progress: move to 20% after understanding
    await Future.delayed(const Duration(milliseconds: 600));
    if (state.step == GenerationStep.understanding) {
      state = state.copyWith(
        progress: 0.2,
        statusMessage: type == GenerationType.video
            ? 'Sending to AI engine...'
            : 'Sending to AI engine...',
      );
    }

    // Step 1: Backend ko generate request bhejo
    final response = await SecureHttpClient.instance.post(
      endpoint,
      body: body,
    );

    if (!response.success) {
      if (response.isNoCredits) {
        state = state.copyWith(
          step: GenerationStep.failed,
          error: 'Not enough credits. Please purchase more.',
        );
        return;
      }
      state = state.copyWith(
        step: GenerationStep.failed,
        error: response.errorMessage ?? 'Generation failed. Please try again.',
      );
      return;
    }

    final data = response.data;

    // Handle image generation that returns result directly (no polling needed)
    if (type == GenerationType.imageGenerate || type == GenerationType.imageUltra) {
      if (data is Map<String, dynamic>) {
        // Check for direct base64 response (image returned immediately)
        final imageBase64 = data['image_base64'] as String?;
        final imageUrl = data['image_url'] as String? ?? data['result_url'] as String?;
        final generationId = data['generation_id'] as String?;

        if (imageBase64 != null) {
          // Image returned directly as base64 — no polling needed
          state = state.copyWith(
            step: GenerationStep.finalizing,
            progress: 0.95,
            statusMessage: 'Finalizing image...',
          );
          await Future.delayed(const Duration(milliseconds: 400));

          _ref.read(authProvider.notifier).deductCredit(amount: creditCostFor(type));

          final result = VideoModel(
            id: generationId ?? DateTime.now().millisecondsSinceEpoch.toString(),
            prompt: prompt,
            thumbnailUrl: '',
            videoUrl: '',
            resultBase64: imageBase64,
            status: VideoStatus.completed,
            createdAt: DateTime.now(),
            duration: Duration.zero,
            hasWatermark: true,
          );

          state = state.copyWith(
            step: GenerationStep.completed,
            progress: 1.0,
            result: result,
            statusMessage: 'Image ready!',
          );
          return;
        }

        if (imageUrl != null && imageUrl.isNotEmpty) {
          // Image returned as URL
          state = state.copyWith(
            step: GenerationStep.finalizing,
            progress: 0.95,
            statusMessage: 'Finalizing image...',
          );
          await Future.delayed(const Duration(milliseconds: 400));

          _ref.read(authProvider.notifier).deductCredit(amount: creditCostFor(type));

          final result = VideoModel(
            id: generationId ?? DateTime.now().millisecondsSinceEpoch.toString(),
            prompt: prompt,
            thumbnailUrl: imageUrl,
            videoUrl: imageUrl,
            status: VideoStatus.completed,
            createdAt: DateTime.now(),
            duration: Duration.zero,
            hasWatermark: true,
          );

          state = state.copyWith(
            step: GenerationStep.completed,
            progress: 1.0,
            result: result,
            statusMessage: 'Image ready!',
          );
          return;
        }
      }

      state = state.copyWith(
        step: GenerationStep.failed,
        error: 'Unexpected response from server. Please try again.',
      );
      return;
    }

    // Video generation - requires polling
    if (data is! Map<String, dynamic>) {
      state = state.copyWith(
        step: GenerationStep.failed,
        error: 'Unexpected response from server. Please try again.',
      );
      return;
    }
    
    final generationId = data['generation_id'] as String?;
    if (generationId == null) {
      state = state.copyWith(
        step: GenerationStep.failed,
        error: 'No generation ID received. Please try again.',
      );
      return;
    }

    state = state.copyWith(
      step: GenerationStep.preparing,
      progress: 0.25,
      statusMessage: 'Preparing video generation...',
      generationId: generationId,
    );

    // Step 2: Status poll karo jab tak completed/failed
    await _pollStatus(generationId, prompt, type);
  }

  Future<void> _pollStatus(String generationId, String prompt, GenerationType type) async {
    const maxAttempts = 36; // 36 * 5s = 3 minutes
    const pollInterval = Duration(seconds: 5);

    final isImage = type == GenerationType.imageGenerate ||
        type == GenerationType.imageUltra;

    final progressSteps = [0.35, 0.45, 0.55, 0.65, 0.72, 0.80, 0.87, 0.93];

    final videoMessages = [
      'Analyzing scene composition...',
      'Preparing visual elements...',
      'Generating frames...',
      'Applying motion effects...',
      'Rendering video...',
      'Running quality check...',
      'Final touches...',
      'Almost done...',
    ];

    final imageMessages = [
      'Processing your prompt...',
      'Generating visual elements...',
      'Rendering pixels...',
      'Applying style...',
      'Enhancing details...',
      'Running quality check...',
      'Final touches...',
      'Almost done...',
    ];

    final messages = isImage ? imageMessages : videoMessages;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(pollInterval);

      // Progress update
      if (attempt < progressSteps.length) {
        state = state.copyWith(
          step: GenerationStep.generating,
          progress: progressSteps[attempt],
          statusMessage: messages[attempt],
        );
      }

      final statusResponse = await SecureHttpClient.instance.get(
        '/video/status/$generationId',
      );

      if (!statusResponse.success) continue;

      final statusData = statusResponse.data as Map<String, dynamic>;
      final status = statusData['status'] as String;

      if (status == 'completed') {
        state = state.copyWith(
          step: GenerationStep.finalizing,
          progress: 0.97,
          statusMessage: 'Finalizing...',
        );

        // Deduct credits on successful generation
        _ref.read(authProvider.notifier).deductCredit(amount: creditCostFor(type));

        await Future.delayed(const Duration(milliseconds: 500));

        // result_base64 contains actual video/image bytes from backend
        final resultBase64 = statusData['result_base64'] as String?;
        final resultUrl = statusData['result_url'] as String? ?? '';
        final thumbnailUrl = statusData['thumbnail_url'] as String? ?? '';

        if (isImage) {
          final imageUrl = statusData['image_url'] as String? ?? resultUrl;
          final result = VideoModel(
            id: generationId,
            prompt: prompt,
            thumbnailUrl: imageUrl.isNotEmpty ? imageUrl : thumbnailUrl,
            videoUrl: imageUrl,
            resultBase64: resultBase64,
            status: VideoStatus.completed,
            createdAt: DateTime.now(),
            duration: Duration.zero,
            hasWatermark: true,
          );

          state = state.copyWith(
            step: GenerationStep.completed,
            progress: 1.0,
            result: result,
            statusMessage: 'Image ready!',
          );
        } else {
          // Video result — may be base64 (direct) or URL
          final isImageOnly = resultUrl == 'image_result';
          final video = VideoModel(
            id: generationId,
            prompt: prompt,
            thumbnailUrl: thumbnailUrl.startsWith('data:') ? '' : thumbnailUrl,
            videoUrl: resultUrl,
            resultBase64: resultBase64,
            isImageOnly: isImageOnly,
            status: VideoStatus.completed,
            createdAt: DateTime.now(),
            duration: isImageOnly ? Duration.zero : const Duration(seconds: 4),
            hasWatermark: true,
          );

          state = state.copyWith(
            step: GenerationStep.completed,
            progress: 1.0,
            result: video,
            statusMessage: isImageOnly ? 'Content ready!' : 'Video ready!',
          );
        }
        return;
      }

      if (status == 'failed') {
        state = state.copyWith(
          step: GenerationStep.failed,
          error: statusData['error'] as String? ?? 'Generation failed. Please try again.',
        );
        return;
      }
      // status == 'processing' — continue polling
    }

    // Timeout
    state = state.copyWith(
      step: GenerationStep.failed,
      error: 'Generation is taking too long. Please try again later.',
    );
  }

  void reset() {
    state = const GenerationState();
  }
}

final generationProvider =
    StateNotifierProvider<GenerationNotifier, GenerationState>((ref) {
  return GenerationNotifier(ref);
});
