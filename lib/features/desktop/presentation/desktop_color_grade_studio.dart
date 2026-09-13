import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../color_grade/models/color_grade_models.dart';
import '../../color_grade/providers/color_grade_provider.dart';
import '../../color_grade/services/color_grade_engine.dart';

class DesktopColorGradeStudio extends ConsumerStatefulWidget {
  const DesktopColorGradeStudio({super.key});

  @override
  ConsumerState<DesktopColorGradeStudio> createState() => _DesktopColorGradeStudioState();
}

class _DesktopColorGradeStudioState extends ConsumerState<DesktopColorGradeStudio> {
  double _splitPosition = 0.5;
  int _selectedPreviewIndex = 0;
  bool _showSideBySide = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final state = ref.watch(colorGradeProvider);
    final notifier = ref.read(colorGradeProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1200;
        final isVeryCompact = constraints.maxWidth < 900;
        final sidePanelWidth = isVeryCompact ? 240.0 : (isCompact ? 270.0 : 310.0);

        return Row(
          children: [
            // ── Left Panel: Reference Pair Studio ──────────────────────────
            SizedBox(
              width: sidePanelWidth,
              child: _buildReferencePairPanel(context, theme, state, notifier),
            ),

            // ── Vertical Divider ───────────────────────────────────────────
            VerticalDivider(width: 1, color: theme.cardBorder),

            // ── Center Panel: Interactive Canvas & Large-Batch Filmstrip ───
            Expanded(
              child: Column(
                children: [
                  // Top Canvas Before/After View
                  Expanded(
                    flex: 6,
                    child: _buildInteractivePreviewCanvas(context, theme, state),
                  ),

                  // Horizontal Divider
                  Divider(height: 1, color: theme.cardBorder),

                  // Bottom Source Images Filmstrip & Drop Zone
                  Expanded(
                    flex: 4,
                    child: _buildBatchFilmstripPanel(context, theme, state, notifier),
                  ),
                ],
              ),
            ),

            // ── Vertical Divider ───────────────────────────────────────────
            VerticalDivider(width: 1, color: theme.cardBorder),

            // ── Right Panel: Parameter Inspector & Master Action ───────────
            SizedBox(
              width: sidePanelWidth,
              child: _buildParameterInspectorPanel(context, theme, state, notifier),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Reference Pair Panel (Left)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildReferencePairPanel(
    BuildContext context,
    AppCustomTheme theme,
    ColorGradeState state,
    ColorGradeNotifier notifier,
  ) {
    return Container(
      color: theme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded, size: 16, color: AppColors.goldBase),
              const SizedBox(width: 8),
              Text(
                'REFERENCE PAIR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Drop Zone 1: Ungraded Reference (1 Image Only)
          _buildSingleReferenceDropZone(
            context: context,
            theme: theme,
            title: '1. Ungraded Reference',
            subtitle: 'Original raw or flat profile image',
            filePath: state.referenceRawPath,
            onDropped: (path) => notifier.setReferenceRaw(path),
            onPick: () async {
              final result = await FilePicker.platform.pickFiles(type: FileType.image);
              if (result != null && result.files.single.path != null) {
                notifier.setReferenceRaw(result.files.single.path!);
              }
            },
            onClear: () => notifier.clearReferenceRaw(),
          ),

          const SizedBox(height: 14),

          // Drop Zone 2: Graded Reference (1 Image Only)
          _buildSingleReferenceDropZone(
            context: context,
            theme: theme,
            title: '2. Graded Reference',
            subtitle: 'Desired aesthetic & target grade',
            filePath: state.referenceGradedPath,
            onDropped: (path) => notifier.setReferenceGraded(path),
            onPick: () async {
              final result = await FilePicker.platform.pickFiles(type: FileType.image);
              if (result != null && result.files.single.path != null) {
                notifier.setReferenceGraded(result.files.single.path!);
              }
            },
            onClear: () => notifier.clearReferenceGraded(),
          ),

          const SizedBox(height: 16),

          // Learn / Analyze Action Button
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: (state.referenceRawPath != null &&
                      state.referenceGradedPath != null &&
                      state.status != ColorGradeStatus.analyzing)
                  ? () => notifier.analyzeGrade()
                  : null,
              icon: state.status == ColorGradeStatus.analyzing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.auto_fix_high, size: 16, color: Colors.black),
              label: Text(
                state.status == ColorGradeStatus.analyzing ? 'Analyzing Color Model...' : 'Learn Reference Grade',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldBase,
                disabledBackgroundColor: theme.cardBorder,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          if (state.learnedProfile != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.goldBase.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.goldBase.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: AppColors.goldBase),
                      SizedBox(width: 6),
                      Text(
                        'Profile Ready & Active',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.goldLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '17x17x17 3D LUT Grid generated with 8-Band HSL transformations and skin protection.',
                    style: TextStyle(fontSize: 10, color: theme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildSingleReferenceDropZone({
    required BuildContext context,
    required AppCustomTheme theme,
    required String title,
    required String subtitle,
    required String? filePath,
    required Function(String) onDropped,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasFile = filePath != null && filePath.isNotEmpty;
    final fileName = hasFile ? filePath.split(Platform.pathSeparator).last : '';

    return DropTarget(
      onDragDone: (detail) {
        if (detail.files.isNotEmpty) {
          onDropped(detail.files.first.path);
        }
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasFile ? AppColors.goldBase.withValues(alpha: 0.6) : theme.cardBorder,
            width: 1,
          ),
        ),
        child: hasFile
            ? Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(filePath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(Icons.broken_image, color: theme.textMuted),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: Colors.black.withValues(alpha: 0.75),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              fileName,
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: onClear,
                            child: const Icon(Icons.close, size: 14, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : InkWell(
                onTap: onPick,
                borderRadius: BorderRadius.circular(8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.file_upload_outlined, size: 22, color: theme.textSecondary),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.textPrimary),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 9, color: theme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Interactive Preview Canvas (Center Top)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildInteractivePreviewCanvas(
    BuildContext context,
    AppCustomTheme theme,
    ColorGradeState state,
  ) {
    // Current active preview file
    final activeItem = state.batchItems.isNotEmpty && _selectedPreviewIndex < state.batchItems.length
        ? state.batchItems[_selectedPreviewIndex]
        : null;

    final sourcePath = activeItem?.sourcePath ?? state.referenceRawPath;
    final gradedPath = activeItem?.outputPath ?? state.referenceGradedPath;

    if (sourcePath == null) {
      return Container(
        color: theme.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_size_select_actual_outlined, size: 48, color: theme.textMuted),
              const SizedBox(height: 12),
              Text(
                'Interactive Studio Canvas',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Load a reference pair or drop source images to view real-time color grading',
                style: TextStyle(fontSize: 11, color: theme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Canvas Render View
          Positioned.fill(
            child: _showSideBySide
                ? Row(
                    children: [
                      Expanded(
                        child: Image.file(File(sourcePath), fit: BoxFit.contain),
                      ),
                      if (gradedPath != null) ...[
                        const VerticalDivider(width: 1, color: Colors.white24),
                        Expanded(
                          child: Image.file(File(gradedPath), fit: BoxFit.contain),
                        ),
                      ],
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Base Ungraded Image (Left)
                          Image.file(File(sourcePath), fit: BoxFit.contain),

                          // Top Graded Image (Clipped by Split Slider)
                          if (gradedPath != null)
                            ClipRect(
                              clipper: _SplitViewClipper(_splitPosition),
                              child: Image.file(File(gradedPath), fit: BoxFit.contain),
                            ),

                          // Split Slider Bar
                          if (gradedPath != null)
                            Positioned(
                              left: constraints.maxWidth * _splitPosition - 12,
                              top: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onHorizontalDragUpdate: (details) {
                                  setState(() {
                                    _splitPosition = (_splitPosition + details.delta.dx / constraints.maxWidth)
                                        .clamp(0.05, 0.95);
                                  });
                                },
                                child: Container(
                                  width: 24,
                                  color: Colors.transparent,
                                  child: Center(
                                    child: Container(
                                      width: 2,
                                      color: AppColors.goldBase,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: const BoxDecoration(
                                              color: AppColors.goldBase,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black54,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.unfold_more,
                                              size: 14,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),

          // Canvas Controls Floating Bar
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Toggle Side-by-Side Mode',
                    icon: Icon(
                      _showSideBySide ? Icons.view_agenda_outlined : Icons.splitscreen_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    onPressed: () => setState(() => _showSideBySide = !_showSideBySide),
                    splashRadius: 14,
                  ),
                  const SizedBox(width: 4),
                  const Text('Before / After', style: TextStyle(fontSize: 10, color: Colors.white70)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Batch Filmstrip Panel (Center Bottom - Supports 10,000+ files)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBatchFilmstripPanel(
    BuildContext context,
    AppCustomTheme theme,
    ColorGradeState state,
    ColorGradeNotifier notifier,
  ) {
    return DropTarget(
      onDragDone: (detail) {
        final paths = detail.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) {
          notifier.addBatchImages(paths);
        }
      },
      child: Container(
        color: theme.surface,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.collections_outlined, size: 16, color: AppColors.goldBase),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SOURCE BATCH FILMSTRIP (${state.batchItems.length} Images Loaded)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.textMuted,
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      allowMultiple: true,
                      type: FileType.custom,
                      allowedExtensions: [
                        'jpg', 'jpeg', 'png', 'tif', 'tiff', 'cr2', 'cr3', 'nef', 'arw', 'dng', 'raf', 'rw2', 'orf'
                      ],
                    );
                    if (result != null) {
                      final paths = result.files.where((f) => f.path != null).map((f) => f.path!).toList();
                      notifier.addBatchImages(paths);
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 14),
                  label: const Text('Add Images / Folder', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                if (state.batchItems.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear Filmstrip',
                    icon: const Icon(Icons.delete_outline, size: 16),
                    onPressed: () => notifier.clearBatch(),
                    splashRadius: 14,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Virtualized Filmstrip Grid (Efficient for 10,000+ files)
            Expanded(
              child: state.batchItems.isEmpty
                  ? Center(
                      child: Text(
                        'Drag and drop images or full photo folders here for high-throughput batch grading',
                        style: TextStyle(fontSize: 11, color: theme.textMuted),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.batchItems.length,
                      itemExtent: 110,
                      itemBuilder: (context, index) {
                        final item = state.batchItems[index];
                        final isSelected = index == _selectedPreviewIndex;
                        return _buildFilmstripItem(context, theme, item, index, isSelected);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilmstripItem(
    BuildContext context,
    AppCustomTheme theme,
    ColorGradeItem item,
    int index,
    bool isSelected,
  ) {
    final fileName = item.sourcePath.split(Platform.pathSeparator).last;
    return GestureDetector(
      onTap: () => setState(() => _selectedPreviewIndex = index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.goldBase : theme.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.file(
                  File(item.outputPath ?? item.sourcePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: theme.surfaceLight,
                    child: Icon(Icons.insert_drive_file, size: 20, color: theme.textMuted),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: _buildItemStatusBadge(item.status),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                color: Colors.black.withValues(alpha: 0.7),
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 9, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemStatusBadge(ColorGradeItemStatus status) {
    Color bg;
    IconData icon;
    switch (status) {
      case ColorGradeItemStatus.completed:
        bg = AppColors.success;
        icon = Icons.check;
        break;
      case ColorGradeItemStatus.processing:
        bg = AppColors.goldBase;
        icon = Icons.sync;
        break;
      case ColorGradeItemStatus.failed:
        bg = AppColors.error;
        icon = Icons.close;
        break;
      case ColorGradeItemStatus.pending:
        return const SizedBox.shrink();
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 10, color: Colors.black),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Parameter Inspector Panel (Right)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildParameterInspectorPanel(
    BuildContext context,
    AppCustomTheme theme,
    ColorGradeState state,
    ColorGradeNotifier notifier,
  ) {
    final profile = state.learnedProfile;
    final isProcessing = state.status == ColorGradeStatus.processingBatch;

    return Container(
      color: theme.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 16, color: AppColors.goldBase),
              const SizedBox(width: 8),
              Text(
                'GRADING INSPECTOR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Expanded(
            child: ListView(
              children: [
                // Tone Curve Adjustments
                _buildSectionHeader(theme, 'TONAL RANGE & DYNAMICS'),
                _buildMetricRow('Shadow Shift', profile?.shadowShift.toStringAsFixed(2) ?? '0.00', theme),
                _buildMetricRow('Midtone Contrast', profile?.midtoneContrast.toStringAsFixed(2) ?? '1.00', theme),
                _buildMetricRow('Highlight Rolloff', profile?.highlightRolloff.toStringAsFixed(2) ?? '1.00', theme),
                _buildMetricRow('Skin Protection', profile?.skinSatRatio.toStringAsFixed(2) ?? '1.00', theme),

                const SizedBox(height: 16),
                _buildSectionHeader(theme, '8-BAND HSL HARMONIZATION'),
                if (profile != null) ...[
                  _buildHSLBandRow('Red Band', profile.hslHueShifts[0], profile.hslSatRatios[0], theme),
                  _buildHSLBandRow('Orange Band (Skin)', profile.hslHueShifts[1], profile.hslSatRatios[1], theme),
                  _buildHSLBandRow('Yellow Band', profile.hslHueShifts[2], profile.hslSatRatios[2], theme),
                  _buildHSLBandRow('Green Band', profile.hslHueShifts[3], profile.hslSatRatios[3], theme),
                  _buildHSLBandRow('Cyan Band', profile.hslHueShifts[4], profile.hslSatRatios[4], theme),
                  _buildHSLBandRow('Blue Band', profile.hslHueShifts[5], profile.hslSatRatios[5], theme),
                ] else
                  Text(
                    'Analyze a reference pair to extract 8-band spectral grading curves.',
                    style: TextStyle(fontSize: 10, color: theme.textMuted),
                  ),

                if (profile != null) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader(theme, 'PRO COLOR FORMATS & EXPORTS'),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final cubeStr = ColorGradeEngine.instance.exportToCubeLUT(profile);
                            final savePath = await FilePicker.platform.saveFile(
                              dialogTitle: 'Export 3D LUT',
                              fileName: 'AIVista_Studio.cube',
                            );
                            if (savePath != null) {
                              await File(savePath).writeAsString(cubeStr);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Exported Adobe .CUBE 3D LUT successfully')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.file_download_outlined, size: 12),
                          label: const Text('.CUBE LUT', style: TextStyle(fontSize: 10)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final xmpStr = ColorGradeEngine.instance.exportToXmpSidecar(profile);
                            final savePath = await FilePicker.platform.saveFile(
                              dialogTitle: 'Export Lightroom Preset',
                              fileName: 'AIVista_Preset.xmp',
                            );
                            if (savePath != null) {
                              await File(savePath).writeAsString(xmpStr);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Exported Lightroom .XMP sidecar successfully')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.tune_outlined, size: 12),
                          label: const Text('.XMP Preset', style: TextStyle(fontSize: 10)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Master Batch Execution Action Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: (state.learnedProfile != null &&
                      state.batchItems.isNotEmpty &&
                      !isProcessing)
                  ? () => notifier.processBatch()
                  : null,
              icon: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.black),
              label: Text(
                isProcessing
                    ? 'Processing Bounded Queue...'
                    : 'Process Master Batch (${state.batchItems.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldBase,
                disabledBackgroundColor: theme.cardBorder,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(AppCustomTheme theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.goldLight, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, AppCustomTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: theme.textSecondary)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildHSLBandRow(String band, double hue, double sat, AppCustomTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(band, style: TextStyle(fontSize: 10, color: theme.textSecondary)),
          Text(
            'H: ${hue.toStringAsFixed(1)}°  S: ${(sat * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.goldLight),
          ),
        ],
      ),
    );
  }
}

class _SplitViewClipper extends CustomClipper<Rect> {
  final double splitFraction;
  _SplitViewClipper(this.splitFraction);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(size.width * splitFraction, 0, size.width * (1 - splitFraction), size.height);
  }

  @override
  bool shouldReclip(_SplitViewClipper oldClipper) => oldClipper.splitFraction != splitFraction;
}
