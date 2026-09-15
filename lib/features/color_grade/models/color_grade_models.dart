import 'package:flutter/foundation.dart';

enum ExportFormat { jpeg, tiff, png }

enum ColorGradeItemStatus { pending, processing, completed, failed }

enum ColorGradeStatus {
  idle,
  analyzing,
  analyzingReference,
  readyToBatch,
  processingBatch,
  done,
  error,
}

/// Dynamically learned dominant hue cluster anchor
class DynamicHueAnchor {
  final double centerHue;
  final double hueShift;
  final double satRatio;
  final double lumRatio;
  final double weight;

  const DynamicHueAnchor({
    required this.centerHue,
    required this.hueShift,
    required this.satRatio,
    required this.lumRatio,
    this.weight = 1.0,
  });

  factory DynamicHueAnchor.fromJson(Map<String, dynamic> json) => DynamicHueAnchor(
        centerHue: (json['center_hue'] as num?)?.toDouble() ?? 0.0,
        hueShift: (json['hue_shift'] as num?)?.toDouble() ?? 0.0,
        satRatio: (json['sat_ratio'] as num?)?.toDouble() ?? 1.0,
        lumRatio: (json['lum_ratio'] as num?)?.toDouble() ?? 1.0,
        weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toJson() => {
        'center_hue': centerHue,
        'hue_shift': hueShift,
        'sat_ratio': satRatio,
        'lum_ratio': lumRatio,
        'weight': weight,
      };
}

/// Accuracy validation result comparing graded original vs ground-truth graded reference
class ValidationMetrics {
  final double meanDeltaE;
  final double maxDeltaE;
  final double ssim;

  const ValidationMetrics({
    required this.meanDeltaE,
    required this.maxDeltaE,
    required this.ssim,
  });

