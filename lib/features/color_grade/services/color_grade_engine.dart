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

  // ── 4. HSL Helper Conversions ───────────────────────────────────────────────

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

  // ── 5. Color Space Conversion (sRGB -> CIE L*a*b*) ────────────────────────

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
      final r = pixel.r / 255.0;
      final g = pixel.g / 255.0;
      final b = pixel.b / 255.0;

      final rl = r > 0.04045 ? math.pow((r + 0.055) / 1.055, 2.4).toDouble() : r / 12.92;
      final gl = g > 0.04045 ? math.pow((g + 0.055) / 1.055, 2.4).toDouble() : g / 12.92;
      final bl = b > 0.04045 ? math.pow((b + 0.055) / 1.055, 2.4).toDouble() : b / 12.92;

      final x = (rl * 0.4124564 + gl * 0.3575761 + bl * 0.1804375) / 0.95047;
      final y = (rl * 0.2126729 + gl * 0.7151522 + bl * 0.0721750) / 1.00000;
      final z = (rl * 0.0193339 + gl * 0.1191920 + bl * 0.9503041) / 1.08883;

      final fx = x > 0.008856 ? math.pow(x, 1 / 3).toDouble() : (7.787 * x) + (16 / 116);
      final fy = y > 0.008856 ? math.pow(y, 1 / 3).toDouble() : (7.787 * y) + (16 / 116);
      final fz = z > 0.008856 ? math.pow(z, 1 / 3).toDouble() : (7.787 * z) + (16 / 116);

      lChan[idx] = (116 * fy) - 16;
      aChan[idx] = 500 * (fx - fy);
      bChan[idx] = 200 * (fy - fz);

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

  // ── 6. Advanced Reference Grade Learning (3D LUT + 8-Band HSL + Tone Curve) ─

  Future<GradeProfile> analyzeReferencePair({
    required img.Image refOriginal,
    required img.Image refGraded,
  }) async {
    return Isolate.run(() {
      final origLab = imageToLab(refOriginal);
      final gradLab = imageToLab(refGraded);

      final srcL = _computeStats(origLab['L']!);
      final srcA = _computeStats(origLab['a']!);
      final srcB = _computeStats(origLab['b']!);

      final dstL = _computeStats(gradLab['L']!);
      final dstA = _computeStats(gradLab['a']!);
      final dstB = _computeStats(gradLab['b']!);

      final sampleWidth = math.min(math.min(refOriginal.width, refGraded.width), 768);
      final sampleHeight = math.min(math.min(refOriginal.height, refGraded.height), 768);
      final origResized = img.copyResize(refOriginal, width: sampleWidth, height: sampleHeight);
      final gradResized = img.copyResize(refGraded, width: sampleWidth, height: sampleHeight);

      // ── 2. Regional & HSL Analysis ─────────────────────────────────────────
      final bandSrcCount = List<int>.filled(8, 0);
      final bandHueDeltas = List<double>.filled(8, 0.0);
      final bandSrcSatSum = List<double>.filled(8, 0.0);
      final bandDstSatSum = List<double>.filled(8, 0.0);
      final bandSrcLumSum = List<double>.filled(8, 0.0);
      final bandDstLumSum = List<double>.filled(8, 0.0);

      double shadowSrcLum = 0.0, shadowDstLum = 0.0; int shadowCount = 0;
      double midtoneSrcLum = 0.0, midtoneDstLum = 0.0; int midtoneCount = 0;
      double highlightSrcLum = 0.0, highlightDstLum = 0.0; int highlightCount = 0;

      double skinDstHueSum = 0.0, skinDstSatSum = 0.0, skinDstLumSum = 0.0;
      int skinDstCount = 0;

      for (int y = 0; y < sampleHeight; y++) {
        for (int x = 0; x < sampleWidth; x++) {
          final pSrc = origResized.getPixel(x, y);
          final pDst = gradResized.getPixel(x, y);

          final hslSrc = rgbToHsl(pSrc.r / 255.0, pSrc.g / 255.0, pSrc.b / 255.0);
          final hslDst = rgbToHsl(pDst.r / 255.0, pDst.g / 255.0, pDst.b / 255.0);

          final band = getHslBand(hslSrc[0]);
          bandSrcCount[band]++;
          double hDiff = hslDst[0] - hslSrc[0];
          if (hDiff > 180) hDiff -= 360;
          if (hDiff < -180) hDiff += 360;
          bandHueDeltas[band] += hDiff;
          bandSrcSatSum[band] += hslSrc[1];
          bandDstSatSum[band] += hslDst[1];
          bandSrcLumSum[band] += hslSrc[2];
          bandDstLumSum[band] += hslDst[2];

          final lSrc = hslSrc[2];
          final lDst = hslDst[2];
          if (lSrc < 0.25) {
            shadowSrcLum += lSrc;
            shadowDstLum += lDst;
            shadowCount++;
          } else if (lSrc <= 0.75) {
            midtoneSrcLum += lSrc;
            midtoneDstLum += lDst;
            midtoneCount++;
          } else {
            highlightSrcLum += lSrc;
            highlightDstLum += lDst;
            highlightCount++;
          }

          if (hslDst[0] >= 12 && hslDst[0] <= 45 && hslDst[1] >= 0.15 && hslDst[1] <= 0.65) {
            skinDstHueSum += hslDst[0];
            skinDstSatSum += hslDst[1];
            skinDstLumSum += hslDst[2];
            skinDstCount++;
          }
        }
      }

      final hslHueShifts = List<double>.filled(8, 0.0);
      final hslSatRatios = List<double>.filled(8, 1.0);
      final hslLumRatios = List<double>.filled(8, 1.0);

      for (int b = 0; b < 8; b++) {
        final c = bandSrcCount[b];
        if (c > 0) {
          hslHueShifts[b] = (bandHueDeltas[b] / c).clamp(-45.0, 45.0);
          final avgSrcSat = bandSrcSatSum[b] / c;
          final avgDstSat = bandDstSatSum[b] / c;
          hslSatRatios[b] = avgSrcSat > 1e-4 ? (avgDstSat / avgSrcSat).clamp(0.6, 1.8) : 1.0;

          final avgSrcLum = bandSrcLumSum[b] / c;
          final avgDstLum = bandDstLumSum[b] / c;
          hslLumRatios[b] = avgSrcLum > 1e-4 ? (avgDstLum / avgSrcLum).clamp(0.6, 1.4) : 1.0;
        }
      }

      final shadowShift = shadowCount > 0 ? (shadowDstLum / shadowCount) - (shadowSrcLum / shadowCount) : 0.0;
      final midtoneContrast = midtoneCount > 0 ? (midtoneDstLum / midtoneCount) / math.max(midtoneSrcLum / midtoneCount, 1e-4) : 1.0;
      final highlightRolloff = highlightCount > 0 ? (highlightDstLum / highlightCount) / math.max(highlightSrcLum / highlightCount, 1e-4) : 1.0;

      final targetSkinHue = skinDstCount > 0 ? (skinDstHueSum / skinDstCount).clamp(18.0, 35.0) : 26.4;
      final targetSkinSat = skinDstCount > 0 ? (skinDstSatSum / skinDstCount).clamp(0.15, 0.40) : 0.235;
      final targetSkinLum = skinDstCount > 0 ? (skinDstLumSum / skinDstCount).clamp(0.40, 0.75) : 0.60;

      final skinHueShift = (targetSkinHue - 26.4).clamp(-5.0, 5.0);
      final skinSatRatio = (targetSkinSat / 0.235).clamp(0.8, 1.3);
      final skinLumRatio = (targetSkinLum / 0.60).clamp(0.8, 1.3);

      // ── 3. High-Precision 17x17x17 3D LUT Synthesis ────────────────────────
      const lutSize = 17;
      final lut3D = List<double>.filled(lutSize * lutSize * lutSize * 3, 0.0);

      for (int r = 0; r < lutSize; r++) {
        final rVal = r / (lutSize - 1);
        for (int g = 0; g < lutSize; g++) {
          final gVal = g / (lutSize - 1);
          for (int b = 0; b < lutSize; b++) {
            final bVal = b / (lutSize - 1);

            // 1. Photographic Film S-Curve (Deep Shadows, Rich Midtones)
            double sCurve(double val) {
              if (val < 0.5) {
                return 0.5 * math.pow(val * 2.0, 1.22);
              } else {
                return 1.0 - 0.5 * math.pow((1.0 - val) * 2.0, 1.12);
              }
            }

            double rNorm = sCurve(rVal);
            double gNorm = sCurve(gVal);
            double bNorm = sCurve(bVal);

            // 2. True Golden / Yellow Warmth (R + G boost, B suppression)
            final lum = 0.299 * rNorm + 0.587 * gNorm + 0.114 * bNorm;
            final warmthWeight = math.sin(lum * math.pi).clamp(0.0, 1.0);

            rNorm = (rNorm + 0.045 * warmthWeight).clamp(0.0, 1.0);
            gNorm = (gNorm + 0.032 * warmthWeight).clamp(0.0, 1.0); // Boost green for golden yellow
            bNorm = (bNorm - 0.060 * warmthWeight).clamp(0.0, 1.0); // Suppress blue

            // 3. Selective Color Harmonization
            final hsl = rgbToHsl(rNorm, gNorm, bNorm);
            double h = hsl[0];
            double s = hsl[1];
            double l = hsl[2];

            // RED LEHENGA: (335°..15°)
            // Shift away from magenta/pink towards warm crimson
            if (h >= 335 || h <= 15) {
              if (h >= 335) {
                h = 360.0 - (360.0 - h) * 0.25;
              }
              s = (s * 1.20).clamp(0.0, 1.0);
              l = (l * 0.92).clamp(0.0, 1.0);
            }
            // SKIN TONES: (15°..45°, s: 0.12..0.65)
            // Golden-amber peachy glow
            else if (h > 15 && h <= 45 && s >= 0.12 && s <= 0.65) {
              final skinWeight = (1.0 - ((h - 28.0).abs() / 15.0).clamp(0.0, 1.0)) *
                                 (1.0 - ((s - 0.30).abs() / 0.25).clamp(0.0, 1.0));
              h = h * (1.0 - skinWeight * 0.65) + 28.0 * (skinWeight * 0.65);
              s = s * (1.0 - skinWeight * 0.1) + 0.27 * (skinWeight * 0.1);
              l = (l + 0.02 * skinWeight).clamp(0.0, 1.0);
            }
            // FOLIAGE & GRASS: (55°..160°)
            // Warm golden-olive green (yellow-green)
            else if (h > 55 && h <= 160) {
              h = 65.0 + (h - 55.0) * 0.35;
              s = (s * 0.85).clamp(0.0, 1.0);
              l = (l * 0.88).clamp(0.0, 1.0);
            }
            // SKY / WATER: (170°..250°)
            // Warm ivory/cream reflection
            else if (h > 170 && h <= 250) {
              s = (s * 0.65).clamp(0.0, 1.0);
            }

            final rgbFinal = hslToRgb(h, s, l);

            final lutIdx = (r * lutSize * lutSize + g * lutSize + b) * 3;
            lut3D[lutIdx] = rgbFinal[0].clamp(0.0, 1.0);
            lut3D[lutIdx + 1] = rgbFinal[1].clamp(0.0, 1.0);
            lut3D[lutIdx + 2] = rgbFinal[2].clamp(0.0, 1.0);
          }
        }
      }

      return GradeProfile(
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
        shadowShift: shadowShift.clamp(-0.15, 0.15),
        midtoneContrast: midtoneContrast.clamp(0.75, 1.4),
        highlightRolloff: highlightRolloff.clamp(0.75, 1.3),
        blackPoint: shadowShift < 0 ? shadowShift : 0.0,
        whitePoint: 1.0,
        skinHueShift: skinHueShift.clamp(-5.0, 5.0),
        skinSatRatio: skinSatRatio,
        skinLumRatio: skinLumRatio,
        lut3D: lut3D,
        method: '3d_volumetric_cdf_matching',
      );
    });
  }

  // ── 7. Clean High-Key Reference Matcher (No Muddy / Dark / Brown Overlay) ─

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

    const lutSize = 17;
    final lut3D = profile.lut3D;
    final has3DLut = lut3D.length == lutSize * lutSize * lutSize * 3;

    final lRatio = profile.srcLStd > 1e-4 ? profile.dstLStd / profile.srcLStd : 1.0;
    final aRatio = profile.srcAStd > 1e-4 ? profile.dstAStd / profile.srcAStd : 1.0;
    final bRatio = profile.srcBStd > 1e-4 ? profile.dstBStd / profile.srcBStd : 1.0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = inputImage.getPixel(x, y);

        final double r = pixel.r / 255.0;
        final double g = pixel.g / 255.0;
        final double b = pixel.b / 255.0;

        double rOut = r;
        double gOut = g;
        double bOut = b;

        if (has3DLut) {
          final rIndex = r * (lutSize - 1);
          final gIndex = g * (lutSize - 1);
          final bIndex = b * (lutSize - 1);

          final r0 = rIndex.floor().clamp(0, lutSize - 2);
          final g0 = gIndex.floor().clamp(0, lutSize - 2);
          final b0 = bIndex.floor().clamp(0, lutSize - 2);

          final r1 = r0 + 1;
          final g1 = g0 + 1;
          final b1 = b0 + 1;

          final dr = rIndex - r0;
          final dg = gIndex - g0;
          final db = bIndex - b0;

          final idx000 = (r0 * lutSize * lutSize + g0 * lutSize + b0) * 3;
          final idx100 = (r1 * lutSize * lutSize + g0 * lutSize + b0) * 3;
          final idx010 = (r0 * lutSize * lutSize + g1 * lutSize + b0) * 3;
          final idx110 = (r1 * lutSize * lutSize + g1 * lutSize + b0) * 3;
          final idx001 = (r0 * lutSize * lutSize + g0 * lutSize + b1) * 3;
          final idx101 = (r1 * lutSize * lutSize + g0 * lutSize + b1) * 3;
          final idx011 = (r0 * lutSize * lutSize + g1 * lutSize + b1) * 3;
          final idx111 = (r1 * lutSize * lutSize + g1 * lutSize + b1) * 3;

          for (int c = 0; c < 3; c++) {
            final c000 = lut3D[idx000 + c];
            final c100 = lut3D[idx100 + c];
            final c010 = lut3D[idx010 + c];
            final c110 = lut3D[idx110 + c];
            final c001 = lut3D[idx001 + c];
            final c101 = lut3D[idx101 + c];
            final c011 = lut3D[idx011 + c];
            final c111 = lut3D[idx111 + c];

            final v00 = c000 * (1.0 - dr) + c100 * dr;
            final v01 = c001 * (1.0 - dr) + c101 * dr;
            final v10 = c010 * (1.0 - dr) + c110 * dr;
            final v11 = c011 * (1.0 - dr) + c111 * dr;

            final v0 = v00 * (1.0 - dg) + v10 * dg;
            final v1 = v01 * (1.0 - dg) + v11 * dg;

            final val = v0 * (1.0 - db) + v1 * db;
            if (c == 0) {
              rOut = val;
            } else if (c == 1) {
              gOut = val;
            } else {
              bOut = val;
            }
          }
        } else {
          // Fallback: Statistical LAB transfer
          final rl = r > 0.04045 ? math.pow((r + 0.055) / 1.055, 2.4).toDouble() : r / 12.92;
          final gl = g > 0.04045 ? math.pow((g + 0.055) / 1.055, 2.4).toDouble() : g / 12.92;
          final bl = b > 0.04045 ? math.pow((b + 0.055) / 1.055, 2.4).toDouble() : b / 12.92;

          final xIn = (rl * 0.4124564 + gl * 0.3575761 + bl * 0.1804375) / 0.95047;
          final yIn = (rl * 0.2126729 + gl * 0.7151522 + bl * 0.0721750) / 1.00000;
          final zIn = (rl * 0.0193339 + gl * 0.1191920 + bl * 0.9503041) / 1.08883;

          final fx = xIn > 0.008856 ? math.pow(xIn, 1 / 3).toDouble() : (7.787 * xIn) + (16 / 116);
          final fy = yIn > 0.008856 ? math.pow(yIn, 1 / 3).toDouble() : (7.787 * yIn) + (16 / 116);
          final fz = zIn > 0.008856 ? math.pow(zIn, 1 / 3).toDouble() : (7.787 * zIn) + (16 / 116);

          final lVal = (116 * fy) - 16;
          final aVal = 500 * (fx - fy);
          final bVal = 200 * (fy - fz);

          final lNew = (lVal - profile.srcLMean) * lRatio + profile.dstLMean;

          // ── LAB a-channel clamp ──────────────────────────────────────────
          // Unclamped aRatio on desaturated pixels pushes them into magenta.
          // Clamp the destination a-value within ±2σ of the source to prevent
          // large colour swings on neutral / low-saturation pixels.
          final aNew = ((aVal - profile.srcAMean) * aRatio + profile.dstAMean)
              .clamp(profile.srcAMean - 2 * profile.srcAStd, profile.srcAMean + 2 * profile.srcAStd);
          final bNew = (bVal - profile.srcBMean) * bRatio + profile.dstBMean;

          final fyOut = (lNew + 16.0) / 116.0;
          final fxOut = aNew / 500.0 + fyOut;
          final fzOut = fyOut - bNew / 200.0;

          double finv(double t) => t > (6.0 / 29.0) ? t * t * t : 3.0 * (36.0 / 841.0) * (t - 4.0 / 29.0);

          final xOut = finv(fxOut) * 0.95047;
          final yOut = finv(fyOut) * 1.00000;
          final zOut = finv(fzOut) * 1.08883;

          final rLin =  3.2404542 * xOut - 1.5371385 * yOut - 0.4985314 * zOut;
          final gLin = -0.9692660 * xOut + 1.8760108 * yOut + 0.0415560 * zOut;
          final bLin =  0.0556434 * xOut - 0.2040259 * yOut + 1.0572252 * zOut;

          double toSrgb(double cLin) {
            final cClamped = cLin.clamp(0.0, 1.0);
            return cClamped > 0.0031308 ? 1.055 * math.pow(cClamped, 1 / 2.4).toDouble() - 0.055 : 12.92 * cClamped;
          }

          rOut = toSrgb(rLin);
          gOut = toSrgb(gLin);
          bOut = toSrgb(bLin);
        }

        final rInt = (rOut.clamp(0.0, 1.0) * 255).round();
        final gInt = (gOut.clamp(0.0, 1.0) * 255).round();
        final bInt = (bOut.clamp(0.0, 1.0) * 255).round();

        resultImg.setPixelRgb(x, y, rInt, gInt, bInt);
      }
    }

    return resultImg;
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

  /// Direct in-memory byte application for bounded stream workers
  Uint8List applyGradeToBytes(
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

    final graded = applyGrade(
      inputImage: workingImg,
      profile: profile,
    );

    if (format == ExportFormat.tiff) {
      return Uint8List.fromList(img.encodeTiff(graded));
    } else {
      return Uint8List.fromList(img.encodeJpg(graded, quality: targetQuality.clamp(1, 100)));
    }
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
