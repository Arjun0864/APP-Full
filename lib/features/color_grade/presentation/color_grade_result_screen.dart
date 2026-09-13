import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/gradient_button.dart';
import '../models/color_grade_models.dart';
import '../providers/color_grade_provider.dart';
import '../services/permission_service.dart';

class ColorGradeResultScreen extends ConsumerWidget {
  const ColorGradeResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(colorGradeProvider);
    final outputs = state.outputs;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration:
            BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, ref, outputs.length),
              Expanded(
                child: outputs.isEmpty
                    ? _buildEmpty()
                    : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  _buildStepIndicator(activeStep: 2),
                                  const SizedBox(height: 20),
                                  _buildSummaryCard(outputs),
                                  const SizedBox(height: 20),
                                  _buildShareAllButton(context, outputs),
                                  const SizedBox(height: 20),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Exported Graded Images',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.82,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) =>
                                    _buildOutputCard(context, outputs[i], i),
                                childCount: outputs.length,
                              ),
                            ),
                          ),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 40),
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

  // ── Sub-widgets ─────────────────────────────────────────────────────────────

  Widget _buildAppBar(
      BuildContext context, WidgetRef ref, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Icon(Icons.arrow_back_ios_new,
                  color: AppColors.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.check_circle_outline,
                color: Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Results · $count file${count == 1 ? '' : 's'}',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: () {
              ref.read(colorGradeProvider.notifier).reset();
              context.go('/color-grade');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                'New Batch',
                style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildStepIndicator({required int activeStep}) {
    const steps = ['Reference', 'Batch', 'Results'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == activeStep;
        final isDone = i < activeStep;
        final isLast = i == steps.length - 1;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isActive || isDone
                            ? const LinearGradient(colors: [
                                Color(0xFF10B981),
                                Color(0xFF3B82F6)
                              ])
                            : null,
                        color: isActive || isDone
                            ? null
                            : AppColors.surfaceLight,
                        border: Border.all(
                          color: isActive || isDone
                              ? Colors.transparent
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Center(
                        child: isDone || isActive
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 14)
                            : Text('${i + 1}',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(steps[i],
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isActive
                                ? const Color(0xFF10B981)
                                : AppColors.textMuted)),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 1.5,
                    margin: const EdgeInsets.only(bottom: 14),
                    color: isDone || isActive
                        ? const Color(0xFF10B981)
                        : AppColors.cardBorder,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSummaryCard(List<GradedImage> outputs) {
    final totalBytes =
        outputs.fold<int>(0, (sum, o) => sum + o.fileSizeBytes);
    final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    final fmtStr = outputs.isNotEmpty && outputs.first.format == ExportFormat.tiff ? 'TIFF' : 'JPEG';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.done_all_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${outputs.length} image${outputs.length == 1 ? '' : 's'} graded successfully',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Format: $fmtStr · Total output size: $totalMb MB',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 50.ms);
  }

  Widget _buildShareAllButton(
      BuildContext context, List<GradedImage> outputs) {
    return GradientButton(
      text: 'Export / Share All Images',
      onPressed: () => _shareAll(context, outputs),
      width: double.infinity,
      height: 48,
      gradientColors: [AppColors.primary, AppColors.secondary],
      icon: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildOutputCard(
      BuildContext context, GradedImage img, int index) {
    final file = File(img.outputPath);
    final exists = file.existsSync();
    final kb = (img.fileSizeBytes / 1024).toStringAsFixed(0);
    final ext = img.fileName.split('.').last.toUpperCase();

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 16,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: exists
                      ? Image.file(
                          file,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ext,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        img.fileName,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('$kb KB',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _shareOne(context, img),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.share_outlined,
                        color: AppColors.primaryLight, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 35).ms, duration: 250.ms).slideY(begin: 0.05, end: 0, duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 250.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined,
              color: AppColors.textMuted, size: 52),
          const SizedBox(height: 12),
          Text('No graded images in session',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Run the batch process to see results here',
              style:
                  TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: Icon(Icons.image_outlined,
            color: AppColors.textMuted, size: 36),
      ),
    );
  }

  // ── Export / Share Actions ──────────────────────────────────────────────────

  Future<void> _shareOne(BuildContext context, GradedImage img) async {
    _showExportOptionsSheet(context, [img]);
  }

  Future<void> _shareAll(
      BuildContext context, List<GradedImage> outputs) async {
    _showExportOptionsSheet(context, outputs);
  }

  void _showExportOptionsSheet(BuildContext context, List<GradedImage> outputs) {
    showModalBottomSheet(
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
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Export Graded Images (${outputs.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose where to save or share your graded photos',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  // Option 1: Save to Photos / Gallery
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _saveToGalleryDirect(context, outputs);
                    },
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
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.photo_library_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Save to Photos / Gallery',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Save directly to your camera roll album',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: AppColors.textMuted, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Option 2: Save to Files / Share Sheet
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _openNativeShareSheet(context, outputs);
                    },
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
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.folder_open_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Save to Files / Share Sheet',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Open iOS/Android sheet with Save to Files, AirDrop, etc.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: AppColors.textMuted, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNativeShareSheet(
      BuildContext context, List<GradedImage> outputs) async {
    final files = outputs
        .where((o) => File(o.outputPath).existsSync())
        .map((o) => XFile(o.outputPath))
        .toList();

    if (files.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No output files found to export'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }

    await Share.shareXFiles(
      files,
      text: '${files.length} images graded with AI Color Grade ✨',
    );
  }

  Future<void> _saveToGalleryDirect(
      BuildContext context, List<GradedImage> outputs) async {
    final hasPermission =
        await PermissionService.instance.requestStoragePermission(context);
    if (!hasPermission) return;

    int savedCount = 0;
    try {
      Directory? targetDir;
      if (Platform.isAndroid) {
        final picturesDir =
            Directory('/storage/emulated/0/Pictures/VisionAI_Graded');
        if (!picturesDir.existsSync()) {
          picturesDir.createSync(recursive: true);
        }
        targetDir = picturesDir;
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      for (final img in outputs) {
        final src = File(img.outputPath);
        if (src.existsSync()) {
          if (Platform.isAndroid) {
            final dest = File('${targetDir.path}/${img.fileName}');
            src.copySync(dest.path);
          }
          savedCount++;
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            Platform.isAndroid
                ? 'Saved $savedCount image${savedCount == 1 ? '' : 's'} to Pictures/VisionAI_Graded folder ✅'
                : 'Ready in Photos ($savedCount image${savedCount == 1 ? '' : 's'}) ✅',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }

      if (Platform.isIOS && context.mounted) {
        await _openNativeShareSheet(context, outputs);
      }
    } catch (e) {
      debugPrint('[ColorGradeResult] Save error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export completed ($savedCount images)'),
          backgroundColor: AppColors.primary,
        ));
      }
    }
  }
}
