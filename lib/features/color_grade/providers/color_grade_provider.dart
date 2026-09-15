import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/color_grade_models.dart';
import '../services/color_grade_engine.dart';
import '../services/color_grade_persistence.dart';
import '../services/master_batch_processor.dart';

class ColorGradeNotifier extends StateNotifier<ColorGradeState> {
  MasterBatchProcessor? _masterProcessor;

  ColorGradeNotifier() : super(const ColorGradeState());

  Future<void> _saveState() async {
    try {
      await ColorGradePersistence.instance.saveColorGradeState(state);
    } catch (_) {}
  }

  // ── Reference Pair Management ──────────────────────────────────────────────

  void setReferenceRaw(String path) {
    state = state.copyWith(referenceRawPath: path, error: null);
    _saveState();
  }

  void setReferenceGraded(String path) {
    state = state.copyWith(referenceGradedPath: path, error: null);
    _saveState();
  }

  void clearReferenceRaw() {
    state = state.copyWith(referenceRawPath: null);
    _saveState();
  }

  void clearReferenceGraded() {
    state = state.copyWith(referenceGradedPath: null);
    _saveState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void reset() {
    state = const ColorGradeState();
    _saveState();
  }

  Future<void> resetAllSession() async {
    _masterProcessor?.cancel();
    state = const ColorGradeState();
    await ColorGradePersistence.instance.clearState();
  }

  Future<void> analyzeGrade() async {
    if (state.referenceRawPath == null || state.referenceGradedPath == null) return;

    state = state.copyWith(status: ColorGradeStatus.analyzing, error: null);

    try {
      final engine = ColorGradeEngine.instance;
      final origImg = await engine.decodeAndDownsample(state.referenceRawPath!, maxDimension: 1024);
      final gradImg = await engine.decodeAndDownsample(state.referenceGradedPath!, maxDimension: 1024);

      final profile = await engine.analyzeReferencePair(
        refOriginal: origImg,
        refGraded: gradImg,
      );

      state = state.copyWith(
        status: ColorGradeStatus.readyToBatch,
        profile: profile,
      );

      _saveState();
    } catch (e) {
      state = state.copyWith(
        status: ColorGradeStatus.error,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ── Source Batch Management (500, 1000, 10000+ files) ──────────────────────

  void addBatchImages(List<String> paths) {
    final existingPaths = state.batchItems.map((i) => i.sourcePath).toSet();
    final newItems = <ColorGradeItem>[];

    for (final path in paths) {
      if (!existingPaths.contains(path)) {
        final ext = path.split('.').last.toLowerCase();
        newItems.add(ColorGradeItem(
          sourcePath: path,
          isRaw: ColorGradeItem.checkIsRaw(ext),
          status: ColorGradeItemStatus.pending,
        ));
      }
    }

    final updated = [...state.batchItems, ...newItems];
    state = state.copyWith(
      batchItems: updated,
      totalCount: updated.length,
      status: state.profile != null ? ColorGradeStatus.readyToBatch : ColorGradeStatus.idle,
    );

    _saveState();
  }

  void setBatchImages(List<String> paths) {
    clearBatch();
    addBatchImages(paths);
  }

  void clearBatch() {
    state = state.copyWith(
      batchItems: const [],
      processedCount: 0,
      totalCount: 0,
      outputs: const [],
    );
    _saveState();
  }

  // ── Master Batch Processing Execution ──────────────────────────────────────

  Future<void> processBatch() async {
    if (state.profile == null || state.batchItems.isEmpty) return;

    state = state.copyWith(
      status: ColorGradeStatus.processingBatch,
      processedCount: 0,
      error: null,
    );

    _masterProcessor = MasterBatchProcessor(maxConcurrent: 2);
    final sourcePaths = state.batchItems.map((i) => i.sourcePath).toList();

    try {
      final stream = _masterProcessor!.processMasterJob(
        sourcePaths: sourcePaths,
        profile: state.profile!,
        format: state.exportFormat,
        quality: state.jpegQuality,
      );

      await for (final update in stream) {
        if (!mounted) break;

        final updatedItems = List<ColorGradeItem>.from(state.batchItems);
        if (update.lastProcessedIndex != null && update.lastProcessedIndex! < updatedItems.length) {
          final idx = update.lastProcessedIndex!;
          final isSuccess = update.lastOutputPath != null;
          updatedItems[idx] = updatedItems[idx].copyWith(
            outputPath: update.lastOutputPath,
            status: isSuccess ? ColorGradeItemStatus.completed : ColorGradeItemStatus.failed,
            errorMessage: update.lastError,
            confidence: update.confidence,
          );
        }

        state = state.copyWith(
          batchItems: updatedItems,
          processedCount: update.completed + update.failed,
          totalCount: update.total,
          currentProcessingFile: update.lastSourcePath,
        );
      }

      state = state.copyWith(status: ColorGradeStatus.done);
      _saveState();
    } catch (e) {
      state = state.copyWith(status: ColorGradeStatus.error, error: e.toString());
    }
  }

  Future<void> runBatch() => processBatch();

  void cancelBatch() {
    _masterProcessor?.cancel();
    state = state.copyWith(status: ColorGradeStatus.idle);
  }

  void pauseBatch() {
    _masterProcessor?.pause();
  }

  void resumeBatch() {
    _masterProcessor?.resume();
  }

  void setExportFormat(ExportFormat format) {
    state = state.copyWith(exportFormat: format);
    _saveState();
  }

  void setJpegQuality(int quality) {
    state = state.copyWith(jpegQuality: quality);
    _saveState();
  }
}

final colorGradeProvider = StateNotifierProvider<ColorGradeNotifier, ColorGradeState>((ref) {
  return ColorGradeNotifier();
});
