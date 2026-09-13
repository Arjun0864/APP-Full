import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/color_grade_models.dart';
import 'color_grade_engine.dart';

/// Bounded Memory Master Batch Processor.
/// Capable of processing 500, 1,000, 10,000+ images without RAM bloat.
class MasterBatchProcessor {
  final int maxConcurrent;
  final int chunkSliceSize;
  bool _isCancelled = false;
  bool _isPaused = false;

  MasterBatchProcessor({
    this.maxConcurrent = 2,
    this.chunkSliceSize = 100,
  });

  void cancel() {
    _isCancelled = true;
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  /// Processes a master batch of items with bounded concurrency and direct-to-disk streaming.
  Stream<BatchProgressUpdate> processMasterJob({
    required List<String> sourcePaths,
    required GradeProfile profile,
    required ExportFormat format,
    required int quality,
  }) async* {
    _isCancelled = false;
    _isPaused = false;

    final totalCount = sourcePaths.length;
    final tempDir = await getTemporaryDirectory();
    final outputDir = Directory('${tempDir.path}/aivista_desktop_output');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    int completedCount = 0;
    int failedCount = 0;

    // Process items in chunks with bounded concurrency queue
    for (int i = 0; i < totalCount; i += maxConcurrent) {
      if (_isCancelled) {
        yield BatchProgressUpdate(
          total: totalCount,
          completed: completedCount,
          failed: failedCount,
          isCancelled: true,
        );
        break;
      }

      while (_isPaused && !_isCancelled) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final end = math.min(i + maxConcurrent, totalCount);
      final currentSlice = sourcePaths.sublist(i, end);

      // Execute worker tasks concurrently
      final futures = currentSlice.asMap().entries.map((entry) async {
        final itemIndex = i + entry.key;
        final path = entry.value;

        try {
          final file = File(path);
          if (!await file.exists()) {
            return _ProcessingResult(index: itemIndex, sourcePath: path, error: 'File not found');
          }

          final ext = path.split('.').last.toLowerCase();
          final bytes = await file.readAsBytes();

          // Apply color grading via isolate engine
          final gradedBytes = await compute(
            _isolateApplyTask,
            _IsolateApplyPayload(
              imageBytes: bytes,
              ext: ext,
              profile: profile,
              format: format,
              quality: quality,
            ),
          );

          if (gradedBytes == null || gradedBytes.isEmpty) {
            return _ProcessingResult(index: itemIndex, sourcePath: path, error: 'Grading output empty');
          }

          // Write output immediately to disk and free memory
          final baseName = path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'\.[^\.]+$'), '');
          final outExt = format == ExportFormat.tiff ? 'tif' : 'jpg';
          final outPath = '${outputDir.path}/${baseName}_graded.$outExt';
          await File(outPath).writeAsBytes(gradedBytes);

          return _ProcessingResult(index: itemIndex, sourcePath: path, outputPath: outPath);
        } catch (e) {
          return _ProcessingResult(index: itemIndex, sourcePath: path, error: e.toString());
        }
      }).toList();

      final results = await Future.wait(futures);

      for (final res in results) {
        if (res.isSuccess) {
          completedCount++;
        } else {
          failedCount++;
        }

        yield BatchProgressUpdate(
          total: totalCount,
          completed: completedCount,
          failed: failedCount,
          lastProcessedIndex: res.index,
          lastSourcePath: res.sourcePath,
          lastOutputPath: res.outputPath,
          lastError: res.error,
          isCancelled: _isCancelled,
        );
      }
    }
  }

  static Uint8List? _isolateApplyTask(_IsolateApplyPayload payload) {
    try {
      final decodable = ColorGradeEngine.extractDecodableBytes(payload.imageBytes, payload.ext);
      final graded = ColorGradeEngine.instance.applyGradeToBytes(
        decodable,
        payload.profile,
        targetQuality: payload.quality,
      );
      return graded;
    } catch (_) {
      return null;
    }
  }
}

class _IsolateApplyPayload {
  final Uint8List imageBytes;
  final String ext;
  final GradeProfile profile;
  final ExportFormat format;
  final int quality;

  _IsolateApplyPayload({
    required this.imageBytes,
    required this.ext,
    required this.profile,
    required this.format,
    required this.quality,
  });
}

class _ProcessingResult {
  final int index;
  final String sourcePath;
  final String? outputPath;
  final String? error;

  _ProcessingResult({
    required this.index,
    required this.sourcePath,
    this.outputPath,
    this.error,
  });

  bool get isSuccess => outputPath != null && error == null;
}

class BatchProgressUpdate {
  final int total;
  final int completed;
  final int failed;
  final int? lastProcessedIndex;
  final String? lastSourcePath;
  final String? lastOutputPath;
  final String? lastError;
  final bool isCancelled;

  BatchProgressUpdate({
    required this.total,
    required this.completed,
    required this.failed,
    this.lastProcessedIndex,
    this.lastSourcePath,
    this.lastOutputPath,
    this.lastError,
    this.isCancelled = false,
  });

  double get overallPercentage => total > 0 ? (completed + failed) / total : 0.0;
}