  factory ValidationMetrics.fromJson(Map<String, dynamic> json) => ValidationMetrics(
        meanDeltaE: (json['mean_delta_e'] as num?)?.toDouble() ?? 0.0,
        maxDeltaE: (json['max_delta_e'] as num?)?.toDouble() ?? 0.0,
        ssim: (json['ssim'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toJson() => {
        'mean_delta_e': meanDeltaE,
        'max_delta_e': maxDeltaE,
        'ssim': ssim,
      };
}

/// Learned reference grade matching profile.
/// Incorporates 3D Color LUT with confidence grid, global affine fallback in linear RGB,
/// dynamic dominant hue cluster anchors, monotonic tone transfer curves, and validation metrics.
class GradeProfile {
  // Global LAB statistics
  final double srcLMean;
  final double srcLStd;
  final double srcAMean;
  final double srcAStd;
  final double srcBMean;
  final double srcBStd;
  final double dstLMean;
  final double dstLStd;
  final double dstAMean;
  final double dstAStd;
  final double dstBMean;
  final double dstBStd;

  // 8-Band HSL Shifts (fallback)
  final List<double> hslHueShifts;
  final List<double> hslSatRatios;
  final List<double> hslLumRatios;

  // 256-Bin Tone Transfer Curve (Input Luminance [0..255] -> Output Luminance [0..1])
  final List<double> toneCurve;

  // Input Normalization Anchors
  final double refMedianLum;
  final double refDynamicRange;

  // 3-Zone Tonal Curve & Rolloff
  final double shadowShift;
  final double midtoneContrast;
  final double highlightRolloff;
  final double blackPoint;
  final double whitePoint;

  // Selective Target Anchors (fallback)
  final double targetSkinHue;
  final double targetSkinSat;
  final double targetSkinLum;
  final double skinHueShift;
  final double skinSatRatio;
  final double skinLumRatio;

  final double targetRedHue;
  final double targetRedSat;
  final double targetRedLum;

  final double targetGreenHue;
  final double targetGreenSat;
  final double targetGreenLum;

  // 3D Color LUT Grid (33x33x33 x 3 = 107,811 entries)
  final List<double> lut3D;

  // Per-Node Confidence Grid (33x33x33 = 35,937 entries, normalized [0..1])
  final List<double> confidenceGrid;

  // Global Affine Color Model (3x3 Matrix + 3x1 Offset in Linear RGB)
  final List<double> globalAffineMatrix;
  final List<double> globalOffset;

  // Generic Dominant Hue Anchors
  final List<DynamicHueAnchor> dominantHueAnchors;

  // Optional Validation Metrics
  final ValidationMetrics? validationMetrics;

  final String method;

  const GradeProfile({
    required this.srcLMean,
    required this.srcLStd,
    required this.srcAMean,
    required this.srcAStd,
    required this.srcBMean,
    required this.srcBStd,
    required this.dstLMean,
    required this.dstLStd,
    required this.dstAMean,
    required this.dstAStd,
    required this.dstBMean,
    required this.dstBStd,
    required this.hslHueShifts,
    required this.hslSatRatios,
    required this.hslLumRatios,
    this.toneCurve = const [],
    this.refMedianLum = 0.50,
    this.refDynamicRange = 1.0,
    required this.shadowShift,
    required this.midtoneContrast,
    required this.highlightRolloff,
    required this.blackPoint,
    required this.whitePoint,
    this.targetSkinHue = 27.5,
    this.targetSkinSat = 0.25,
    this.targetSkinLum = 0.62,
    required this.skinHueShift,
    required this.skinSatRatio,
    required this.skinLumRatio,
    this.targetRedHue = 356.0,
    this.targetRedSat = 0.75,
    this.targetRedLum = 0.45,
    this.targetGreenHue = 70.0,
    this.targetGreenSat = 0.25,
    this.targetGreenLum = 0.35,
    required this.lut3D,
    this.confidenceGrid = const [],
    this.globalAffineMatrix = const [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
    this.globalOffset = const [0.0, 0.0, 0.0],
    this.dominantHueAnchors = const [],
    this.validationMetrics,
    this.method = '3d_hybrid_confidence_reference_lut',
  });

  factory GradeProfile.fromJson(Map<String, dynamic> json) => GradeProfile(
        srcLMean: (json['src_l_mean'] as num?)?.toDouble() ?? 50.0,
        srcLStd: (json['src_l_std'] as num?)?.toDouble() ?? 10.0,
        srcAMean: (json['src_a_mean'] as num?)?.toDouble() ?? 0.0,
        srcAStd: (json['src_a_std'] as num?)?.toDouble() ?? 5.0,
        srcBMean: (json['src_b_mean'] as num?)?.toDouble() ?? 0.0,
        srcBStd: (json['src_b_std'] as num?)?.toDouble() ?? 5.0,
        dstLMean: (json['dst_l_mean'] as num?)?.toDouble() ?? 50.0,
        dstLStd: (json['dst_l_std'] as num?)?.toDouble() ?? 10.0,
        dstAMean: (json['dst_a_mean'] as num?)?.toDouble() ?? 0.0,
        dstAStd: (json['dst_a_std'] as num?)?.toDouble() ?? 5.0,
        dstBMean: (json['dst_b_mean'] as num?)?.toDouble() ?? 0.0,
        dstBStd: (json['dst_b_std'] as num?)?.toDouble() ?? 5.0,
        hslHueShifts: (json['hsl_hue_shifts'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? List.filled(8, 0.0),
        hslSatRatios: (json['hsl_sat_ratios'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? List.filled(8, 1.0),
        hslLumRatios: (json['hsl_lum_ratios'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? List.filled(8, 1.0),
        toneCurve: (json['tone_curve'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [],
        refMedianLum: (json['ref_median_lum'] as num?)?.toDouble() ?? 0.50,
        refDynamicRange: (json['ref_dynamic_range'] as num?)?.toDouble() ?? 1.0,
        shadowShift: (json['shadow_shift'] as num?)?.toDouble() ?? 0.0,
        midtoneContrast: (json['midtone_contrast'] as num?)?.toDouble() ?? 1.0,
        highlightRolloff: (json['highlight_rolloff'] as num?)?.toDouble() ?? 1.0,
        blackPoint: (json['black_point'] as num?)?.toDouble() ?? 0.0,
        whitePoint: (json['white_point'] as num?)?.toDouble() ?? 1.0,
        targetSkinHue: (json['target_skin_hue'] as num?)?.toDouble() ?? 27.5,
        targetSkinSat: (json['target_skin_sat'] as num?)?.toDouble() ?? 0.25,
        targetSkinLum: (json['target_skin_lum'] as num?)?.toDouble() ?? 0.62,
        skinHueShift: (json['skin_hue_shift'] as num?)?.toDouble() ?? 0.0,
        skinSatRatio: (json['skin_sat_ratio'] as num?)?.toDouble() ?? 1.0,
        skinLumRatio: (json['skin_lum_ratio'] as num?)?.toDouble() ?? 1.0,
        targetRedHue: (json['target_red_hue'] as num?)?.toDouble() ?? 356.0,
        targetRedSat: (json['target_red_sat'] as num?)?.toDouble() ?? 0.75,
        targetRedLum: (json['target_red_lum'] as num?)?.toDouble() ?? 0.45,
        targetGreenHue: (json['target_green_hue'] as num?)?.toDouble() ?? 70.0,
        targetGreenSat: (json['target_green_sat'] as num?)?.toDouble() ?? 0.25,
        targetGreenLum: (json['target_green_lum'] as num?)?.toDouble() ?? 0.35,
        lut3D: (json['lut_3d'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
        confidenceGrid: (json['confidence_grid'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
        globalAffineMatrix: (json['global_affine_matrix'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
        globalOffset: (json['global_offset'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [0.0, 0.0, 0.0],
        dominantHueAnchors: (json['dominant_hue_anchors'] as List?)?.map((e) => DynamicHueAnchor.fromJson(Map<String, dynamic>.from(e as Map))).toList() ?? [],
        validationMetrics: json['validation_metrics'] != null ? ValidationMetrics.fromJson(Map<String, dynamic>.from(json['validation_metrics'] as Map)) : null,
        method: json['method'] as String? ?? '3d_hybrid_confidence_reference_lut',
      );

  Map<String, dynamic> toJson() => {
        'src_l_mean': srcLMean,
        'src_l_std': srcLStd,
        'src_a_mean': srcAMean,
        'src_a_std': srcAStd,
        'src_b_mean': srcBMean,
        'src_b_std': srcBStd,
        'dst_l_mean': dstLMean,
        'dst_l_std': dstLStd,
        'dst_a_mean': dstAMean,
        'dst_a_std': dstAStd,
        'dst_b_mean': dstBMean,
        'dst_b_std': dstBStd,
        'hsl_hue_shifts': hslHueShifts,
        'hsl_sat_ratios': hslSatRatios,
        'hsl_lum_ratios': hslLumRatios,
        'tone_curve': toneCurve,
        'ref_median_lum': refMedianLum,
        'ref_dynamic_range': refDynamicRange,
        'shadow_shift': shadowShift,
        'midtone_contrast': midtoneContrast,
        'highlight_rolloff': highlightRolloff,
        'black_point': blackPoint,
        'white_point': whitePoint,
        'target_skin_hue': targetSkinHue,
        'target_skin_sat': targetSkinSat,
        'target_skin_lum': targetSkinLum,
        'skin_hue_shift': skinHueShift,
        'skin_sat_ratio': skinSatRatio,
        'skin_lum_ratio': skinLumRatio,
        'target_red_hue': targetRedHue,
        'target_red_sat': targetRedSat,
        'target_red_lum': targetRedLum,
        'target_green_hue': targetGreenHue,
        'target_green_sat': targetGreenSat,
        'target_green_lum': targetGreenLum,
        'lut_3d': lut3D,
        'confidence_grid': confidenceGrid,
        'global_affine_matrix': globalAffineMatrix,
        'global_offset': globalOffset,
        'dominant_hue_anchors': dominantHueAnchors.map((e) => e.toJson()).toList(),
        'validation_metrics': validationMetrics?.toJson(),
        'method': method,
      };

  double get brightnessShift => dstLMean - srcLMean;
  double get warmthShift => (dstBMean - srcBMean) - (dstAMean - srcAMean);
  double get contrastRatio => srcLStd > 0 ? dstLStd / srcLStd : 1.0;
}

class GradedImage {
  final String originalPath;
  final String outputPath;
  final String fileName;
  final int fileSizeBytes;
  final ExportFormat format;

  const GradedImage({
    required this.originalPath,
    required this.outputPath,
    required this.fileName,
    required this.fileSizeBytes,
    this.format = ExportFormat.jpeg,
  });
}

class ColorGradeItem {
  final String sourcePath;
  final String? outputPath;
  final ColorGradeItemStatus status;
  final String? errorMessage;
  final bool isRaw;
  final double? confidence;

  const ColorGradeItem({
    required this.sourcePath,
    this.outputPath,
    this.status = ColorGradeItemStatus.pending,
    this.errorMessage,
    this.isRaw = false,
    this.confidence,
  });

  String get fileName => sourcePath.split(RegExp(r'[/\\]')).last;
  String get extension => fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  bool get isSuccess => status == ColorGradeItemStatus.completed;

  static bool checkIsRaw(String ext) {
    const rawExts = {'cr2', 'cr3', 'nef', 'arw', 'dng', 'raf', 'rw2', 'orf', 'tif', 'tiff'};
    return rawExts.contains(ext.toLowerCase());
  }

  ColorGradeItem copyWith({
    String? outputPath,
    ColorGradeItemStatus? status,
    String? errorMessage,
    double? confidence,
  }) =>
      ColorGradeItem(
        sourcePath: sourcePath,
        outputPath: outputPath ?? this.outputPath,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        isRaw: isRaw,
        confidence: confidence ?? this.confidence,
      );
}

// Backward-compatible alias for existing tests
typedef BatchItem = ColorGradeItem;

@immutable
class ColorGradeState {
  final ColorGradeStatus status;
  final String? referenceRawPath;
  final String? referenceGradedPath;
  final GradeProfile? profile;
  final List<ColorGradeItem> batchItems;
  final ExportFormat exportFormat;
  final int jpegQuality;
  final int processedCount;
  final int totalCount;
  final String? currentProcessingFile;
  final List<GradedImage> outputs;
  final String? error;

  const ColorGradeState({
    this.status = ColorGradeStatus.idle,
    this.referenceRawPath,
    this.referenceGradedPath,
    this.profile,
    this.batchItems = const [],
    this.exportFormat = ExportFormat.jpeg,
    this.jpegQuality = 95,
    this.processedCount = 0,
    this.totalCount = 0,
    this.currentProcessingFile,
    this.outputs = const [],
    this.error,
  });

  GradeProfile? get learnedProfile => profile;
  List<String> get inputPaths => batchItems.map((e) => e.sourcePath).toList();

  ColorGradeState copyWith({
    ColorGradeStatus? status,
    String? referenceRawPath,
    String? referenceGradedPath,
    GradeProfile? profile,
    List<ColorGradeItem>? batchItems,
    ExportFormat? exportFormat,
    int? jpegQuality,
    int? processedCount,
    int? totalCount,
    String? currentProcessingFile,
    List<GradedImage>? outputs,
    String? error,
  }) =>
      ColorGradeState(
        status: status ?? this.status,
        referenceRawPath: referenceRawPath ?? this.referenceRawPath,
        referenceGradedPath: referenceGradedPath ?? this.referenceGradedPath,
        profile: profile ?? this.profile,
        batchItems: batchItems ?? this.batchItems,
        exportFormat: exportFormat ?? this.exportFormat,
        jpegQuality: jpegQuality ?? this.jpegQuality,
        processedCount: processedCount ?? this.processedCount,
        totalCount: totalCount ?? this.totalCount,
        currentProcessingFile: currentProcessingFile ?? this.currentProcessingFile,
        outputs: outputs ?? this.outputs,
        error: error ?? this.error,
      );

  bool get hasReferencePair => referenceRawPath != null && referenceGradedPath != null;
  bool get hasBatchImages => batchItems.isNotEmpty;
  double get batchProgress => totalCount > 0 ? processedCount / totalCount : 0.0;
}
