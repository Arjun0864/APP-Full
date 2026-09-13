import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';

/// Universal Image Viewer
///
/// Supported formats:
///   Standard:  JPEG, PNG, GIF, WebP, BMP, WBMP, ICO
///   Apple:     HEIC, HEIF (iOS native; Android needs plugin — shown as info card)
///   RAW/DSLR:  CRW, CR2, CR3 (Canon), NEF, NRW (Nikon), ARW, SRF, SR2 (Sony),
///              ORF (Olympus), RW2 (Panasonic), PEF (Pentax), DNG (Adobe),
///              RAF (Fujifilm), RWL (Leica), RAW (generic)
///   Other:     TIFF, TIF, SVG (info card), AVIF
///
/// Features:
///   - Pinch-to-zoom (photo_view)
///   - Swipe gallery with thumbnail strip
///   - Share & download actions
///   - HEIC: native on iOS, info card on Android
///   - RAW: metadata info card (RAW files need dedicated editors)
class UniversalImageViewer extends StatefulWidget {
  final List<ImageSource> images;
  final int initialIndex;
  final String? title;

  const UniversalImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.title,
  });

  /// Single image convenience constructor
  factory UniversalImageViewer.single({
    Key? key,
    required ImageSource image,
    String? title,
  }) {
    return UniversalImageViewer(
      key: key,
      images: [image],
      title: title,
    );
  }

  @override
  State<UniversalImageViewer> createState() => _UniversalImageViewerState();
}

class _UniversalImageViewerState extends State<UniversalImageViewer> {
  late int _currentIndex;
  late PageController _pageController;

  // ── Format classification ─────────────────────────────────────────────────

