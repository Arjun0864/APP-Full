import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:confetti/confetti.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/app_models.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/gradient_button.dart';
import '../../videos/providers/videos_provider.dart';
import '../../generation/providers/generation_provider.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final VideoModel? video;
  const ResultScreen({super.key, this.video});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _playController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _playController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onResultRevealed();
    });
  }

  void _onResultRevealed() {
    _confettiController.play();
    final video = widget.video ?? ref.read(generationProvider).result;
    if (video != null) {
      ref.read(currentUserVideosProvider.notifier).addVideo(video);
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _playController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video ?? ref.watch(generationProvider).result;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Stack(
          children: [
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildAppBar(context)),
                  SliverToBoxAdapter(child: _buildSuccessBadge()),
                  SliverToBoxAdapter(child: _buildVideoPreview(video)),
                  SliverToBoxAdapter(child: _buildPromptInfo(video)),
                  SliverToBoxAdapter(child: _buildActions(context, video)),
                  SliverToBoxAdapter(child: _buildStats(video)),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
            // Confetti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.accent,
                  Colors.white,
                ],
                numberOfParticles: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              ref.read(generationProvider.notifier).reset();
              context.go('/dashboard');
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Your Video',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/my-videos'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Text(
                'My Videos',
                style: TextStyle(color: AppColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSuccessBadge() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.success.withValues(alpha: 0.2), AppColors.success.withValues(alpha: 0.1)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 16),
                SizedBox(width: 6),
                Text(
                  'Video Generated Successfully!',
                  style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.3);
  }

  Widget _buildVideoPreview(VideoModel? video) {
    // Decode base64 content if available (image or video thumbnail)
    Uint8List? imageBytes;
    if (video?.resultBase64 != null) {
      try {
        imageBytes = base64Decode(video!.resultBase64!);
      } catch (_) {
        imageBytes = null;
      }
    }

    final isImageResult = video == null ||
        video.duration == Duration.zero ||
        video.isImageOnly;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: 24,
        child: Column(
          children: [
            // Image / video preview
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildMediaWidget(video, imageBytes, isImageResult),
                  ),
                  // Play button overlay for videos
                  if (!isImageResult)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => setState(() => _isPlaying = !_isPlaying),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.3),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Type badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isImageResult
                                ? Icons.image_outlined
                                : Icons.video_camera_back_outlined,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isImageResult ? 'IMAGE' : 'VIDEO',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Duration badge for video
                  if (!isImageResult)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${video.duration.inSeconds}s',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isImageResult ? Icons.image : Icons.hd,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isImageResult ? 'AI Image' : '1080p',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.auto_awesome,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 4),
                  Text('AI Generated',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                  const Spacer(),
                  if (imageBytes != null)
                    Text(
                      '${(imageBytes.length / 1024).toStringAsFixed(0)} KB',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2);
  }

  Widget _buildMediaWidget(
      VideoModel? video, Uint8List? imageBytes, bool isImageResult) {
    // Priority: base64 bytes > network URL
    if (imageBytes != null) {
      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _mediaPlaceholder(isImageResult),
      );
    }

    final url = video?.thumbnailUrl ?? video?.videoUrl ?? '';
    if (url.isNotEmpty && !url.startsWith('data:') && url != 'image_result') {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _mediaPlaceholder(isImageResult),
      );
    }

    return _mediaPlaceholder(isImageResult);
  }

  Widget _mediaPlaceholder(bool isImage) {
    return Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: Icon(
          isImage ? Icons.image_outlined : Icons.movie_outlined,
          color: AppColors.textMuted,
          size: 60,
        ),
      ),
    );
  }

  Widget _buildPromptInfo(VideoModel? video) {
    if (video == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prompt Used',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              video.prompt,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildActions(BuildContext context, VideoModel? video) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  text: 'Download',
                  onPressed: () => _downloadFile(context, video),
                  gradientColors: [AppColors.primary, AppColors.secondary],
                  icon: const Icon(Icons.download, color: Colors.white, size: 18),
                  height: 52,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  text: 'Share',
                  onPressed: () => _shareFile(context, video),
                  gradientColors: [AppColors.secondary, AppColors.accent],
                  icon: const Icon(Icons.share, color: Colors.white, size: 18),
                  height: 52,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (video?.hasWatermark == true)
            GestureDetector(
              onTap: () => context.push('/paywall'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.workspace_premium, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Remove Watermark',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Upgrade to Pro for watermark-free videos',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.accent, size: 20),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              ref.read(generationProvider.notifier).reset();
              context.go('/dashboard');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Center(
                child: Text(
                  'Create Another Video',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2);
  }

  Widget _buildStats(VideoModel? video) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          _statCard('Resolution', '1080p HD', Icons.hd_outlined),
          const SizedBox(width: 12),
          _statCard('Duration', '${video?.duration.inSeconds ?? 15}s', Icons.timer_outlined),
          const SizedBox(width: 12),
          _statCard('Format', 'MP4', Icons.video_file_outlined),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(BuildContext context, VideoModel? video) async {
    if (video == null) {
      _showSnackbar(context, 'No content available to download', Icons.error_outline);
      return;
    }

    _showSnackbar(context, 'Downloading...', Icons.download);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final isImage = video.duration == Duration.zero || video.isImageOnly;
      final ext = isImage ? 'png' : 'mp4';
      final fileName = 'visionai_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File('${dir.path}/$fileName');

      if (video.resultBase64 != null) {
        // Use base64 data directly
        final bytes = base64Decode(video.resultBase64!);
        await file.writeAsBytes(bytes);
      } else if (video.videoUrl.isNotEmpty &&
          video.videoUrl != 'image_result' &&
          video.videoUrl != 'video_result') {
        // Download from URL
        final response = await http.get(Uri.parse(video.videoUrl));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Download failed: ${response.statusCode}');
        }
      } else if (mounted) {
        _showSnackbar(this.context, 'No downloadable content available', Icons.error_outline);
        return;
      }

      if (mounted) {
        _showSnackbar(this.context, 'Saved to downloads', Icons.check_circle);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(this.context, 'Download failed. Try again.', Icons.error_outline);
      }
    }
  }

  Future<void> _shareFile(BuildContext context, VideoModel? video) async {
    if (video == null) {
      await Share.share('Check out this AI content I created with VisionAI! 🎬✨');
      return;
    }

    _showSnackbar(context, 'Preparing to share...', Icons.share);

    try {
      final dir = await getTemporaryDirectory();
      final isImage = video.duration == Duration.zero || video.isImageOnly;
      final ext = isImage ? 'png' : 'mp4';
      final fileName = 'visionai_share.$ext';
      final file = File('${dir.path}/$fileName');

      if (video.resultBase64 != null) {
        final bytes = base64Decode(video.resultBase64!);
        await file.writeAsBytes(bytes);
      } else if (video.videoUrl.isNotEmpty &&
          video.videoUrl != 'image_result' &&
          video.videoUrl != 'video_result') {
        final response = await http.get(Uri.parse(video.videoUrl));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Failed to fetch content');
        }
      } else {
        await Share.share('Created with VisionAI ✨');
        return;
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Created with VisionAI ✨',
      );
    } catch (e) {
      await Share.share('Check out this AI content I created with VisionAI! 🎬✨');
    }
  }

  void _showSnackbar(BuildContext context, String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
