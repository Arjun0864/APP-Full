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
  final Set<int> _selectedIndices = {};

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
            RepaintBoundary(
              child: SizedBox(
                width: sidePanelWidth,
                child: _buildReferencePairPanel(context, theme, state, notifier),
              ),
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
                    child: RepaintBoundary(
                      child: _buildInteractivePreviewCanvas(context, theme, state),
                    ),
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
            RepaintBoundary(
              child: SizedBox(
                width: sidePanelWidth,
                child: _buildParameterInspectorPanel(context, theme, state, notifier),
              ),
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
          // Header
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.goldBase.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.compare_arrows_rounded, size: 16, color: AppColors.goldBase),
              ),
              const SizedBox(width: 10),
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
          const SizedBox(height: 6),
          Text(
            'Upload the original and your graded version of the same photo.',
            style: TextStyle(fontSize: 10, color: theme.textMuted),
          ),
          const SizedBox(height: 16),

          // Drop Zone 1: Ungraded Reference
          _buildSingleReferenceDropZone(
            context: context,
            theme: theme,
            stepNumber: '1',
            title: 'Ungraded Original',
            subtitle: 'Raw or flat profile photo',
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

          const SizedBox(height: 12),

          // Drop Zone 2: Graded Reference
          _buildSingleReferenceDropZone(
            context: context,
            theme: theme,
            stepNumber: '2',
            title: 'Graded Reference',
            subtitle: 'Your desired colour aesthetic',
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
            height: 42,
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
                state.status == ColorGradeStatus.analyzing ? 'Analysing Color Model…' : 'Learn Reference Grade',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldBase,
                disabledBackgroundColor: theme.cardBorder,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),

          // Error message
          if (state.error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, size: 14, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: const TextStyle(fontSize: 10, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (state.learnedProfile != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.goldBase.withValues(alpha: 0.10),
                    AppColors.goldBase.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.goldBase.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.goldBase.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 12, color: AppColors.goldBase),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Grade Profile Active',
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
                    '17³ 3D LUT · 8-Band HSL · Tone Curve · Skin Protection',
                    style: TextStyle(fontSize: 9, color: theme.textSecondary, letterSpacing: 0.2),
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
    required String stepNumber,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 118,
        decoration: BoxDecoration(
          color: hasFile ? theme.cardBg : theme.cardBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasFile
                ? AppColors.goldBase.withValues(alpha: 0.5)
                : theme.cardBorder,
            width: hasFile ? 1.5 : 1,
          ),
        ),
        child: hasFile
            ? Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.file(
                        File(filePath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(Icons.broken_image, color: theme.textMuted),
                        ),
                      ),
                    ),
                  ),
                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(9),
                          bottomRight: Radius.circular(9),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              fileName,
                              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: onClear,
                            child: Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 11, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Step badge
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.goldBase,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Step $stepNumber',
                        style: const TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              )
            : InkWell(
                onTap: onPick,
                borderRadius: BorderRadius.circular(10),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: theme.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.cardBorder),
                        ),
                        child: Center(
                          child: Text(
                            stepNumber,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: theme.textMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 9, color: theme.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Click or drag & drop',
                        style: TextStyle(fontSize: 9, color: theme.textMuted, fontStyle: FontStyle.italic),
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
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: theme.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.cardBorder),
                ),
                child: Icon(Icons.photo_size_select_actual_outlined, size: 36, color: theme.textMuted),
              ),
              const SizedBox(height: 16),
              Text(
                'Interactive Studio Canvas',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Load a reference pair or drop photos to start colour grading',
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
                                            width: 24,
                                            height: 24,
                                            decoration: const BoxDecoration(
                                              color: AppColors.goldBase,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(color: Colors.black54, blurRadius: 6),
                                              ],
                                            ),
                                            child: const Icon(Icons.unfold_more, size: 14, color: Colors.black),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Labels
                          if (gradedPath != null) ...[
                            Positioned(
                              top: 12, left: 12,
                              child: _canvasLabel('BEFORE'),
                            ),
                            Positioned(
                              top: 12, right: 12,
                              child: _canvasLabel('AFTER'),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
          ),

          // Canvas Controls Floating Bar
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _canvasIconButton(
                    icon: _showSideBySide ? Icons.view_agenda_outlined : Icons.splitscreen_outlined,
                    tooltip: _showSideBySide ? 'Split View' : 'Side-by-Side',
                    onPressed: () => setState(() => _showSideBySide = !_showSideBySide),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _showSideBySide ? 'Side by Side' : 'Split View',
                    style: const TextStyle(fontSize: 10, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),

          // Current file indicator
          if (activeItem != null)
            Positioned(
              top: 12, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedPreviewIndex + 1} / ${state.batchItems.length}  •  ${activeItem.fileName}',
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _canvasLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 9, color: Colors.white60, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }

  Widget _canvasIconButton({required IconData icon, required String tooltip, required VoidCallback onPressed}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Batch Filmstrip Panel (Center Bottom — Supports 10,000+ files)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBatchFilmstripPanel(
    BuildContext context,
    AppCustomTheme theme,
    ColorGradeState state,
    ColorGradeNotifier notifier,
  ) {
    final isBatchDone = state.status == ColorGradeStatus.done;
    final totalCompleted = state.batchItems
        .where((i) => i.status == ColorGradeItemStatus.completed)
        .length;
    final selectedCompleted = _getSelectedCompleted(state).length;
    final hasSelection = _selectedIndices.isNotEmpty;

    // Smart download label & count:
    //   • No selection → Download All (N)  where N = all completed
    //   • Has selection → Download Selected (N)  where N = selected & completed
    final downloadLabel = hasSelection
        ? 'Download Selected ($selectedCompleted)'
        : 'Download All ($totalCompleted)';

    final allSelected = state.batchItems.isNotEmpty &&
        _selectedIndices.length == state.batchItems.length;

    return DropTarget(
      onDragDone: (detail) {
        final paths = detail.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) {
          notifier.addBatchImages(paths);
        }
      },
      child: Container(
        color: theme.surface,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.goldBase.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.collections_outlined, size: 14, color: AppColors.goldBase),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.batchItems.isEmpty
                        ? 'BATCH FILMSTRIP'
                        : 'BATCH FILMSTRIP  ·  ${state.batchItems.length} images',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: theme.textMuted,
                      letterSpacing: 0.7,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // Select All / Uncheck All toggle
                if (state.batchItems.isNotEmpty) ...[
                  _filmstripActionButton(
                    icon: allSelected ? Icons.deselect : Icons.select_all,
                    label: allSelected ? 'Uncheck All' : 'Select All',
                    theme: theme,
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          _selectedIndices.clear();
                        } else {
                          _selectedIndices.addAll(
                            List.generate(state.batchItems.length, (i) => i),
                          );
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                ],

                // ── Smart Download Button ────────────────────────────────
                // Shows ONLY after the entire batch is done grading.
                // • No photos checked  → downloads ALL completed photos
                // • Photos checked     → downloads ONLY the checked ones
                if (isBatchDone && totalCompleted > 0) ...[
                  _filmstripActionButton(
                    icon: Icons.download_rounded,
                    label: downloadLabel,
                    theme: theme,
                    accent: true,
                    onPressed: () => hasSelection
                        ? _downloadSelected(context, state)
                        : _downloadAll(context, state),
                  ),
                  const SizedBox(width: 6),
                ],

                // Add Images button
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
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 13),
                  label: const Text('Add Photos', style: TextStyle(fontSize: 10)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),

                if (state.batchItems.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Clear Filmstrip',
                    icon: const Icon(Icons.delete_outline, size: 15),
                    onPressed: () {
                      setState(() => _selectedIndices.clear());
                      notifier.clearBatch();
                    },
                    splashRadius: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Virtualized Filmstrip Grid
            Expanded(
              child: state.batchItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 32, color: theme.textMuted),
                          const SizedBox(height: 8),
                          Text(
                            'Drag & drop photos here or click Add Photos',
                            style: TextStyle(fontSize: 11, color: theme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Supports JPG · PNG · RAW (CR2, NEF, ARW, DNG…)',
                            style: TextStyle(fontSize: 9, color: theme.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.batchItems.length,
                      itemExtent: 116,
                      itemBuilder: (context, index) {
                        final item = state.batchItems[index];
                        final isSelected = index == _selectedPreviewIndex;
                        final isChecked = _selectedIndices.contains(index);
                        return _buildFilmstripItem(
                          context, theme, item, index, isSelected, isChecked,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filmstripActionButton({
    required IconData icon,
    required String label,
    required AppCustomTheme theme,
    bool accent = false,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.goldBase.withValues(alpha: 0.15)
              : theme.cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: accent ? AppColors.goldBase.withValues(alpha: 0.5) : theme.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: accent ? AppColors.goldBase : theme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: accent ? AppColors.goldLight : theme.textSecondary,
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
    bool isChecked,
  ) {
    final fileName = item.fileName;
    final displayPath = item.outputPath ?? item.sourcePath;

    return GestureDetector(
      onTap: () => setState(() => _selectedPreviewIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.goldBase : (isChecked ? AppColors.goldBase.withValues(alpha: 0.5) : theme.cardBorder),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.goldBase.withValues(alpha: 0.2), blurRadius: 8)]
              : null,
        ),
        child: Stack(
          children: [
            // Thumbnail image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.file(
                  File(displayPath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: theme.surfaceLight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.isRaw ? Icons.raw_on_outlined : Icons.image_outlined,
                          size: 22, color: theme.textMuted,
                        ),
                        const SizedBox(height: 4),
                        Text('Loading…', style: TextStyle(fontSize: 8, color: theme.textMuted)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Gradient overlay at bottom (for filename readability)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(5, 12, 5, 4),
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Top-left: Checkbox
            Positioned(
              top: 4, left: 4,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isChecked) {
                      _selectedIndices.remove(index);
                    } else {
                      _selectedIndices.add(index);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: isChecked ? AppColors.goldBase : Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isChecked ? AppColors.goldBase : Colors.white30,
                      width: 1.5,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check, size: 11, color: Colors.black)
                      : null,
                ),
              ),
            ),

            // Top-right: Status badge
            Positioned(
              top: 4, right: 4,
              child: _buildItemStatusBadge(item.status),
            ),

            // Center: Preview button (shows on hover via mouse region or tap)
            if (item.outputPath != null || item.sourcePath.isNotEmpty)
              Positioned(
                bottom: 24, left: 0, right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _showPhotoPreview(context, item),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Icon(Icons.zoom_in_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemStatusBadge(ColorGradeItemStatus status) {
    switch (status) {
      case ColorGradeItemStatus.completed:
        return Container(
          width: 18, height: 18,
          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 11, color: Colors.white),
        );
      case ColorGradeItemStatus.processing:
        return Container(
          width: 18, height: 18,
          decoration: const BoxDecoration(color: AppColors.goldBase, shape: BoxShape.circle),
          child: const SizedBox(
            width: 11, height: 11,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black),
          ),
        );
      case ColorGradeItemStatus.failed:
        return Container(
          width: 18, height: 18,
          decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
          child: const Icon(Icons.close, size: 11, color: Colors.white),
        );
      case ColorGradeItemStatus.pending:
        return const SizedBox.shrink();
    }
  }

  void _showPhotoPreview(BuildContext context, ColorGradeItem item) {
    final previewPath = item.outputPath ?? item.sourcePath;
    final isGraded = item.outputPath != null;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isGraded ? AppColors.goldBase.withValues(alpha: 0.2) : Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isGraded ? '✦ GRADED' : 'ORIGINAL',
                      style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                        color: isGraded ? AppColors.goldBase : Colors.white60,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.fileName,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => Navigator.of(ctx).pop(),
                    splashRadius: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Image
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.80,
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: Image.file(
                  File(previewPath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black,
                    padding: const EdgeInsets.all(32),
                    child: const Text('Unable to load image', style: TextStyle(color: Colors.white54)),
                  ),
                ),
              ),
            ),

            // Download this photo button (if graded)
            if (isGraded) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _downloadSingleItem(context, item),
                icon: const Icon(Icons.download_rounded, size: 16, color: Colors.black),
                label: const Text('Save This Photo', style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.goldBase,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _downloadSingleItem(BuildContext context, ColorGradeItem item) async {
    if (item.outputPath == null) return;
    final fileName = item.outputPath!.split(Platform.pathSeparator).last;
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Graded Photo',
      fileName: fileName,
    );
    if (savePath == null) return;
    try {
      await File(item.outputPath!).copy(savePath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Saved to $savePath'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  List<ColorGradeItem> _getSelectedCompleted(ColorGradeState state) {
    return _selectedIndices
        .where((i) => i < state.batchItems.length)
        .map((i) => state.batchItems[i])
        .where((item) => item.status == ColorGradeItemStatus.completed && item.outputPath != null)
        .toList();
  }

  Future<void> _downloadSelected(BuildContext context, ColorGradeState state) async {
    final items = _getSelectedCompleted(state);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No completed photos in your selection'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose Folder to Save Photos');
    if (dir == null) return;

    int saved = 0;
    for (final item in items) {
      try {
        final src = File(item.outputPath!);
        final fileName = item.outputPath!.split(Platform.pathSeparator).last;
        await src.copy('$dir${Platform.pathSeparator}$fileName');
        saved++;
      } catch (_) {}
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $saved photo${saved == 1 ? '' : 's'} saved to $dir'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Downloads every completed batch photo to a user-chosen folder.
  /// Called when the smart Download button is tapped with no checkboxes selected.
  Future<void> _downloadAll(BuildContext context, ColorGradeState state) async {
    final allCompleted = state.batchItems
        .where((i) => i.status == ColorGradeItemStatus.completed && i.outputPath != null)
        .toList();

    if (allCompleted.isEmpty) return;

    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Folder to Save All Graded Photos',
    );
    if (dir == null) return;

    int saved = 0;
    for (final item in allCompleted) {
      try {
        final src = File(item.outputPath!);
        final fileName = item.outputPath!.split(Platform.pathSeparator).last;
        await src.copy('$dir${Platform.pathSeparator}$fileName');
        saved++;
      } catch (_) {}
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $saved photo${saved == 1 ? '' : 's'} saved to $dir'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.goldBase.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, size: 16, color: AppColors.goldBase),
              ),
              const SizedBox(width: 10),
              Text(
                'GRADE INSPECTOR',
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
            child: profile == null
                ? _buildEmptyInspector(theme)
                : ListView(
                    children: [
                      // Batch progress bar (when processing)
                      if (isProcessing) ...[
                        _buildInspectorProgress(theme, state),
                        const SizedBox(height: 16),
                      ],

                      _buildSectionHeader(theme, 'TONAL RANGE'),
                      _buildMetricBar(theme, 'Shadow Lift', (profile.shadowShift + 0.1) / 0.2, profile.shadowShift.toStringAsFixed(3)),
                      _buildMetricBar(theme, 'Midtone Contrast', (profile.midtoneContrast - 0.8) / 0.5, profile.midtoneContrast.toStringAsFixed(2)),
                      _buildMetricBar(theme, 'Highlight Rolloff', (profile.highlightRolloff - 0.8) / 0.4, profile.highlightRolloff.toStringAsFixed(2)),

                      const SizedBox(height: 16),
                      _buildSectionHeader(theme, '8-BAND HSL'),
                      _buildHSLBandRow('Red', profile.hslHueShifts[0], profile.hslSatRatios[0], theme),
                      _buildHSLBandRow('Orange / Skin', profile.hslHueShifts[1], profile.hslSatRatios[1], theme),
                      _buildHSLBandRow('Yellow', profile.hslHueShifts[2], profile.hslSatRatios[2], theme),
                      _buildHSLBandRow('Green', profile.hslHueShifts[3], profile.hslSatRatios[3], theme),
                      _buildHSLBandRow('Cyan', profile.hslHueShifts[4], profile.hslSatRatios[4], theme),
                      _buildHSLBandRow('Blue', profile.hslHueShifts[5], profile.hslSatRatios[5], theme),

                      const SizedBox(height: 16),
                      _buildSectionHeader(theme, 'PRO EXPORT'),
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
                                      const SnackBar(content: Text('Exported Adobe .CUBE 3D LUT')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.file_download_outlined, size: 12),
                              label: const Text('.CUBE', style: TextStyle(fontSize: 10)),
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
                                      const SnackBar(content: Text('Exported Lightroom .XMP preset')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.tune_outlined, size: 12),
                              label: const Text('.XMP', style: TextStyle(fontSize: 10)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 12),

          // Master Batch Execution Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: (state.learnedProfile != null &&
                      state.batchItems.isNotEmpty &&
                      !isProcessing)
                  ? () => notifier.processBatch()
                  : null,
              icon: isProcessing
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 22, color: Colors.black),
              label: Text(
                isProcessing
                    ? 'Processing…'
                    : 'Process Batch  (${state.batchItems.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldBase,
                disabledBackgroundColor: theme.cardBorder,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyInspector(AppCustomTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: theme.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.cardBorder),
            ),
            child: Icon(Icons.tune_rounded, size: 24, color: theme.textMuted),
          ),
          const SizedBox(height: 12),
          Text(
            'No grade profile yet',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Load a reference pair\nand click Learn Reference Grade',
            style: TextStyle(fontSize: 10, color: theme.textMuted, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorProgress(AppCustomTheme theme, ColorGradeState state) {
    final total = state.batchItems.length;
    final completed = state.batchItems.where((i) => i.status == ColorGradeItemStatus.completed).length;
    final failed = state.batchItems.where((i) => i.status == ColorGradeItemStatus.failed).length;
    final progress = total > 0 ? (completed + failed) / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.goldBase.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBase.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completed / $total photos',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.goldLight),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.goldBase),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: theme.cardBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.goldBase),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(AppCustomTheme theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3, height: 12,
            decoration: BoxDecoration(
              color: AppColors.goldBase,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.goldLight,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBar(AppCustomTheme theme, String label, double fraction, String valueStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: theme.textSecondary)),
              Text(valueStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.goldLight)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: theme.cardBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.goldBase),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHSLBandRow(String band, double hue, double sat, AppCustomTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(band, style: TextStyle(fontSize: 10, color: theme.textSecondary)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('H ${hue.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 9, color: AppColors.goldLight)),
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ((hue + 30) / 60).clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: theme.cardBorder,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.goldBase),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  child: Text(
                    'S ${(sat * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 9, color: AppColors.goldLight),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
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