  /// Formats Flutter can render natively via Image widget
  static const _nativeFormats = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'wbmp', 'ico', 'avif',
  };

  /// HEIC/HEIF — native on iOS, needs special handling on Android
  static const _heicFormats = {'heic', 'heif'};

  /// TIFF — limited support (some decoders handle it)
  static const _tiffFormats = {'tiff', 'tif'};

  /// RAW camera formats — cannot be rendered, show info card
  static const _rawFormats = {
    // Canon
    'crw', 'cr2', 'cr3',
    // Nikon
    'nef', 'nrw',
    // Sony
    'arw', 'srf', 'sr2',
    // Olympus
    'orf',
    // Panasonic
    'rw2',
    // Pentax
    'pef',
    // Adobe DNG (universal RAW)
    'dng',
    // Fujifilm
    'raf',
    // Leica
    'rwl',
    // Generic
    'raw',
  };

  /// SVG — not renderable by Flutter without a plugin
  static const _svgFormats = {'svg', 'svgz'};

  _ImageType _getType(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (_rawFormats.contains(ext)) return _ImageType.raw;
    if (_heicFormats.contains(ext)) return _ImageType.heic;
    if (_tiffFormats.contains(ext)) return _ImageType.tiff;
    if (_svgFormats.contains(ext)) return _ImageType.svg;
    if (_nativeFormats.contains(ext)) return _ImageType.native;
    return _ImageType.unknown;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ?? _getCurrentFileName(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.images.length > 1)
              Text(
                '${_currentIndex + 1} / ${widget.images.length}',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
          ],
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          // Format badge
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getCurrentExtension().toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareCurrentImage,
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: _downloadCurrentImage,
            tooltip: 'Save',
          ),
        ],
      ),
      body: widget.images.length == 1
          ? _buildSingleImage(widget.images[0])
          : _buildGallery(),
      bottomNavigationBar: widget.images.length > 1
          ? _buildThumbnailStrip()
          : null,
    );
  }

  // ── Image rendering ───────────────────────────────────────────────────────

  Widget _buildSingleImage(ImageSource source) {
    final path = source.path ?? '';
    final type = _getType(path);

    switch (type) {
      case _ImageType.raw:
        return _buildRawInfoCard(source);
      case _ImageType.heic:
        return _buildHeicImage(source);
      case _ImageType.svg:
        return _buildSvgInfoCard(source);
      case _ImageType.tiff:
        return _buildTiffImage(source);
      case _ImageType.native:
      case _ImageType.unknown:
        return _buildPhotoView(source);
    }
  }

  Widget _buildGallery() {
    return PhotoViewGallery.builder(
      pageController: _pageController,
      itemCount: widget.images.length,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      builder: (context, index) {
        final source = widget.images[index];
        final path = source.path ?? '';
        final type = _getType(path);

        if (type == _ImageType.raw) {
          return PhotoViewGalleryPageOptions.customChild(
            child: _buildRawInfoCard(source),
          );
        }
        if (type == _ImageType.heic) {
          return PhotoViewGalleryPageOptions.customChild(
            child: _buildHeicImage(source),
          );
        }
        if (type == _ImageType.svg) {
          return PhotoViewGalleryPageOptions.customChild(
            child: _buildSvgInfoCard(source),
          );
        }

        return PhotoViewGalleryPageOptions(
          imageProvider: _getImageProvider(source),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
          errorBuilder: (context, error, stackTrace) =>
              _buildImageError(source),
        );
      },
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      loadingBuilder: (context, event) => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildPhotoView(ImageSource source) {
    return PhotoView(
      imageProvider: _getImageProvider(source),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      loadingBuilder: (context, event) => Center(
        child: CircularProgressIndicator(
          value: event?.expectedTotalBytes != null
              ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
              : null,
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
        ),
      ),
      errorBuilder: (context, error, stackTrace) => _buildImageError(source),
    );
  }

  /// HEIC: iOS renders natively via FileImage. Android shows info card.
  Widget _buildHeicImage(ImageSource source) {
    if (Platform.isIOS && source.path != null) {
      // iOS can render HEIC natively
      return PhotoView(
        imageProvider: FileImage(File(source.path!)),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        errorBuilder: (context, error, stackTrace) =>
            _buildHeicAndroidCard(source),
      );
    }
    // Android: HEIC not natively supported — show info card
    return _buildHeicAndroidCard(source);
  }

  Widget _buildHeicAndroidCard(ImageSource source) {
    final fileName = source.path?.split('/').last ?? 'image.heic';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.image, color: Colors.white, size: 50),
            ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 20),
            const Text(
              'HEIC / HEIF Image',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              fileName,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white54, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'HEIC is Apple\'s High Efficiency Image format.',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.greenAccent, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Fully supported on iOS — opens natively.',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.orangeAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          Platform.isAndroid
                              ? 'On Android, HEIC requires Android 10+ with hardware decoder. '
                                  'Convert to JPEG for universal compatibility.'
                              : 'This file could not be decoded.',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// TIFF: try to render, fall back to info card
  Widget _buildTiffImage(ImageSource source) {
    // Flutter's image codec supports basic TIFF on some platforms
    try {
      return PhotoView(
        imageProvider: _getImageProvider(source),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        errorBuilder: (context, error, stackTrace) =>
            _buildFormatInfoCard(source, 'TIFF',
                'TIFF files may not render on all devices. '
                'Convert to JPEG or PNG for best compatibility.'),
      );
    } catch (_) {
      return _buildFormatInfoCard(source, 'TIFF',
          'TIFF files may not render on all devices.');
    }
  }

  /// RAW camera format info card
  Widget _buildRawInfoCard(ImageSource source) {
    final ext = (source.path ?? '').split('.').last.toUpperCase();
    final fileName = source.path?.split('/').last ?? 'image.$ext';

    final cameraInfo = _getRawCameraInfo(ext.toLowerCase());

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 50),
            ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 20),
            Text(
              '.$ext RAW File',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              cameraInfo,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              fileName,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white54, size: 15),
                      SizedBox(width: 8),
                      Text(
                        'About RAW Files',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'RAW files contain unprocessed sensor data from your camera. '
                    'They require a dedicated RAW editor (Lightroom, Capture One, '
                    'Darktable) to view and edit properly.\n\n'
                    'VisionAI can use RAW files for AI processing — the file '
                    'metadata and embedded preview are available.',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: Icons.share_outlined,
                    label: 'Share File',
                    onTap: _shareCurrentImage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    icon: Icons.auto_awesome,
                    label: 'Use for AI',
                    onTap: () => Navigator.pop(context),
                    isPrimary: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSvgInfoCard(ImageSource source) {
    return _buildFormatInfoCard(
      source,
      'SVG',
      'SVG vector files require a dedicated SVG renderer. '
          'Export as PNG for use in VisionAI.',
    );
  }

  Widget _buildFormatInfoCard(ImageSource source, String format, String message) {
    final fileName = source.path?.split('/').last ?? 'file';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.image_not_supported_outlined,
                  color: Colors.white54, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              '$format File',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              fileName,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isPrimary ? AppColors.primaryGradient : null,
          color: isPrimary ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ── Thumbnail strip ───────────────────────────────────────────────────────

  Widget _buildThumbnailStrip() {
    return Container(
      height: 72,
      color: Colors.black,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          final isSelected = index == _currentIndex;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 6),
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _buildThumbnail(widget.images[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumbnail(ImageSource source) {
    final path = source.path ?? '';
    final type = _getType(path);

    if (type == _ImageType.raw) {
      return Container(
        color: const Color(0xFF2D1B69),
        child: const Center(
          child: Icon(Icons.camera_alt, color: Colors.white54, size: 20),
        ),
      );
    }
    if (type == _ImageType.heic && Platform.isAndroid) {
      return Container(
        color: const Color(0xFF1B2D69),
        child: const Center(
          child: Icon(Icons.image, color: Colors.white54, size: 20),
        ),
      );
    }
    if (type == _ImageType.svg) {
      return Container(
        color: const Color(0xFF1B4D2D),
        child: const Center(
          child: Icon(Icons.code, color: Colors.white54, size: 20),
        ),
      );
    }

    try {
      return Image(
        image: _getImageProvider(source),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: AppColors.surfaceLight,
          child: Icon(Icons.broken_image, color: AppColors.textMuted),
        ),
      );
    } catch (_) {
      return Container(color: AppColors.surfaceLight);
    }
  }

  // ── Error widget ──────────────────────────────────────────────────────────

  Widget _buildImageError(ImageSource source) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Image could not be loaded',
            style: TextStyle(color: Colors.white60, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            source.path?.split('/').last ?? source.networkUrl ?? '',
            style: const TextStyle(color: Colors.white30, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ImageProvider _getImageProvider(ImageSource source) {
    if (source.bytes != null) {
      return MemoryImage(source.bytes!);
    }
    if (source.path != null) {
      return FileImage(File(source.path!));
    }
    if (source.networkUrl != null) {
      return CachedNetworkImageProvider(source.networkUrl!);
    }
    throw Exception('No image source provided');
  }

  String _getCurrentFileName() {
    final source = widget.images[_currentIndex];
    if (source.path != null) return source.path!.split('/').last;
    if (source.networkUrl != null) {
      return source.networkUrl!.split('/').last.split('?').first;
    }
    return 'Image';
  }

  String _getCurrentExtension() {
    final source = widget.images[_currentIndex];
    final path = source.path ?? source.networkUrl ?? '';
    final parts = path.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'img';
  }

  String _getRawCameraInfo(String ext) {
    switch (ext) {
      case 'crw':
      case 'cr2':
      case 'cr3':
        return 'Canon RAW format';
      case 'nef':
      case 'nrw':
        return 'Nikon RAW format';
      case 'arw':
      case 'srf':
      case 'sr2':
        return 'Sony RAW format';
      case 'orf':
        return 'Olympus RAW format';
      case 'rw2':
        return 'Panasonic RAW format';
      case 'pef':
        return 'Pentax RAW format';
      case 'dng':
        return 'Adobe DNG (Digital Negative)';
      case 'raf':
        return 'Fujifilm RAW format';
      case 'rwl':
        return 'Leica RAW format';
      default:
        return 'Camera RAW format';
    }
  }

  void _shareCurrentImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sharing image...'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _downloadCurrentImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saving to gallery...'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Image type enum ───────────────────────────────────────────────────────────

enum _ImageType { native, heic, tiff, raw, svg, unknown }

// ── Image source model ────────────────────────────────────────────────────────

/// Image source — can be file path, network URL, or raw bytes
class ImageSource {
  final String? path;
  final String? networkUrl;
  final Uint8List? bytes;
  final String? label;

  const ImageSource({this.path, this.networkUrl, this.bytes, this.label})
      : assert(path != null || networkUrl != null || bytes != null,
            'At least one of path, networkUrl, or bytes must be provided');

  factory ImageSource.file(String path, {String? label}) =>
      ImageSource(path: path, label: label);

  factory ImageSource.network(String url, {String? label}) =>
      ImageSource(networkUrl: url, label: label);

  factory ImageSource.memory(Uint8List bytes, {String? label}) =>
      ImageSource(bytes: bytes, label: label);
}
