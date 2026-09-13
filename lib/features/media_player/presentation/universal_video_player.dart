import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../core/theme/app_theme.dart';

/// Universal Video Player
///
/// Supported formats (via ExoPlayer on Android / AVPlayer on iOS):
///   MP4, M4V, MOV, MPEG, MPEG4, MPG, M2TS, MTS
///   MKV (Matroska) — ExoPlayer natively supports on Android
///   AVI — ExoPlayer supports on Android 5+
///   WebM, 3GP, 3G2, FLV, TS, OGV
///   WMV, ASF — Android only (ExoPlayer)
///   RMVB, RM — limited support
///
/// Note: iOS AVPlayer has more limited format support than Android ExoPlayer.
/// MKV and some AVI files may not play on iOS — a format-not-supported
/// message is shown in that case.
class UniversalVideoPlayer extends StatefulWidget {
  final String? filePath;   // Local file path
  final String? networkUrl; // Network URL
  final String? title;
  final bool autoPlay;
  final bool looping;

  const UniversalVideoPlayer({
    super.key,
    this.filePath,
    this.networkUrl,
    this.title,
    this.autoPlay = false,
    this.looping = false,
  }) : assert(filePath != null || networkUrl != null,
            'Either filePath or networkUrl must be provided');

  @override
  State<UniversalVideoPlayer> createState() => _UniversalVideoPlayerState();
}

class _UniversalVideoPlayerState extends State<UniversalVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  String? _error;
  bool _isLimitedSupport = false; // Format plays but may have issues

  // ── Format support tables ─────────────────────────────────────────────────

  /// Fully supported on both Android (ExoPlayer) and iOS (AVPlayer)
  static const _fullySupported = {
    'mp4', 'm4v', 'mov', 'mpeg', 'mpg', 'mpeg4', 'm2ts', 'mts',
    'webm', '3gp', '3g2', 'ts',
  };

  /// Supported on Android (ExoPlayer) — may not work on iOS
  static const _androidOnly = {
    'mkv', 'avi', 'flv', 'wmv', 'asf', 'ogv', 'rm', 'rmvb', 'vob',
  };

  /// All supported formats combined
  static Set<String> get _allSupported => {..._fullySupported, ..._androidOnly};

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.filePath != null) {
        final ext = widget.filePath!.split('.').last.toLowerCase();

        if (!_allSupported.contains(ext)) {
          setState(() => _error =
              'Format .$ext is not supported.\n\nSupported: MP4, MKV, AVI, MOV, MPEG4, WebM, 3GP, FLV, M4V, WMV');
          return;
        }

        // Warn about iOS-limited formats
        if (Platform.isIOS && _androidOnly.contains(ext)) {
          setState(() => _isLimitedSupport = true);
        }

        _videoController = VideoPlayerController.file(File(widget.filePath!));
      } else if (widget.networkUrl != null) {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.networkUrl!),
          httpHeaders: const {
            'User-Agent': 'VisionAI/1.0',
          },
        );
      }

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: widget.autoPlay,
        looping: widget.looping,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        showOptions: true,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF7C3AED)),
            ),
          ),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primaryLight,
          backgroundColor: AppColors.surfaceLight,
          bufferedColor: AppColors.primary.withValues(alpha: 0.3),
        ),
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primaryLight,
        ),
        errorBuilder: (context, errorMessage) => _buildInlineError(errorMessage),
      );

      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) {
        final ext = widget.filePath?.split('.').last.toLowerCase() ?? '';
        String errorMsg;

        if (Platform.isIOS && _androidOnly.contains(ext)) {
          errorMsg =
              '.$ext format is not supported on iOS.\n\n'
              'This format plays on Android. On iOS, use MP4, MOV, or M4V.';
        } else {
          errorMsg = 'Could not load video.\n\nError: $e';
        }
        setState(() => _error = errorMsg);
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    // Restore system UI when leaving fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorScreen(_error!);
    }

    if (!_isInitialized) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ?? _getFileName(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            if (_isLimitedSupport)
              const Text(
                'Limited iOS support — may not play correctly',
                style: TextStyle(fontSize: 10, color: Colors.orange),
              ),
          ],
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          // Format info
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getFileExtension().toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Chewie(controller: _chewieController!)),
            // Video info bar
            _buildInfoBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBar() {
    final duration = _videoController?.value.duration;
    final size = _videoController?.value.size;
    final ext = _getFileExtension().toUpperCase();

    return Container(
      color: const Color(0xFF0A0A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _infoChip(Icons.video_file_outlined, ext),
          const SizedBox(width: 10),
          if (duration != null)
            _infoChip(Icons.timer_outlined, _formatDuration(duration)),
          if (size != null) ...[
            const SizedBox(width: 10),
            _infoChip(Icons.aspect_ratio, '${size.width.toInt()}×${size.height.toInt()}'),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 13),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? _getFileName()),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading ${_getFileName()}...',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              _getFileExtension().toUpperCase(),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.white,
        title: const Text('Video Player'),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_off,
                    color: AppColors.error, size: 40),
              ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 20),
              Text(
                'Video Could Not Play',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supported Video Formats:',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Android: MP4, MKV, AVI, MOV, MPEG4, WebM, 3GP, FLV, WMV, M4V, TS\n'
                      'iOS: MP4, MOV, M4V, MPEG4, 3GP, WebM',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineError(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getFileName() {
    if (widget.filePath != null) {
      return widget.filePath!.split('/').last;
    }
    if (widget.networkUrl != null) {
      return widget.networkUrl!.split('/').last.split('?').first;
    }
    return 'Video';
  }

  String _getFileExtension() {
    if (widget.filePath != null) {
      final parts = widget.filePath!.split('.');
      return parts.length > 1 ? parts.last.toLowerCase() : 'video';
    }
    if (widget.networkUrl != null) {
      final path = widget.networkUrl!.split('?').first;
      final parts = path.split('.');
      return parts.length > 1 ? parts.last.toLowerCase() : 'video';
    }
    return 'video';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m}m ${s}s';
    }
    return '${m}m ${s}s';
  }
}
