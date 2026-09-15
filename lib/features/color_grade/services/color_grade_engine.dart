import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/color_grade_models.dart';

/// Exception thrown for specific file validation errors
class FileValidationError implements Exception {
  final String message;
  final String filePath;
  FileValidationError(this.message, this.filePath);

  @override
  String toString() => message;
}

class ColorGradeEngine {
  ColorGradeEngine._();
  static final ColorGradeEngine instance = ColorGradeEngine._();

  // Supported Extensions
  static const Set<String> supportedExtensions = {
    'jpg', 'jpeg', 'cr2', 'cr3', 'nef', 'arw', 'dng', 'raf', 'rw2', 'orf', 'png', 'webp', 'tif', 'tiff'
  };

  // ── 1. File Validation & Magic Signature Check ──────────────────────────────

  /// Validates file integrity, extension, size, permissions, and magic headers
  Future<void> validateFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileValidationError('File does not exist', filePath);
    }

    final length = await file.length();
    if (length == 0) {
      throw FileValidationError('File is empty (0 bytes)', filePath);
    }

    final ext = filePath.split('.').last.toLowerCase();
    if (!supportedExtensions.contains(ext)) {
      throw FileValidationError('Unsupported image format (.$ext)', filePath);
    }

    final bytes = await file.openRead(0, math.min<int>(16, length)).first;
    if (bytes.length < 4) {
      throw FileValidationError('Invalid image header', filePath);
    }

    final isValidHeader = _checkMagicHeader(bytes, ext);
    if (!isValidHeader) {
      throw FileValidationError('File contents appear corrupted or invalid', filePath);
    }
  }

  bool _checkMagicHeader(List<int> bytes, String ext) {
    if (ext == 'jpg' || ext == 'jpeg') {
      return bytes[0] == 0xFF && bytes[1] == 0xD8;
    }
    if (ext == 'png') {
      return bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
    }
    // Little-endian TIFF / RAW (II*\0)
    if (bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) return true;
    // Big-endian TIFF / RAW (MM\0*)
    if (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A) return true;
    // CR2 RAW (II R\0)
    if (bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x52 && bytes[3] == 0x00) return true;
    // RIFF / WEBP
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return true;
    // ISO base media file format (MP4/CR3/HEIC/HEIF)
    if (bytes.length >= 8 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) return true;

    return true;
  }

  // ── 2. RAW Preview Extraction ───────────────────────────────────────────────

  static Uint8List extractDecodableBytes(Uint8List rawFileBytes, String ext) {
    final lowerExt = ext.toLowerCase();
    // Only proprietary camera RAW formats need embedded JPEG preview extraction
    const proprietaryRaws = {'cr2', 'cr3', 'nef', 'arw', 'raf', 'rw2', 'orf'};
    if (!proprietaryRaws.contains(lowerExt)) {
      return rawFileBytes;
    }

    int bestStart = -1;
    int bestLength = -1;
    final len = rawFileBytes.length;

    for (int i = 0; i < len - 4; i++) {
      if (rawFileBytes[i] == 0xFF && rawFileBytes[i + 1] == 0xD8) {
        // Look ahead for the EOI marker (0xFF, 0xD9)
        for (int j = i + 2; j < len - 1; j++) {
          if (rawFileBytes[j] == 0xFF && rawFileBytes[j + 1] == 0xD9) {
            final length = (j + 2) - i;
            if (length > bestLength) {
              bestStart = i;
              bestLength = length;
            }
            // Check next bytes or continue searching for largest valid stream
            break;
          }
        }
      }
    }

    if (bestStart != -1 && bestLength > 5000) {
      debugPrint('[COLOR_GRADE] Extracted embedded JPEG preview from $ext RAW file ($bestLength bytes)');
      return rawFileBytes.sublist(bestStart, bestStart + bestLength);
    }

    return rawFileBytes;
  }

  // ── 3. Image Decoding & Downsampling (Isolate Safe) ─────────────────────────

  Future<img.Image> decodeAndDownsample(String filePath, {int maxDimension = 512}) async {
    await validateFile(filePath);

    return Isolate.run(() async {
      final rawFile = File(filePath);
      final rawBytes = await rawFile.readAsBytes();
      final ext = filePath.split('.').last;
      final decodableBytes = extractDecodableBytes(rawBytes, ext);

      img.Image? decoded = img.decodeImage(decodableBytes);
      if (decoded == null && decodableBytes != rawBytes) {
        decoded = img.decodeImage(rawBytes);
      }

      if (decoded == null) {
        throw FileValidationError('Failed to decode image data from $ext file', filePath);
      }

      if (decoded.width <= 0 || decoded.height <= 0) {
        throw FileValidationError('Invalid image dimensions (${decoded.width}x${decoded.height})', filePath);
      }

      if (decoded.width <= maxDimension && decoded.height <= maxDimension) {
        return decoded;
      }

      if (decoded.width >= decoded.height) {
        return img.copyResize(decoded, width: maxDimension);
      } else {
        return img.copyResize(decoded, height: maxDimension);
      }
    });
  }

  // ── 4. Color Space & Linearization Utilities ──────────────────────────────

  /// Converts sRGB [0..1] to Linear RGB [0..1]
  static double srgbToLinear(double c) {
    final clamped = c.clamp(0.0, 1.0);
    return clamped <= 0.04045 ? clamped / 12.92 : math.pow((clamped + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Converts Linear RGB [0..1] to sRGB [0..1]
  static double linearToSrgb(double c) {
    final clamped = c.clamp(0.0, 1.0);
    return clamped <= 0.0031308 ? clamped * 12.92 : 1.055 * math.pow(clamped, 1.0 / 2.4).toDouble() - 0.055;
  }

  /// Converts RGB [0..1] to HSL [h: 0..360, s: 0..1, l: 0..1]
  List<double> rgbToHsl(double r, double g, double b) {
    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    double h = 0.0;
    double s = 0.0;
    final l = (max + min) / 2.0;

    if (max != min) {
      final d = max - min;
      s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min);
      if (max == r) {
        h = (g - b) / d + (g < b ? 6 : 0);
      } else if (max == g) {
        h = (b - r) / d + 2;
      } else {
        h = (r - g) / d + 4;
      }
      h /= 6.0;
    }
    return [h * 360.0, s, l];
  }

  /// Converts HSL [h: 0..360, s: 0..1, l: 0..1] to RGB [0..1]
  List<double> hslToRgb(double h, double s, double l) {
    if (s == 0) {
      return [l, l, l];
    }

    double hue2rgb(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    final hn = (h % 360.0) / 360.0;
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;

    final r = hue2rgb(p, q, hn + 1 / 3);
    final g = hue2rgb(p, q, hn);
    final b = hue2rgb(p, q, hn - 1 / 3);

    return [r.clamp(0.0, 1.0), g.clamp(0.0, 1.0), b.clamp(0.0, 1.0)];
  }

  /// Classifies Hue angle [0..360] into 1 of 8 HSL color bands
  int getHslBand(double h) {
    final normH = (h % 360.0 + 360.0) % 360.0;
    if (normH >= 345 || normH < 15) return 0; // Red
    if (normH >= 15 && normH < 45) return 1; // Orange / Skin
    if (normH >= 45 && normH < 75) return 2; // Yellow
    if (normH >= 75 && normH < 165) return 3; // Green
    if (normH >= 165 && normH < 195) return 4; // Cyan
    if (normH >= 195 && normH < 255) return 5; // Blue
    if (normH >= 255 && normH < 315) return 6; // Purple
    return 7; // Magenta
  }

  // ── 5. Color Space Conversion (sRGB -> CIE L*a*b*) & Metrics ──────────────

  List<double> rgbToLabPoint(double r, double g, double b) {
    final rl = srgbToLinear(r);
    final gl = srgbToLinear(g);
    final bl = srgbToLinear(b);

    final x = (rl * 0.4124564 + gl * 0.3575761 + bl * 0.1804375) / 0.95047;
    final y = (rl * 0.2126729 + gl * 0.7151522 + bl * 0.0721750) / 1.00000;
    final z = (rl * 0.0193339 + gl * 0.1191920 + bl * 0.9503041) / 1.08883;

    final fx = x > 0.008856 ? math.pow(x, 1 / 3).toDouble() : (7.787 * x) + (16 / 116);
    final fy = y > 0.008856 ? math.pow(y, 1 / 3).toDouble() : (7.787 * y) + (16 / 116);
    final fz = z > 0.008856 ? math.pow(z, 1 / 3).toDouble() : (7.787 * z) + (16 / 116);

    return [(116 * fy) - 16, 500 * (fx - fy), 200 * (fy - fz)];
  }

  Map<String, Float64List> imageToLab(img.Image image) {
    final width = image.width;
    final height = image.height;
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Invalid image dimensions: ${width}x$height');
    }
    final count = width * height;

    final lChan = Float64List(count);
    final aChan = Float64List(count);
    final bChan = Float64List(count);

    int idx = 0;
    for (final pixel in image) {
      if (idx >= count) break;
      final lab = rgbToLabPoint(pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0);
      lChan[idx] = lab[0];
      aChan[idx] = lab[1];
      bChan[idx] = lab[2];
      idx++;
    }

    return {'L': lChan, 'a': aChan, 'b': bChan};
  }

  Map<String, double> _computeStats(Float64List data) {
    if (data.isEmpty) return {'mean': 0.0, 'std': 1.0};
    double sum = 0.0;
    for (int i = 0; i < data.length; i++) {
      sum += data[i];
    }
    final mean = sum / data.length;

    double varianceSum = 0.0;
    for (int i = 0; i < data.length; i++) {
      final diff = data[i] - mean;
      varianceSum += diff * diff;
    }
    final std = math.sqrt(varianceSum / data.length);

    return {'mean': mean, 'std': math.max(std, 1e-5)};
  }

  /// Solves a 4x4 linear system via Gaussian elimination with partial pivoting
  static List<double>? solve4x4(List<List<double>> A, List<double> b) {
    final M = List.generate(4, (i) => List<double>.from(A[i])..add(b[i]));
    for (int i = 0; i < 4; i++) {
      int pivot = i;
      for (int j = i + 1; j < 4; j++) {
        if (M[j][i].abs() > M[pivot][i].abs()) pivot = j;
      }
      if (pivot != i) {
        final temp = M[i];
        M[i] = M[pivot];
        M[pivot] = temp;
      }
      if (M[i][i].abs() < 1e-12) return null;
      for (int j = i + 1; j < 4; j++) {
        final factor = M[j][i] / M[i][i];
        for (int k = i; k <= 4; k++) {
          M[j][k] -= factor * M[i][k];
        }
      }
    }
    final x = List<double>.filled(4, 0.0);
    for (int i = 3; i >= 0; i--) {
      double sum = M[i][4];
      for (int j = i + 1; j < 4; j++) {
        sum -= M[i][j] * x[j];
      }
      x[i] = sum / M[i][i];
    }
    return x;
  }

  /// Standard CIEDE2000 Color Difference Formula
  static double ciede2000(double l1, double a1, double b1, double l2, double a2, double b2) {
    const kL = 1.0;
    const kC = 1.0;
    const kH = 1.0;

    final c1 = math.sqrt(a1 * a1 + b1 * b1);
    final c2 = math.sqrt(a2 * a2 + b2 * b2);
    final cBar = (c1 + c2) / 2.0;

    final g = 0.5 * (1.0 - math.sqrt(math.pow(cBar, 7) / (math.pow(cBar, 7) + math.pow(25.0, 7))));
    final a1Prime = (1.0 + g) * a1;
    final a2Prime = (1.0 + g) * a2;

    final c1Prime = math.sqrt(a1Prime * a1Prime + b1 * b1);
    final c2Prime = math.sqrt(a2Prime * a2Prime + b2 * b2);

    double h1Prime = math.atan2(b1, a1Prime) * 180.0 / math.pi;
    if (h1Prime < 0) h1Prime += 360.0;
    double h2Prime = math.atan2(b2, a2Prime) * 180.0 / math.pi;
    if (h2Prime < 0) h2Prime += 360.0;

    final deltaLPrime = l2 - l1;
    final deltaCPrime = c2Prime - c1Prime;

    double deltaHPrime = 0.0;
    if (c1Prime * c2Prime != 0) {
      final dh = h2Prime - h1Prime;
      if (dh.abs() <= 180.0) {
        deltaHPrime = dh;
      } else if (dh > 180.0) {
        deltaHPrime = dh - 360.0;
      } else {
        deltaHPrime = dh + 360.0;
      }
    }
    final deltaBigHPrime = 2.0 * math.sqrt(c1Prime * c2Prime) * math.sin((deltaHPrime * math.pi / 180.0) / 2.0);

    final lBarPrime = (l1 + l2) / 2.0;
    final cBarPrime = (c1Prime + c2Prime) / 2.0;

    double hBarPrime = (h1Prime + h2Prime) / 2.0;
    if (c1Prime * c2Prime != 0 && (h1Prime - h2Prime).abs() > 180.0) {
      if (h1Prime + h2Prime < 360.0) {
        hBarPrime += 180.0;
      } else {
        hBarPrime -= 180.0;
      }
    }

    final t = 1.0 - 0.17 * math.cos((hBarPrime - 30.0) * math.pi / 180.0)
        + 0.24 * math.cos((2.0 * hBarPrime) * math.pi / 180.0)
        + 0.32 * math.cos((3.0 * hBarPrime + 6.0) * math.pi / 180.0)
        - 0.20 * math.cos((4.0 * hBarPrime - 63.0) * math.pi / 180.0);

    final sL = 1.0 + (0.015 * math.pow(lBarPrime - 50.0, 2)) / math.sqrt(20.0 + math.pow(lBarPrime - 50.0, 2));
    final sC = 1.0 + 0.045 * cBarPrime;
    final sH = 1.0 + 0.015 * cBarPrime * t;

    final deltaTheta = 30.0 * math.exp(-math.pow((hBarPrime - 275.0) / 25.0, 2));
    final rC = 2.0 * math.sqrt(math.pow(cBarPrime, 7) / (math.pow(cBarPrime, 7) + math.pow(25.0, 7)));
    final rT = -math.sin(2.0 * deltaTheta * math.pi / 180.0) * rC;

    final vL = deltaLPrime / (kL * sL);
    final vC = deltaCPrime / (kC * sC);
    final vH = deltaBigHPrime / (kH * sH);

    return math.sqrt(vL * vL + vC * vC + vH * vH + rT * vC * vH);
  }

  /// Computes SSIM (Structural Similarity Index) on image luminance
  static double computeSSIM(img.Image img1, img.Image img2) {
    final w = math.min(img1.width, img2.width);
    final h = math.min(img1.height, img2.height);
    const c1 = 6.5025; // (0.01 * 255)^2
    const c2 = 58.5225; // (0.03 * 255)^2

    double mean1 = 0.0, mean2 = 0.0;
    final count = (w * h).toDouble();

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p1 = img1.getPixel(x, y);
        final p2 = img2.getPixel(x, y);
        final l1 = 0.2126 * p1.r + 0.7152 * p1.g + 0.0722 * p1.b;
        final l2 = 0.2126 * p2.r + 0.7152 * p2.g + 0.0722 * p2.b;
        mean1 += l1;
        mean2 += l2;
      }
    }
    mean1 /= count;
    mean2 /= count;

    double var1 = 0.0, var2 = 0.0, covar = 0.0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p1 = img1.getPixel(x, y);
        final p2 = img2.getPixel(x, y);
        final l1 = 0.2126 * p1.r + 0.7152 * p1.g + 0.0722 * p1.b;
        final l2 = 0.2126 * p2.r + 0.7152 * p2.g + 0.0722 * p2.b;
        final d1 = l1 - mean1;
        final d2 = l2 - mean2;
        var1 += d1 * d1;
        var2 += d2 * d2;
        covar += d1 * d2;
      }
    }
    var1 /= count;
    var2 /= count;
    covar /= count;

    final num = (2.0 * mean1 * mean2 + c1) * (2.0 * covar + c2);
    final den = (mean1 * mean1 + mean2 * mean2 + c1) * (var1 + var2 + c2);
    return (num / den).clamp(0.0, 1.0);
  }

  // 4x4 Bayer ordered dither matrix
  static const List<List<int>> _bayer4x4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
  ];

  static double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  // ── 6. Advanced Reference Grade Learning (Hybrid 3D LUT + Global Affine) ────

  Future<GradeProfile> analyzeReferencePair({
    required img.Image refOriginal,
    required img.Image refGraded,
  }) async {
    return Isolate.run(() {
      final sampleWidth = math.min(math.min(refOriginal.width, refGraded.width), 1024);
      final sampleHeight = math.min(math.min(refOriginal.height, refGraded.height), 1024);
      final origResized = (refOriginal.width == sampleWidth && refOriginal.height == sampleHeight)
          ? refOriginal
          : img.copyResize(refOriginal, width: sampleWidth, height: sampleHeight);
      final gradResized = (refGraded.width == sampleWidth && refGraded.height == sampleHeight)
          ? refGraded
          : img.copyResize(refGraded, width: sampleWidth, height: sampleHeight);

      final totalPixels = sampleWidth * sampleHeight;

      // ── 1. Least-Squares Linear Affine Fit in Linear RGB ─────────────────────
      final ata = List.generate(4, (_) => List<double>.filled(4, 0.0));
      final atyR = List<double>.filled(4, 0.0);
      final atyG = List<double>.filled(4, 0.0);
      final atyB = List<double>.filled(4, 0.0);

      // ── 2. Extract Exact Per-Channel and Luminance Tone Transfer Curves ────────
      final binDstLumSum = Float64List(256);
      final binDstLumCount = Int32List(256);
      final binDstRSum = Float64List(256); final binDstRCount = Int32List(256);
      final binDstGSum = Float64List(256); final binDstGCount = Int32List(256);
      final binDstBSum = Float64List(256); final binDstBCount = Int32List(256);
      final srcLumList = Float64List(totalPixels);

      // ── 3. Dynamic Dominant Hue Clustering (24 bins) ─────────────────────────
      const numHueBins = 24;
      final hueBinCount = List<int>.filled(numHueBins, 0);
      final hueBinDeltaHSum = List<double>.filled(numHueBins, 0.0);
      final hueBinSrcSSum = List<double>.filled(numHueBins, 0.0);
      final hueBinDstSSum = List<double>.filled(numHueBins, 0.0);
      final hueBinSrcLSum = List<double>.filled(numHueBins, 0.0);
      final hueBinDstLSum = List<double>.filled(numHueBins, 0.0);

      // 8-Band Fallback HSL
      final bandSrcCount = List<int>.filled(8, 0);
      final bandHueDeltas = List<double>.filled(8, 0.0);
      final bandSrcSatSum = List<double>.filled(8, 0.0);
      final bandDstSatSum = List<double>.filled(8, 0.0);
      final bandSrcLumSum = List<double>.filled(8, 0.0);
      final bandDstLumSum = List<double>.filled(8, 0.0);

      double skinDstHueSum = 0.0, skinDstSatSum = 0.0, skinDstLumSum = 0.0; int skinDstCount = 0;
      double redDstHueSum = 0.0, redDstSatSum = 0.0, redDstLumSum = 0.0; int redDstCount = 0;
      double greenDstHueSum = 0.0, greenDstSatSum = 0.0, greenDstLumSum = 0.0; int greenDstCount = 0;

      // 3D LUT Accumulators (49x49x49 for fine color transition capture)
      const lutSize = 49;
      final gridRSum = Float64List(lutSize * lutSize * lutSize);
      final gridGSum = Float64List(lutSize * lutSize * lutSize);
      final gridBSum = Float64List(lutSize * lutSize * lutSize);
      final gridWeight = Float64List(lutSize * lutSize * lutSize);

      int pIdx = 0;
      for (int y = 0; y < sampleHeight; y++) {
        for (int x = 0; x < sampleWidth; x++) {
          final pSrc = origResized.getPixel(x, y);
          final pDst = gradResized.getPixel(x, y);

          final rIn = pSrc.r / 255.0; final gIn = pSrc.g / 255.0; final bIn = pSrc.b / 255.0;
          final rOut = pDst.r / 255.0; final gOut = pDst.g / 255.0; final bOut = pDst.b / 255.0;

          final rInLin = srgbToLinear(rIn); final gInLin = srgbToLinear(gIn); final bInLin = srgbToLinear(bIn);
          final rOutLin = srgbToLinear(rOut); final gOutLin = srgbToLinear(gOut); final bOutLin = srgbToLinear(bOut);

          // Linear Regression Normal Equations
          final u = [rInLin, gInLin, bInLin, 1.0];
          for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
              ata[i][j] += u[i] * u[j];
            }
            atyR[i] += u[i] * rOutLin;
            atyG[i] += u[i] * gOutLin;
            atyB[i] += u[i] * bOutLin;
          }

          // Tone Curves
          final lSrc = (0.2126 * pSrc.r + 0.7152 * pSrc.g + 0.0722 * pSrc.b) / 255.0;
          final lDst = (0.2126 * pDst.r + 0.7152 * pDst.g + 0.0722 * pDst.b) / 255.0;
          srcLumList[pIdx++] = lSrc;

          final binL = (lSrc * 255.0).round().clamp(0, 255);
          binDstLumSum[binL] += lDst;
          binDstLumCount[binL]++;

          final binR = pSrc.r.toInt().clamp(0, 255);
          binDstRSum[binR] += rOut;
          binDstRCount[binR]++;

          final binG = pSrc.g.toInt().clamp(0, 255);
          binDstGSum[binG] += gOut;
          binDstGCount[binG]++;

          final binB = pSrc.b.toInt().clamp(0, 255);
          binDstBSum[binB] += bOut;
          binDstBCount[binB]++;

          // 3D LUT Cells
          final rCell = (rIn * (lutSize - 1)).round().clamp(0, lutSize - 1);
          final gCell = (gIn * (lutSize - 1)).round().clamp(0, lutSize - 1);
          final bCell = (bIn * (lutSize - 1)).round().clamp(0, lutSize - 1);
          final cIdx = rCell * lutSize * lutSize + gCell * lutSize + bCell;
          gridRSum[cIdx] += rOut;
          gridGSum[cIdx] += gOut;
          gridBSum[cIdx] += bOut;
          gridWeight[cIdx] += 1.0;

          // HSL Dynamic & Fallback analysis
          final hslSrc = ColorGradeEngine.instance.rgbToHsl(rIn, gIn, bIn);
          final hslDst = ColorGradeEngine.instance.rgbToHsl(rOut, gOut, bOut);

          if (hslSrc[1] >= 0.08) {
            final binIdx = ((hslSrc[0] / (360.0 / numHueBins)).floor()) % numHueBins;
            hueBinCount[binIdx]++;
            double dh = hslDst[0] - hslSrc[0];
            if (dh > 180) dh -= 360;
            if (dh < -180) dh += 360;
            hueBinDeltaHSum[binIdx] += dh;
            hueBinSrcSSum[binIdx] += hslSrc[1];
            hueBinDstSSum[binIdx] += hslDst[1];
            hueBinSrcLSum[binIdx] += hslSrc[2];
            hueBinDstLSum[binIdx] += hslDst[2];
          }

          final band = ColorGradeEngine.instance.getHslBand(hslSrc[0]);
          bandSrcCount[band]++;
          double hDiff = hslDst[0] - hslSrc[0];
          if (hDiff > 180) hDiff -= 360;
          if (hDiff < -180) hDiff += 360;
          bandHueDeltas[band] += hDiff;
          bandSrcSatSum[band] += hslSrc[1];
          bandDstSatSum[band] += hslDst[1];
          bandSrcLumSum[band] += hslSrc[2];
          bandDstLumSum[band] += hslDst[2];

          // Graded Skin Anchor
          if (hslDst[0] >= 15 && hslDst[0] <= 45 && hslDst[1] >= 0.12 && hslDst[1] <= 0.60 && hslDst[2] >= 0.30 && hslDst[2] <= 0.85) {
            skinDstHueSum += hslDst[0];
            skinDstSatSum += hslDst[1];
            skinDstLumSum += hslDst[2];
            skinDstCount++;
          }

          // Graded Red Lehenga/Attire
          if ((hslDst[0] >= 335 || hslDst[0] <= 15) && hslDst[1] >= 0.30) {
            double hRed = hslDst[0];
            if (hRed > 180) hRed -= 360;
            redDstHueSum += hRed;
            redDstSatSum += hslDst[1];
            redDstLumSum += hslDst[2];
            redDstCount++;
          }

          // Foliage / Green Vegetation
          if (hslDst[0] >= 65 && hslDst[0] <= 160 && hslDst[1] >= 0.05) {
            greenDstHueSum += hslDst[0];
            greenDstSatSum += hslDst[1];
            greenDstLumSum += hslDst[2];
            greenDstCount++;
          }
        }
      }

      // Solve Global Affine Model with slight ridge regularization
      for (int i = 0; i < 4; i++) {
        ata[i][i] += 1e-4 * totalPixels;
      }
      final wR = solve4x4(ata, atyR) ?? [1.0, 0.0, 0.0, 0.0];
      final wG = solve4x4(ata, atyG) ?? [0.0, 1.0, 0.0, 0.0];
      final wB = solve4x4(ata, atyB) ?? [0.0, 0.0, 1.0, 0.0];

      final globalAffineMatrix = [
        wR[0], wR[1], wR[2],
        wG[0], wG[1], wG[2],
        wB[0], wB[1], wB[2],
      ];
      final globalOffset = [wR[3], wG[3], wB[3]];

      // Smooth Tone Curves
      List<double> buildSmoothCurve(Float64List sums, Int32List counts) {
        final raw = List<double>.filled(256, 0.0);
        int lastObs = 0;
        double lastVal = 0.0;
        for (int i = 0; i < 256; i++) {
          if (counts[i] > 0) {
            raw[i] = (sums[i] / counts[i]).clamp(0.0, 1.0);
            if (i > lastObs + 1) {
              final sV = raw[lastObs];
              final eV = raw[i];
              for (int k = lastObs + 1; k < i; k++) {
                final t = (k - lastObs) / (i - lastObs);
                raw[k] = sV * (1.0 - t) + eV * t;
              }
            }
            lastObs = i;
            lastVal = raw[i];
          } else if (i == 0) {
            raw[i] = 0.0;
          } else {
            raw[i] = lastVal;
          }
        }
        for (int i = lastObs + 1; i < 256; i++) {
          raw[i] = lastVal;
        }

        final smooth = List<double>.filled(256, 0.0);
        for (int i = 0; i < 256; i++) {
          double sum = 0.0, wSum = 0.0;
          for (int offset = -2; offset <= 2; offset++) {
            final idx = (i + offset).clamp(0, 255);
            final w = math.exp(-(offset * offset) / (2 * 1.2 * 1.2));
            sum += raw[idx] * w;
            wSum += w;
          }
          smooth[i] = (sum / wSum).clamp(0.0, 1.0);
        }
        return smooth;
      }

      final toneCurve = buildSmoothCurve(binDstLumSum, binDstLumCount);
      final rCurve = buildSmoothCurve(binDstRSum, binDstRCount);
      final gCurve = buildSmoothCurve(binDstGSum, binDstGCount);
      final bCurve = buildSmoothCurve(binDstBSum, binDstBCount);

      srcLumList.sort();
      final refMedianLum = srcLumList[(totalPixels * 0.50).toInt()].clamp(0.05, 0.95);
      final refP05 = srcLumList[(totalPixels * 0.05).toInt()];
      final refP95 = srcLumList[(totalPixels * 0.95).toInt()];
      final refDynamicRange = math.max(refP95 - refP05, 0.1);

      // Extract Dominant Dynamic Hue Anchors (top 3-5)
      final totalSaturated = hueBinCount.reduce((a, b) => a + b);
      final dominantAnchors = <DynamicHueAnchor>[];
      final sortedBins = List.generate(numHueBins, (i) => i)..sort((a, b) => hueBinCount[b].compareTo(hueBinCount[a]));

      for (final bIdx in sortedBins) {
        final count = hueBinCount[bIdx];
        if (count > 0 && (count / math.max(1, totalSaturated)) >= 0.03 && dominantAnchors.length < 5) {
          final centerH = (bIdx + 0.5) * (360.0 / numHueBins);
          final avgDh = hueBinDeltaHSum[bIdx] / count;
          final srcS = hueBinSrcSSum[bIdx] / count; final dstS = hueBinDstSSum[bIdx] / count;
          final srcL = hueBinSrcLSum[bIdx] / count; final dstL = hueBinDstLSum[bIdx] / count;
          final sRatio = srcS > 1e-4 ? (dstS / srcS).clamp(0.4, 1.8) : 1.0;
          final lRatio = srcL > 1e-4 ? (dstL / srcL).clamp(0.6, 1.4) : 1.0;
          final weight = (count / totalSaturated).clamp(0.0, 1.0);

          dominantAnchors.add(DynamicHueAnchor(
            centerHue: centerH,
            hueShift: avgDh.clamp(-40.0, 40.0),
            satRatio: sRatio,
            lumRatio: lRatio,
            weight: weight,
          ));
        }
      }

      // Fallback anchors if empty
      if (dominantAnchors.isEmpty) {
        dominantAnchors.add(const DynamicHueAnchor(centerHue: 28.0, hueShift: 0.0, satRatio: 1.0, lumRatio: 1.0, weight: 1.0));
        dominantAnchors.add(const DynamicHueAnchor(centerHue: 357.6, hueShift: 0.0, satRatio: 1.0, lumRatio: 1.0, weight: 1.0));
      }

      // 8-Band Fallback HSL
      final hslHueShifts = List<double>.filled(8, 0.0);
      final hslSatRatios = List<double>.filled(8, 1.0);
      final hslLumRatios = List<double>.filled(8, 1.0);

      for (int b = 0; b < 8; b++) {
        final c = bandSrcCount[b];
        if (c > 0) {
          hslHueShifts[b] = (bandHueDeltas[b] / c).clamp(-45.0, 45.0);
          final avgSrcSat = bandSrcSatSum[b] / c;
          final avgDstSat = bandDstSatSum[b] / c;
          hslSatRatios[b] = avgSrcSat > 1e-4 ? (avgDstSat / avgSrcSat).clamp(0.2, 2.0) : 1.0;
          final avgSrcLum = bandSrcLumSum[b] / c;
          final avgDstLum = bandDstLumSum[b] / c;
          hslLumRatios[b] = avgSrcLum > 1e-4 ? (avgDstLum / avgSrcLum).clamp(0.5, 1.5) : 1.0;
        }
      }

      final targetSkinHue = skinDstCount > 0 ? (skinDstHueSum / skinDstCount).clamp(22.0, 32.0) : 28.0;
      final targetSkinSat = skinDstCount > 0 ? (skinDstSatSum / skinDstCount).clamp(0.16, 0.35) : 0.21;
      final targetSkinLum = skinDstCount > 0 ? (skinDstLumSum / skinDstCount).clamp(0.45, 0.72) : 0.58;

      double targetRedHue = 357.6;
      if (redDstCount > 0) {
        final avgH = redDstHueSum / redDstCount;
        targetRedHue = (avgH < 0 ? avgH + 360.0 : avgH).clamp(350.0, 360.0);
      }
      final targetRedSat = redDstCount > 0 ? (redDstSatSum / redDstCount).clamp(0.40, 0.95) : 0.46;
      final targetRedLum = redDstCount > 0 ? (redDstLumSum / redDstCount).clamp(0.35, 0.70) : 0.55;

      final targetGreenHue = greenDstCount > 0 ? (greenDstHueSum / greenDstCount).clamp(75.0, 100.0) : 86.6;
      final targetGreenSat = greenDstCount > 0 ? (greenDstSatSum / greenDstCount).clamp(0.04, 0.20) : 0.07;
      final targetGreenLum = greenDstCount > 0 ? (greenDstLumSum / greenDstCount).clamp(0.20, 0.50) : 0.34;

      // Build 49x49x49 3D LUT + Confidence Grid (sigma = 0.7 for optimal precision)
      final lut3D = List<double>.filled(lutSize * lutSize * lutSize * 3, 0.0);
      final confidenceGrid = List<double>.filled(lutSize * lutSize * lutSize, 0.0);

      const sigma = 0.7;
      const twoSigmaSq = 2.0 * sigma * sigma;

      for (int r = 0; r < lutSize; r++) {
        final rNorm = r / (lutSize - 1);
        final rBase = rCurve[(rNorm * 255.0).round().clamp(0, 255)];

        for (int g = 0; g < lutSize; g++) {
          final gNorm = g / (lutSize - 1);
          final gBase = gCurve[(gNorm * 255.0).round().clamp(0, 255)];

          for (int b = 0; b < lutSize; b++) {
            final bNorm = b / (lutSize - 1);
            final bBase = bCurve[(bNorm * 255.0).round().clamp(0, 255)];

            double wSum = 0.0, rAcc = 0.0, gAcc = 0.0, bAcc = 0.0;
            final minR = math.max(0, r - 3); final maxR = math.min(lutSize - 1, r + 3);
            final minG = math.max(0, g - 3); final maxG = math.min(lutSize - 1, g + 3);
            final minB = math.max(0, b - 3); final maxB = math.min(lutSize - 1, b + 3);

            for (int ri = minR; ri <= maxR; ri++) {
              final dr = ri - r;
              for (int gi = minG; gi <= maxG; gi++) {
                final dg = gi - g;
                for (int bi = minB; bi <= maxB; bi++) {
                  final db = bi - b;
                  final cIdx = ri * lutSize * lutSize + gi * lutSize + bi;
                  final count = gridWeight[cIdx];
                  if (count > 0) {
                    final distSq = (dr * dr + dg * dg + db * db).toDouble();
                    final w = math.exp(-distSq / twoSigmaSq) * count;
                    rAcc += (gridRSum[cIdx] / count) * w;
                    gAcc += (gridGSum[cIdx] / count) * w;
                    bAcc += (gridBSum[cIdx] / count) * w;
                    wSum += w;
                  }
                }
              }
            }

            final cellIdx = r * lutSize * lutSize + g * lutSize + b;
            final lutIdx = cellIdx * 3;
            final confidence = (1.0 - math.exp(-wSum / 8.0)).clamp(0.0, 1.0);
            confidenceGrid[cellIdx] = confidence;

            if (wSum > 0.01) {
              final rLearned = rAcc / wSum;
              final gLearned = gAcc / wSum;
              final bLearned = bAcc / wSum;

              final blendWeight = math.min(1.0, wSum / 4.0);
              lut3D[lutIdx] = (rLearned * blendWeight + rBase * (1.0 - blendWeight)).clamp(0.0, 1.0);
              lut3D[lutIdx + 1] = (gLearned * blendWeight + gBase * (1.0 - blendWeight)).clamp(0.0, 1.0);
              lut3D[lutIdx + 2] = (bLearned * blendWeight + bBase * (1.0 - blendWeight)).clamp(0.0, 1.0);
            } else {
              lut3D[lutIdx] = rBase.clamp(0.0, 1.0);
              lut3D[lutIdx + 1] = gBase.clamp(0.0, 1.0);
              lut3D[lutIdx + 2] = bBase.clamp(0.0, 1.0);
            }
          }
        }
      }

      final origLab = ColorGradeEngine.instance.imageToLab(origResized);
      final gradLab = ColorGradeEngine.instance.imageToLab(gradResized);
      final srcL = ColorGradeEngine.instance._computeStats(origLab['L']!);
      final srcA = ColorGradeEngine.instance._computeStats(origLab['a']!);
      final srcB = ColorGradeEngine.instance._computeStats(origLab['b']!);
      final dstL = ColorGradeEngine.instance._computeStats(gradLab['L']!);
      final dstA = ColorGradeEngine.instance._computeStats(gradLab['a']!);
      final dstB = ColorGradeEngine.instance._computeStats(gradLab['b']!);

      final preliminaryProfile = GradeProfile(
        srcLMean: srcL['mean']!,
        srcLStd: srcL['std']!,
        srcAMean: srcA['mean']!,
        srcAStd: srcA['std']!,
        srcBMean: srcB['mean']!,
        srcBStd: srcB['std']!,
        dstLMean: dstL['mean']!,
        dstLStd: dstL['std']!,
        dstAMean: dstA['mean']!,
        dstAStd: dstA['std']!,
        dstBMean: dstB['mean']!,
        dstBStd: dstB['std']!,
        hslHueShifts: hslHueShifts,
        hslSatRatios: hslSatRatios,
        hslLumRatios: hslLumRatios,
        toneCurve: toneCurve,
        refMedianLum: refMedianLum,
        refDynamicRange: refDynamicRange,
        shadowShift: toneCurve[0],
        midtoneContrast: (toneCurve[150] - toneCurve[100]) / (50.0 / 255.0),
        highlightRolloff: toneCurve[255],
        blackPoint: toneCurve[0],
        whitePoint: toneCurve[255],
        targetSkinHue: targetSkinHue,
        targetSkinSat: targetSkinSat,
        targetSkinLum: targetSkinLum,
        skinHueShift: (targetSkinHue - 28.0).clamp(-5.0, 5.0),
        skinSatRatio: (targetSkinSat / 0.21).clamp(0.7, 1.4),
        skinLumRatio: (targetSkinLum / 0.58).clamp(0.7, 1.4),
        targetRedHue: targetRedHue,
        targetRedSat: targetRedSat,
        targetRedLum: targetRedLum,
        targetGreenHue: targetGreenHue,
        targetGreenSat: targetGreenSat,
        targetGreenLum: targetGreenLum,
        lut3D: lut3D,
        confidenceGrid: confidenceGrid,
        globalAffineMatrix: globalAffineMatrix,
        globalOffset: globalOffset,
        dominantHueAnchors: dominantAnchors,
        method: '3d_hybrid_confidence_reference_lut',
      );

      // Validate Accuracy
      final valMetrics = ColorGradeEngine.instance.validateAccuracy(
        refOriginal: origResized,
        refGraded: gradResized,
        profile: preliminaryProfile,
      );

      return GradeProfile(
        srcLMean: preliminaryProfile.srcLMean,
        srcLStd: preliminaryProfile.srcLStd,
        srcAMean: preliminaryProfile.srcAMean,
        srcAStd: preliminaryProfile.srcAStd,
        srcBMean: preliminaryProfile.srcBMean,
        srcBStd: preliminaryProfile.srcBStd,
        dstLMean: preliminaryProfile.dstLMean,
        dstLStd: preliminaryProfile.dstLStd,
        dstAMean: preliminaryProfile.dstAMean,
        dstAStd: preliminaryProfile.dstAStd,
        dstBMean: preliminaryProfile.dstBMean,
        dstBStd: preliminaryProfile.dstBStd,
        hslHueShifts: preliminaryProfile.hslHueShifts,
        hslSatRatios: preliminaryProfile.hslSatRatios,
        hslLumRatios: preliminaryProfile.hslLumRatios,
        toneCurve: preliminaryProfile.toneCurve,
        refMedianLum: preliminaryProfile.refMedianLum,
        refDynamicRange: preliminaryProfile.refDynamicRange,
        shadowShift: preliminaryProfile.shadowShift,
        midtoneContrast: preliminaryProfile.midtoneContrast,
        highlightRolloff: preliminaryProfile.highlightRolloff,
        blackPoint: preliminaryProfile.blackPoint,
        whitePoint: preliminaryProfile.whitePoint,
        targetSkinHue: preliminaryProfile.targetSkinHue,
        targetSkinSat: preliminaryProfile.targetSkinSat,
        targetSkinLum: preliminaryProfile.targetSkinLum,
        skinHueShift: preliminaryProfile.skinHueShift,
        skinSatRatio: preliminaryProfile.skinSatRatio,
        skinLumRatio: preliminaryProfile.skinLumRatio,
        targetRedHue: preliminaryProfile.targetRedHue,
        targetRedSat: preliminaryProfile.targetRedSat,
        targetRedLum: preliminaryProfile.targetRedLum,
        targetGreenHue: preliminaryProfile.targetGreenHue,
        targetGreenSat: preliminaryProfile.targetGreenSat,
        targetGreenLum: preliminaryProfile.targetGreenLum,
        lut3D: preliminaryProfile.lut3D,
        confidenceGrid: preliminaryProfile.confidenceGrid,
        globalAffineMatrix: preliminaryProfile.globalAffineMatrix,
        globalOffset: preliminaryProfile.globalOffset,
        dominantHueAnchors: preliminaryProfile.dominantHueAnchors,
        validationMetrics: valMetrics,
        method: preliminaryProfile.method,
      );
    });
  }

  // ── 7. Adaptive Reference Grading Application (Hybrid Confidence Model) ────

  img.Image applyGrade({
    required img.Image inputImage,
    required GradeProfile profile,
  }) {
    final width = inputImage.width;
    final height = inputImage.height;
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Invalid input image dimensions: ${width}x$height');
    }

    final resultImg = img.Image(width: width, height: height);

    final lut3D = profile.lut3D;
    final has3DLut = lut3D.isNotEmpty;
    final lutSize = has3DLut ? (math.pow(lut3D.length ~/ 3, 1 / 3)).round() : 17;
    final confGrid = profile.confidenceGrid;
    final hasConfGrid = confGrid.length == lutSize * lutSize * lutSize;
    final M = profile.globalAffineMatrix;
    final bias = profile.globalOffset;
    final hasGlobalAffine = M.length == 9 && bias.length == 3;
    final hasToneCurve = profile.toneCurve.length == 256;
    final dominantAnchors = profile.dominantHueAnchors;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = inputImage.getPixel(x, y);

        final double rIn = pixel.r / 255.0;
        final double gIn = pixel.g / 255.0;
        final double bIn = pixel.b / 255.0;

        double rLut = rIn;
        double gLut = gIn;
        double bLut = bIn;
        double conf = 1.0;

        if (has3DLut && lut3D.length == lutSize * lutSize * lutSize * 3) {
          // Trilinear 3D LUT lookup
          final rIndex = rIn * (lutSize - 1);
          final gIndex = gIn * (lutSize - 1);
          final bIndex = bIn * (lutSize - 1);

          final r0 = rIndex.floor().clamp(0, lutSize - 2);
          final g0 = gIndex.floor().clamp(0, lutSize - 2);
          final b0 = bIndex.floor().clamp(0, lutSize - 2);

          final r1 = r0 + 1;
          final g1 = g0 + 1;
          final b1 = b0 + 1;

          final dr = rIndex - r0;
          final dg = gIndex - g0;
          final db = bIndex - b0;

          final idx000 = r0 * lutSize * lutSize + g0 * lutSize + b0;
          final idx100 = r1 * lutSize * lutSize + g0 * lutSize + b0;
          final idx010 = r0 * lutSize * lutSize + g1 * lutSize + b0;
          final idx110 = r1 * lutSize * lutSize + g1 * lutSize + b0;
          final idx001 = r0 * lutSize * lutSize + g0 * lutSize + b1;
          final idx101 = r1 * lutSize * lutSize + g0 * lutSize + b1;
          final idx011 = r0 * lutSize * lutSize + g1 * lutSize + b1;
          final idx111 = r1 * lutSize * lutSize + g1 * lutSize + b1;

          if (hasConfGrid) {
            final c00 = confGrid[idx000] * (1.0 - dr) + confGrid[idx100] * dr;
            final c01 = confGrid[idx001] * (1.0 - dr) + confGrid[idx101] * dr;
            final c10 = confGrid[idx010] * (1.0 - dr) + confGrid[idx110] * dr;
            final c11 = confGrid[idx011] * (1.0 - dr) + confGrid[idx111] * dr;
            final c0 = c00 * (1.0 - dg) + c10 * dg;
            final c1 = c01 * (1.0 - dg) + c11 * dg;
            conf = c0 * (1.0 - db) + c1 * db;
          }

          final lutColor = List<double>.filled(3, 0.0);
          for (int c = 0; c < 3; c++) {
            final c000 = lut3D[idx000 * 3 + c];
            final c100 = lut3D[idx100 * 3 + c];
            final c010 = lut3D[idx010 * 3 + c];
            final c110 = lut3D[idx110 * 3 + c];
            final c001 = lut3D[idx001 * 3 + c];
            final c101 = lut3D[idx101 * 3 + c];
            final c011 = lut3D[idx011 * 3 + c];
            final c111 = lut3D[idx111 * 3 + c];

            final v00 = c000 * (1.0 - dr) + c100 * dr;
            final v01 = c001 * (1.0 - dr) + c101 * dr;
            final v10 = c010 * (1.0 - dr) + c110 * dr;
            final v11 = c011 * (1.0 - dr) + c111 * dr;

            final v0 = v00 * (1.0 - dg) + v10 * dg;
            final v1 = v01 * (1.0 - dg) + v11 * dg;

            lutColor[c] = v0 * (1.0 - db) + v1 * db;
          }
          rLut = lutColor[0];
          gLut = lutColor[1];
          bLut = lutColor[2];
        }

        // Global Affine Fallback Model with Non-Linear Tone Transfer
        double rAff = rIn, gAff = gIn, bAff = bIn;
        if (hasGlobalAffine) {
          final rLin = srgbToLinear(rIn);
          final gLin = srgbToLinear(gIn);
          final bLin = srgbToLinear(bIn);

          final rAffLin = M[0] * rLin + M[1] * gLin + M[2] * bLin + bias[0];
          final gAffLin = M[3] * rLin + M[4] * gLin + M[5] * bLin + bias[1];
          final bAffLin = M[6] * rLin + M[7] * gLin + M[8] * bLin + bias[2];

          rAff = linearToSrgb(rAffLin).clamp(0.0, 1.0);
          gAff = linearToSrgb(gAffLin).clamp(0.0, 1.0);
          bAff = linearToSrgb(bAffLin).clamp(0.0, 1.0);
        }

        // Hybrid Smoothstep Blend between 0.15 and 0.60 confidence
        final blend = _smoothstep(0.15, 0.60, conf);
        double rOut = rLut * blend + rAff * (1.0 - blend);
        double gOut = gLut * blend + gAff * (1.0 - blend);
        double bOut = bLut * blend + bAff * (1.0 - blend);

        // Apply learned luminance tone curve for deep blacks, midtone contrast, and controlled highlights
        if (hasToneCurve) {
          final lIn = 0.2126 * rIn + 0.7152 * gIn + 0.0722 * bIn;
          final lOut = 0.2126 * rOut + 0.7152 * gOut + 0.0722 * bOut;
          final lTarget = profile.toneCurve[(lIn * 255.0).round().clamp(0, 255)];
          if (lOut > 1e-4) {
            final targetLumRatio = (lTarget / lOut).clamp(0.65, 1.40);
            // Blend tone curve strength (0.85 in high confidence, 1.0 in fallback)
            final curveStrength = 0.85 + 0.15 * (1.0 - blend);
            final lumRatio = 1.0 + (targetLumRatio - 1.0) * curveStrength;
            rOut = (rOut * lumRatio).clamp(0.0, 1.0);
            gOut = (gOut * lumRatio).clamp(0.0, 1.0);
            bOut = (bOut * lumRatio).clamp(0.0, 1.0);
          }
        }

        // Dynamic Dominant Hue Anchors & Bridal Red / Foliage Refinement (Widened Radius 50°)
        final hsl = rgbToHsl(rOut, gOut, bOut);
        double h = hsl[0];
        double s = hsl[1];
        double l = hsl[2];

        if (s >= 0.08 && dominantAnchors.isNotEmpty) {
          double totalWeight = 0.0, dHAcc = 0.0, sAcc = 0.0, lAcc = 0.0;
          for (final anchor in dominantAnchors) {
            double dh = (h - anchor.centerHue).abs();
            if (dh > 180) dh = 360 - dh;
            if (dh < 50.0) {
              final w = math.exp(-(dh * dh) / (2 * 22.0 * 22.0)) * anchor.weight;
              dHAcc += anchor.hueShift * w;
              sAcc += anchor.satRatio * w;
              lAcc += anchor.lumRatio * w;
              totalWeight += w;
            }
          }
          if (totalWeight > 0.01) {
            final effWeight = math.min(1.0, totalWeight);
            h = (h + (dHAcc / totalWeight) * effWeight) % 360.0;
            if (h < 0) h += 360.0;
            s = (s * (1.0 + ((sAcc / totalWeight) - 1.0) * effWeight)).clamp(0.0, 1.0);
            l = (l * (1.0 + ((lAcc / totalWeight) - 1.0) * effWeight)).clamp(0.0, 1.0);
          }
        }

        // Dedicated Bridal Red Hue Lock & Foliage Saturation Boost
        if ((h >= 325 || h <= 25) && s >= 0.18) {
          double redDist = h >= 325 ? (360.0 - h) : h;
          if (redDist < 25.0) {
            final rWeight = math.exp(-(redDist * redDist) / (2 * 14.0 * 14.0));
            // Shift towards crimson reference red
            double targetRedH = profile.targetRedHue;
            if (targetRedH > 180) targetRedH -= 360;
            double curH = h > 180 ? h - 360 : h;
            double newH = curH * (1.0 - rWeight * 0.70) + targetRedH * (rWeight * 0.70);
            h = (newH < 0 ? newH + 360 : newH) % 360.0;
            // Rich red saturation boost
            s = (s * (1.0 + 0.25 * rWeight)).clamp(0.0, 1.0);
          }
        } else if (h >= 55 && h <= 165 && s >= 0.05) {
          // Foliage Green rich depth
          final gDist = (h - profile.targetGreenHue).abs();
          if (gDist < 45.0) {
            final gWeight = math.exp(-(gDist * gDist) / (2 * 20.0 * 20.0));
            s = (s * (1.0 + 0.20 * gWeight)).clamp(0.0, 1.0);
            l = (l * (1.0 - 0.08 * gWeight)).clamp(0.0, 1.0); // Rich deeper foliage
          }
        }

        final rgbFinal = hslToRgb(h, s, l);

        // Anti-Banding Ordered Bayer 4x4 Dither at sub-LSB level (+/- 0.5/255)
        final dither = (_bayer4x4[y % 4][x % 4] / 16.0 - 0.5) / 255.0;
        final rInt = ((rgbFinal[0] + dither).clamp(0.0, 1.0) * 255.0).round();
        final gInt = ((rgbFinal[1] + dither).clamp(0.0, 1.0) * 255.0).round();
        final bInt = ((rgbFinal[2] + dither).clamp(0.0, 1.0) * 255.0).round();

        resultImg.setPixelRgb(x, y, rInt, gInt, bInt);
      }
    }

    return resultImg;
  }

  /// Evaluates accuracy of the learned profile against the ground-truth graded reference
  ValidationMetrics validateAccuracy({
    required img.Image refOriginal,
    required img.Image refGraded,
    required GradeProfile profile,
  }) {
    final gradedOrig = applyGrade(inputImage: refOriginal, profile: profile);
    final sampleW = math.min(gradedOrig.width, refGraded.width);
    final sampleH = math.min(gradedOrig.height, refGraded.height);

    double sumDeltaE = 0.0;
    double maxDeltaE = 0.0;
    int count = 0;

    for (int y = 0; y < sampleH; y += 2) {
      for (int x = 0; x < sampleW; x += 2) {
        final p1 = gradedOrig.getPixel(x, y);
        final p2 = refGraded.getPixel(x, y);
        final lab1 = rgbToLabPoint(p1.r / 255.0, p1.g / 255.0, p1.b / 255.0);
        final lab2 = rgbToLabPoint(p2.r / 255.0, p2.g / 255.0, p2.b / 255.0);
        final de = ciede2000(lab1[0], lab1[1], lab1[2], lab2[0], lab2[1], lab2[2]);
        sumDeltaE += de;
        if (de > maxDeltaE) maxDeltaE = de;
        count++;
      }
    }

    final meanDeltaE = count > 0 ? sumDeltaE / count : 0.0;
    final ssim = computeSSIM(gradedOrig, refGraded);

    return ValidationMetrics(
      meanDeltaE: meanDeltaE,
      maxDeltaE: maxDeltaE,
      ssim: ssim,
    );
  }

  /// Computes average LUT node confidence across an input image's pixel distribution
  double computeImageConfidence({
    required img.Image image,
    required GradeProfile profile,
  }) {
    final confGrid = profile.confidenceGrid;
    if (confGrid.isEmpty) return 1.0;
    final lutSize = (math.pow(confGrid.length, 1.0 / 3.0)).round();
    if (confGrid.length != lutSize * lutSize * lutSize) return 1.0;

    double confSum = 0.0;
    int count = 0;
    final step = math.max(1, math.sqrt((image.width * image.height / 10000.0)).floor());

    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < image.width; x += step) {
        final p = image.getPixel(x, y);
        final rCell = (p.r / 255.0 * (lutSize - 1)).round().clamp(0, lutSize - 1);
        final gCell = (p.g / 255.0 * (lutSize - 1)).round().clamp(0, lutSize - 1);
        final bCell = (p.b / 255.0 * (lutSize - 1)).round().clamp(0, lutSize - 1);
        final cIdx = rCell * lutSize * lutSize + gCell * lutSize + bCell;
        confSum += confGrid[cIdx];
        count++;
      }
    }

    return count > 0 ? (confSum / count).clamp(0.0, 1.0) : 1.0;
  }

  // ── 8. Isolated Single Batch Item Processor ───────────────────────────────

  Future<GradedImage> processSingleBatchItem({
    required String inputPath,
    required String outputPath,
    required String outputFileName,
    required GradeProfile profile,
    required ExportFormat format,
    required int jpegQuality,
  }) async {
    await validateFile(inputPath);

    return Isolate.run(() async {
      final rawBytes = await File(inputPath).readAsBytes();
      final ext = inputPath.split('.').last;
      final decodableBytes = extractDecodableBytes(rawBytes, ext);

      img.Image? decoded = img.decodeImage(decodableBytes);
      if (decoded == null && decodableBytes != rawBytes) {
        decoded = img.decodeImage(rawBytes);
      }

      if (decoded == null) {
        throw FileValidationError('Failed to decode image data from $ext file', inputPath);
      }

      img.Image workingImg = decoded;
      if (workingImg.width > 2048 || workingImg.height > 2048) {
        if (workingImg.width >= workingImg.height) {
          workingImg = img.copyResize(workingImg, width: 2048);
        } else {
          workingImg = img.copyResize(workingImg, height: 2048);
        }
      }

      final gradedImg = applyGrade(
        inputImage: workingImg,
        profile: profile,
      );

      final List<int> encodedBytes;
      if (format == ExportFormat.tiff) {
        encodedBytes = img.encodeTiff(gradedImg);
      } else {
        encodedBytes = img.encodeJpg(gradedImg, quality: jpegQuality.clamp(1, 100));
      }

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(encodedBytes, flush: true);

      return GradedImage(
        originalPath: inputPath,
        outputPath: outputPath,
        fileName: outputFileName,
        fileSizeBytes: encodedBytes.length,
        format: format,
      );
    });
  }

  /// Direct in-memory byte application for bounded stream workers with confidence calculation
  (Uint8List, double) applyGradeToBytesWithConfidence(
    Uint8List inputBytes,
    GradeProfile profile, {
    int targetQuality = 90,
    ExportFormat format = ExportFormat.jpeg,
  }) {
    img.Image? decoded = img.decodeImage(inputBytes);
    if (decoded == null) {
      throw Exception('Failed to decode image bytes');
    }

    img.Image workingImg = decoded;
    if (workingImg.width > 2048 || workingImg.height > 2048) {
      if (workingImg.width >= workingImg.height) {
        workingImg = img.copyResize(workingImg, width: 2048);
      } else {
        workingImg = img.copyResize(workingImg, height: 2048);
      }
    }

    final confidence = computeImageConfidence(image: workingImg, profile: profile);
    final graded = applyGrade(
      inputImage: workingImg,
      profile: profile,
    );

    final Uint8List outBytes;
    if (format == ExportFormat.tiff) {
      outBytes = Uint8List.fromList(img.encodeTiff(graded));
    } else {
      outBytes = Uint8List.fromList(img.encodeJpg(graded, quality: targetQuality.clamp(1, 100)));
    }

    return (outBytes, confidence);
  }

  /// Backward-compatible direct in-memory byte application
  Uint8List applyGradeToBytes(
    Uint8List inputBytes,
    GradeProfile profile, {
    int targetQuality = 90,
    ExportFormat format = ExportFormat.jpeg,
  }) {
    return applyGradeToBytesWithConfidence(
      inputBytes,
      profile,
      targetQuality: targetQuality,
      format: format,
    ).$1;
  }

  /// Exports the learned 3D LUT as a standard professional Adobe / DaVinci .CUBE file
  String exportToCubeLUT(GradeProfile profile, {String title = 'AIVista_Pro_Grade'}) {
    final buffer = StringBuffer();
    buffer.writeln('# AIVista Studio - Professional 3D LUT');
    buffer.writeln('# Method: ${profile.method}');
    buffer.writeln('TITLE "$title"');
    buffer.writeln('LUT_3D_SIZE 17');
    buffer.writeln('DOMAIN_MIN 0.0 0.0 0.0');
    buffer.writeln('DOMAIN_MAX 1.0 1.0 1.0');
    buffer.writeln();

    final lut = profile.lut3D;
    if (lut.isNotEmpty && lut.length >= 17 * 17 * 17 * 3) {
      for (int i = 0; i < lut.length; i += 3) {
        final r = lut[i].clamp(0.0, 1.0).toStringAsFixed(6);
        final g = lut[i + 1].clamp(0.0, 1.0).toStringAsFixed(6);
        final b = lut[i + 2].clamp(0.0, 1.0).toStringAsFixed(6);
        buffer.writeln('$r $g $b');
      }
    }

    return buffer.toString();
  }

  /// Exports learned adjustments to a Lightroom/Camera RAW compatible .XMP sidecar file
  String exportToXmpSidecar(GradeProfile profile) {
    final exposure = ((profile.dstLMean - profile.srcLMean) / 50.0).clamp(-2.0, 2.0).toStringAsFixed(2);
    final contrast = (((profile.dstLStd / (profile.srcLStd > 0 ? profile.srcLStd : 1.0)) - 1.0) * 50.0).clamp(-50.0, 50.0).toStringAsFixed(0);
    final highlights = ((profile.highlightRolloff - 1.0) * -50.0).clamp(-100.0, 100.0).toStringAsFixed(0);
    final shadows = (profile.shadowShift * 50.0).clamp(-100.0, 100.0).toStringAsFixed(0);
    final temp = ((profile.dstBMean - profile.srcBMean) * 2.0).clamp(-100.0, 100.0).toStringAsFixed(0);
    final tint = ((profile.dstAMean - profile.srcAMean) * 2.0).clamp(-100.0, 100.0).toStringAsFixed(0);

    return '''<x:xmpmeta xmlns:x="adobe:ns:meta/">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"
      crs:Version="15.0"
      crs:ProcessVersion="15.4"
      crs:Exposure2012="$exposure"
      crs:Contrast2012="$contrast"
      crs:Highlights2012="$highlights"
      crs:Shadows2012="$shadows"
      crs:Temperature="$temp"
      crs:Tint="$tint"
      crs:HueAdjustmentRed="${profile.hslHueShifts[0].toStringAsFixed(1)}"
      crs:HueAdjustmentOrange="${profile.hslHueShifts[1].toStringAsFixed(1)}"
      crs:HueAdjustmentYellow="${profile.hslHueShifts[2].toStringAsFixed(1)}"
      crs:HueAdjustmentGreen="${profile.hslHueShifts[3].toStringAsFixed(1)}"
      crs:HueAdjustmentAqua="${profile.hslHueShifts[4].toStringAsFixed(1)}"
      crs:HueAdjustmentBlue="${profile.hslHueShifts[5].toStringAsFixed(1)}"
      crs:SaturationAdjustmentRed="${((profile.hslSatRatios[0] - 1.0) * 100).toStringAsFixed(0)}"
      crs:SaturationAdjustmentOrange="${((profile.hslSatRatios[1] - 1.0) * 100).toStringAsFixed(0)}"
      crs:SaturationAdjustmentYellow="${((profile.hslSatRatios[2] - 1.0) * 100).toStringAsFixed(0)}"
      crs:SaturationAdjustmentGreen="${((profile.hslSatRatios[3] - 1.0) * 100).toStringAsFixed(0)}"
      crs:SaturationAdjustmentAqua="${((profile.hslSatRatios[4] - 1.0) * 100).toStringAsFixed(0)}"
      crs:SaturationAdjustmentBlue="${((profile.hslSatRatios[5] - 1.0) * 100).toStringAsFixed(0)}"
    />
  </rdf:RDF>
</x:xmpmeta>''';
  }

  /// Parses an Adobe standard .CUBE LUT file into a 3D LUT table
  static List<double>? parseCubeLUT(String content) {
    try {
      final lines = content.split('\n');
      final lutValues = <double>[];

      for (var rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#') || line.startsWith('TITLE') || line.startsWith('LUT_') || line.startsWith('DOMAIN_')) {
          continue;
        }

        final tokens = line.split(RegExp(r'\s+'));
        if (tokens.length >= 3) {
          final r = double.tryParse(tokens[0]);
          final g = double.tryParse(tokens[1]);
          final b = double.tryParse(tokens[2]);
          if (r != null && g != null && b != null) {
            lutValues.add(r.clamp(0.0, 1.0));
            lutValues.add(g.clamp(0.0, 1.0));
            lutValues.add(b.clamp(0.0, 1.0));
          }
        }
      }

      if (lutValues.length >= 17 * 17 * 17 * 3) {
        return lutValues;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
