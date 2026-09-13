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

/// Learned reference grade matching profile.
/// Incorporates 3D Color LUT, 8-band HSL transformations, 3-zone tone curve, and skin protection.
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

  // 8-Band HSL Shifts: 8 elements each for [Red, Orange, Yellow, Green, Cyan, Blue, Purple, Magenta]
  final List<double> hslHueShifts;
  final List<double> hslSatRatios;
  final List<double> hslLumRatios;

  // 3-Zone Tonal Curve & Rolloff
  final double shadowShift;
  final double midtoneContrast;
  final double highlightRolloff;
  final double blackPoint;
  final double whitePoint;

  // Skin Protection target
  final double skinHueShift;
  final double skinSatRatio;
  final double skinLumRatio;

  // 3D Color LUT Grid (17x17x17 x 3 = 14,739 entries)
  final List<double> lut3D;

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
    required this.shadowShift,
    required this.midtoneContrast,
    required this.highlightRolloff,
    required this.blackPoint,
    required this.whitePoint,
    required this.skinHueShift,
    required this.skinSatRatio,
    required this.skinLumRatio,
    required this.lut3D,
    this.method = '3d_lut_hsl_8band_matching',
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
        shadowShift: (json['shadow_shift'] as num?)?.toDouble() ?? 0.0,
        midtoneContrast: (json['midtone_contrast'] as num?)?.toDouble() ?? 1.0,
        highlightRolloff: (json['highlight_rolloff'] as num?)?.toDouble() ?? 1.0,
        blackPoint: (json['black_point'] as num?)?.toDouble() ?? 0.0,
        whitePoint: (json['white_point'] as num?)?.toDouble() ?? 1.0,
        skinHueShift: (json['skin_hue_shift'] as num?)?.toDouble() ?? 0.0,
        skinSatRatio: (json['skin_sat_ratio'] as num?)?.toDouble() ?? 1.0,
        skinLumRatio: (json['skin_lum_ratio'] as num?)?.toDouble() ?? 1.0,
        lut3D: (json['lut_3d'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
        method: json['method'] as String? ?? '3d_lut_hsl_8band_matching',
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
        'shadow_shift': shadowShift,
        'midtone_contrast': midtoneContrast,
        'highlight_rolloff': highlightRolloff,
        'black_point': blackPoint,
        'white_point': whitePoint,
        'skin_hue_shift': skinHueShift,
        'skin_sat_ratio': skinSatRatio,
        'skin_lum_ratio': skinLumRatio,
        'lut_3d': lut3D,
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

  const ColorGradeItem({
    required this.sourcePath,
    this.outputPath,
    this.status = ColorGradeItemStatus.pending,
    this.errorMessage,
    this.isRaw = false,
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
  }) =>
      ColorGradeItem(
        sourcePath: sourcePath,
        outputPath: outputPath ?? this.outputPath,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        isRaw: isRaw,
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
