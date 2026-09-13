import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';

class ImageSourceSheet {
  ImageSourceSheet._();

  static const List<String> defaultRawAndImageExtensions = [
    'jpg', 'jpeg', 'cr2', 'cr3', 'nef', 'arw', 'dng', 'raf', 'rw2', 'orf', 'png', 'webp', 'tif', 'tiff'
  ];

  static Future<void> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    bool allowMultiple = false,
    int maxImages = 200,
    List<String> allowedExtensions = defaultRawAndImageExtensions,
    required void Function(List<String> paths) onSelected,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title & Subtitle
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle ?? (allowMultiple ? 'Select multiple images from Gallery or Files' : 'Select an image from Gallery or Files'),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Option 1: Gallery / Photos
                  _buildOption(
                    context: ctx,
                    icon: Icons.photo_library_rounded,
                    iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
                    title: 'Photos / Gallery',
                    subtitle: 'Choose JPEGs, PNGs, and camera photos',
                    badgeText: 'Quick Pick',
                    badgeColor: const Color(0xFF10B981),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final picker = ImagePicker();
                      try {
                        if (allowMultiple) {
                          final xFiles = await picker.pickMultiImage();
                          if (xFiles.isNotEmpty) {
                            final paths = xFiles
                                .map((f) => f.path)
                                .where((p) => p.isNotEmpty)
                                .take(maxImages)
                                .toList();
                            if (paths.isNotEmpty) {
                              onSelected(paths);
                            }
                          }
                        } else {
                          final xFile = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 100,
                          );
                          if (xFile != null && xFile.path.isNotEmpty) {
                            onSelected([xFile.path]);
                          }
                        }
                      } catch (e) {
                        debugPrint('[ImageSourceSheet] Gallery pick error: $e');
                      }
                    },
                  ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1, duration: 250.ms, curve: Curves.easeOutCubic),

                  const SizedBox(height: 12),

                  // Option 2: Files / Documents (supports RAW, CR2, NEF, ARW, DNG, TIFF)
                  _buildOption(
                    context: ctx,
                    icon: Icons.folder_open_rounded,
                    iconGradient: const [Color(0xFF3B82F6), Color(0xFF7C3AED)],
                    title: 'Files / Documents',
                    subtitle: 'Supports RAW (CR2, NEF, ARW, DNG) & high-res files',
                    badgeText: 'RAW Supported',
                    badgeColor: const Color(0xFF7C3AED),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: allowedExtensions,
                          allowMultiple: allowMultiple,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          final paths = result.files
                              .where((f) => f.path != null)
                              .map((f) => f.path!)
                              .take(maxImages)
                              .toList();
                          if (paths.isNotEmpty) {
                            onSelected(paths);
                          }
                        }
                      } catch (e) {
                        debugPrint('[ImageSourceSheet] File pick error: $e');
                      }
                    },
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, duration: 250.ms, curve: Curves.easeOutCubic),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: iconGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: iconGradient.first.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
