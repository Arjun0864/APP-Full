import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/gradient_button.dart';
import '../models/color_grade_models.dart';
import '../providers/color_grade_provider.dart';

import 'image_source_sheet.dart';

class ColorGradeBatchScreen extends ConsumerStatefulWidget {
  const ColorGradeBatchScreen({super.key});

  @override
  ConsumerState<ColorGradeBatchScreen> createState() =>
      _ColorGradeBatchScreenState();
}

class _ColorGradeBatchScreenState
    extends ConsumerState<ColorGradeBatchScreen> {

  static const _maxImages = 200;
  static const _allowedExtensions = [
    'jpg', 'jpeg', 'cr2', 'cr3', 'nef', 'arw', 'dng', 'raf', 'rw2', 'orf', 'png', 'webp', 'tif', 'tiff'
  ];

  Future<void> _pickBatchImages() async {
    await ImageSourceSheet.show(
      context: context,
      title: 'Select Batch Images',
      subtitle: 'Choose multiple photos from Gallery or Files (RAW supported)',
      allowMultiple: true,
      maxImages: _maxImages,
      allowedExtensions: _allowedExtensions,
      onSelected: (paths) {
        if (paths.isNotEmpty && mounted) {
          ref.read(colorGradeProvider.notifier).setBatchImages(paths);
          if (paths.length >= _maxImages) {
            _showSnack(
              'Selected maximum $_maxImages images limit',
              AppColors.warning,
            );
          }
        }
      },
    );
  }

  bool _isActionInProgress = false;

  Future<void> _runBatch() async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);
    try {
      await ref.read(colorGradeProvider.notifier).runBatch();
      if (!mounted) return;
      final state = ref.read(colorGradeProvider);
      if (state.status == ColorGradeStatus.done) {
        context.push('/color-grade/result');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(colorGradeProvider);
    final isProcessing = state.status == ColorGradeStatus.processingBatch;
    final canRun = state.hasBatchImages && !isProcessing;

    ref.listen(colorGradeProvider, (_, next) {
      if (next.status == ColorGradeStatus.error && next.error != null) {
        _showSnack(next.error!, AppColors.error);
        ref.read(colorGradeProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration:
            BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildStepIndicator(activeStep: 1),
                      const SizedBox(height: 24),

                      // Grade profile summary
                      if (state.profile != null) ...[
                        _buildProfileSummary(state.profile!),
                        const SizedBox(height: 20),
                      ],

                      // Export settings card
                      _buildExportSettings(state),
                      const SizedBox(height: 20),

                      // Batch picker zone
                      _sectionLabel('Select mixed RAW + JPEG input images (up to $_maxImages)'),
                      const SizedBox(height: 10),
                      _buildBatchPickerZone(state),
                      const SizedBox(height: 20),

                      // Batch list
                      if (state.batchItems.isNotEmpty) ...[
                        _buildBatchItemsList(state),
                        const SizedBox(height: 20),
                      ],

                      // Progress or CTA
                      if (isProcessing)
                        _buildBatchProgress(state)
                      else
                        GradientButton(
                          text: canRun
                              ? 'Apply Grade to ${state.inputPaths.length} Mixed File${state.inputPaths.length == 1 ? '' : 's'}'
                              : 'Select images first',
                          onPressed: canRun ? _runBatch : null,
                          width: double.infinity,
                          height: 54,
                          gradientColors: canRun
                              ? [
                                  const Color(0xFF10B981),
                                  const Color(0xFF3B82F6)
                                ]
                              : [AppColors.textMuted, AppColors.textMuted],
                          icon: const Icon(Icons.auto_fix_high_outlined,
                              color: Colors.white, size: 20),
                        ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-widgets ─────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
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
            child: const Icon(Icons.burst_mode_outlined,
                color: Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'Batch Processing',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
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
                        child: isDone
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 14)
                            : Text('${i + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isActive
                            ? const Color(0xFF10B981)
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 1.5,
                    margin: const EdgeInsets.only(bottom: 14),
                    color: isDone
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

  Widget _buildProfileSummary(GradeProfile profile) {
    final brightness = profile.brightnessShift;
    final contrast = profile.contrastRatio;
    final warmth = profile.warmthShift;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined,
                  color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 8),
              Text('Grade Profile Active',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatCell(
                label: 'Brightness',
                value: brightness > 0
                    ? '+${brightness.toStringAsFixed(1)}'
                    : brightness.toStringAsFixed(1),
                icon: brightness >= 0
                    ? Icons.brightness_high_outlined
                    : Icons.brightness_low_outlined,
                color: brightness >= 0
                    ? const Color(0xFFF59E0B)
                    : AppColors.secondary,
              ),
              _StatCell(
                label: 'Contrast',
                value: '×${contrast.toStringAsFixed(2)}',
                icon: Icons.contrast_outlined,
                color: AppColors.primary,
              ),
              _StatCell(
                label: 'Warmth',
                value: warmth > 0
                    ? '+${warmth.toStringAsFixed(1)}'
                    : warmth.toStringAsFixed(1),
                icon: Icons.thermostat_outlined,
                color: warmth >= 0
                    ? const Color(0xFFEC4899)
                    : AppColors.secondary,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 50.ms);
  }

  Widget _buildExportSettings(ColorGradeState state) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Export Format & Quality',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('JPEG (High Quality)'),
                  selected: state.exportFormat == ExportFormat.jpeg,
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(colorGradeProvider.notifier).setExportFormat(ExportFormat.jpeg);
                    }
                  },
                  selectedColor: const Color(0xFF10B981),
                  backgroundColor: AppColors.surfaceLight,
                  labelStyle: TextStyle(
                    color: state.exportFormat == ExportFormat.jpeg ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Text('TIFF (Uncompressed)'),
                  selected: state.exportFormat == ExportFormat.tiff,
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(colorGradeProvider.notifier).setExportFormat(ExportFormat.tiff);
                    }
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceLight,
                  labelStyle: TextStyle(
                    color: state.exportFormat == ExportFormat.tiff ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (state.exportFormat == ExportFormat.jpeg) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('JPEG Quality:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                Text('${state.jpegQuality}%', style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: state.jpegQuality.toDouble(),
              min: 50,
              max: 100,
              divisions: 50,
              activeColor: const Color(0xFF10B981),
              inactiveColor: AppColors.surfaceLight,
              onChanged: (val) {
                ref.read(colorGradeProvider.notifier).setJpegQuality(val.round());
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3),
    );
  }

  Widget _buildBatchPickerZone(ColorGradeState state) {
    final count = state.inputPaths.length;
    final rawCount = state.batchItems.where((i) => i.isRaw).length;
    final jpegCount = count - rawCount;

    return GestureDetector(
      onTap: _pickBatchImages,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: count > 0
              ? const Color(0xFF10B981).withValues(alpha: 0.08)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: count > 0
                ? const Color(0xFF10B981)
                : AppColors.cardBorder,
            width: count > 0 ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              count > 0
                  ? Icons.collections
                  : Icons.add_photo_alternate_outlined,
              color: count > 0
                  ? const Color(0xFF10B981)
                  : AppColors.textMuted,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              count > 0
                  ? '$count images selected ($rawCount RAW, $jpegCount JPEG)'
                  : 'Tap to select RAW + JPEG files',
              style: TextStyle(
                color: count > 0
                    ? const Color(0xFF10B981)
                    : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              count > 0
                  ? 'Tap to change selection'
                  : 'CR2, CR3, NEF, ARW, DNG, RAF, JPG, PNG — max $_maxImages',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildBatchItemsList(ColorGradeState state) {
    final items = state.batchItems;
    final displayList = items.take(15).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionLabel('Batch File Queue (${items.length})'),
            const Spacer(),
            if (items.length > 15)
              Text(
                '+${items.length - 15} more files',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayList.length,
          itemBuilder: (context, idx) {
            final item = displayList[idx];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.isRaw ? const Color(0xFF7C3AED) : const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.extension.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.fileName,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.confidence != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (item.confidence! < 0.50) ...[
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'Low overlap (${(item.confidence! * 100).toInt()}%)',
                                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ] else ...[
                                Text(
                                  'Match ${(item.confidence! * 100).toInt()}%',
                                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 10),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item.isSuccess)
                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16)
                  else if (item.errorMessage != null)
                    const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                ],
              ),
            ).animate().fadeIn(delay: (idx * 20).ms, duration: 200.ms).slideX(begin: 0.04, end: 0, duration: 200.ms, curve: Curves.easeOutCubic);
          },
        ),
      ],
    );
  }

  Widget _buildBatchProgress(ColorGradeState state) {
    final processed = state.processedCount;
    final total = state.totalCount;
    final progress = state.batchProgress;
    final pct = (progress * 100).toInt();

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation(Color(0xFF10B981)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Grading file $processed of $total…',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (state.currentProcessingFile != null) ...[
            const SizedBox(height: 6),
            Text(
              'Current: ${state.currentProcessingFile}',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceLight,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF10B981)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Processing 100% locally on device — originals untouched',
            style:
                TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCell(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          Text(label,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}
