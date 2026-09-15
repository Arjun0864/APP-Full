import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import '../lib/features/color_grade/services/color_grade_engine.dart';
import '../lib/features/color_grade/models/color_grade_models.dart';

double srgbToLinear(double c) {
  final clamped = c.clamp(0.0, 1.0);
  return clamped <= 0.04045 ? clamped / 12.92 : math.pow((clamped + 0.055) / 1.055, 2.4).toDouble();
}

double linearToSrgb(double c) {
  final clamped = c.clamp(0.0, 1.0);
  return clamped <= 0.0031308 ? clamped * 12.92 : 1.055 * math.pow(clamped, 1.0 / 2.4).toDouble() - 0.055;
}

List<double> rgbToLab(double r, double g, double b) {
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

double ciede2000(double l1, double a1, double b1, double l2, double a2, double b2) {
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

List<int> deltaEToThermal(double de) {
  final t = (de / 15.0).clamp(0.0, 1.0);
  if (t < 0.20) {
    final s = t / 0.20;
    return [0, (s * 180).round(), (180 + s * 75).round()];
  } else if (t < 0.40) {
    final s = (t - 0.20) / 0.20;
    return [0, (180 + s * 75).round(), ((1.0 - s) * 255).round()];
  } else if (t < 0.70) {
    final s = (t - 0.40) / 0.30;
    return [(s * 255).round(), 255, 0];
  } else {
    final s = (t - 0.70) / 0.30;
    return [255, ((1.0 - s) * 220).round(), 0];
  }
}

List<double>? solve4x4(List<List<double>> A, List<double> b) {
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

double computeSSIM(img.Image img1, img.Image img2) {
  final w = math.min(img1.width, img2.width);
  final h = math.min(img1.height, img2.height);
  const c1 = 6.5025;
  const c2 = 58.5225;

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

class DiagnosticModel {
  final int lutSize;
  final List<double> lut3D;
  final List<double> confidenceGrid;
  final List<double> globalAffineMatrix;
  final List<double> globalOffset;

  DiagnosticModel({
    required this.lutSize,
    required this.lut3D,
    required this.confidenceGrid,
    required this.globalAffineMatrix,
    required this.globalOffset,
  });
}

DiagnosticModel trainDiagnosticModel({
  required img.Image origImg,
  required img.Image gradImg,
  int lutSize = 65,
  double sigma = 0.85,
}) {
  final w = math.min(math.min(origImg.width, gradImg.width), 1024);
  final h = math.min(math.min(origImg.height, gradImg.height), 1024);
  final orig = (origImg.width == w && origImg.height == h) ? origImg : img.copyResize(origImg, width: w, height: h);
  final grad = (gradImg.width == w && gradImg.height == h) ? gradImg : img.copyResize(gradImg, width: w, height: h);

  final totalPixels = w * h;

  final ata = List.generate(4, (_) => List<double>.filled(4, 0.0));
  final atyR = List<double>.filled(4, 0.0);
  final atyG = List<double>.filled(4, 0.0);
  final atyB = List<double>.filled(4, 0.0);

  final binDstRSum = Float64List(256); final binDstRCount = Int32List(256);
  final binDstGSum = Float64List(256); final binDstGCount = Int32List(256);
  final binDstBSum = Float64List(256); final binDstBCount = Int32List(256);

  final gridRSum = Float64List(lutSize * lutSize * lutSize);
  final gridGSum = Float64List(lutSize * lutSize * lutSize);
  final gridBSum = Float64List(lutSize * lutSize * lutSize);
  final gridWeight = Float64List(lutSize * lutSize * lutSize);

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final pSrc = orig.getPixel(x, y);
      final pDst = grad.getPixel(x, y);

      final rIn = pSrc.r / 255.0; final gIn = pSrc.g / 255.0; final bIn = pSrc.b / 255.0;
      final rOut = pDst.r / 255.0; final gOut = pDst.g / 255.0; final bOut = pDst.b / 255.0;

      final rInLin = srgbToLinear(rIn); final gInLin = srgbToLinear(gIn); final bInLin = srgbToLinear(bIn);
      final rOutLin = srgbToLinear(rOut); final gOutLin = srgbToLinear(gOut); final bOutLin = srgbToLinear(bOut);

      final u = [rInLin, gInLin, bInLin, 1.0];
      for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
          ata[i][j] += u[i] * u[j];
        }
        atyR[i] += u[i] * rOutLin;
        atyG[i] += u[i] * gOutLin;
        atyB[i] += u[i] * bOutLin;
      }

      final binR = pSrc.r.toInt().clamp(0, 255); binDstRSum[binR] += rOut; binDstRCount[binR]++;
      final binG = pSrc.g.toInt().clamp(0, 255); binDstGSum[binG] += gOut; binDstGCount[binG]++;
      final binB = pSrc.b.toInt().clamp(0, 255); binDstBSum[binB] += bOut; binDstBCount[binB]++;

      final rCell = (rIn * (lutSize - 1)).round().clamp(0, lutSize - 1);
      final gCell = (gIn * (lutSize - 1)).round().clamp(0, lutSize - 1);
      final bCell = (bIn * (lutSize - 1)).round().clamp(0, lutSize - 1);
      final cIdx = rCell * lutSize * lutSize + gCell * lutSize + bCell;
      gridRSum[cIdx] += rOut;
      gridGSum[cIdx] += gOut;
      gridBSum[cIdx] += bOut;
      gridWeight[cIdx] += 1.0;
    }
  }

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

  List<double> buildSmoothCurve(Float64List sums, Int32List counts) {
    final raw = List<double>.filled(256, 0.0);
    int lastObs = 0; double lastVal = 0.0;
    for (int i = 0; i < 256; i++) {
      if (counts[i] > 0) {
        raw[i] = (sums[i] / counts[i]).clamp(0.0, 1.0);
        if (i > lastObs + 1) {
          final sV = raw[lastObs]; final eV = raw[i];
          for (int k = lastObs + 1; k < i; k++) {
            final t = (k - lastObs) / (i - lastObs);
            raw[k] = sV * (1.0 - t) + eV * t;
          }
        }
        lastObs = i; lastVal = raw[i];
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

  final rCurve = buildSmoothCurve(binDstRSum, binDstRCount);
  final gCurve = buildSmoothCurve(binDstGSum, binDstGCount);
  final bCurve = buildSmoothCurve(binDstBSum, binDstBCount);

  final lut3D = List<double>.filled(lutSize * lutSize * lutSize * 3, 0.0);
  final confidenceGrid = List<double>.filled(lutSize * lutSize * lutSize, 0.0);

  final twoSigmaSq = 2.0 * sigma * sigma;
  final radius = (sigma * 3.0).ceil();

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
        final minR = math.max(0, r - radius); final maxR = math.min(lutSize - 1, r + radius);
        final minG = math.max(0, g - radius); final maxG = math.min(lutSize - 1, g + radius);
        final minB = math.max(0, b - radius); final maxB = math.min(lutSize - 1, b + radius);

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
        final confidence = (1.0 - math.exp(-wSum / 6.0)).clamp(0.0, 1.0);
        confidenceGrid[cellIdx] = confidence;

        if (wSum > 0.005) {
          final rLearned = rAcc / wSum;
          final gLearned = gAcc / wSum;
          final bLearned = bAcc / wSum;

          final blendWeight = math.min(1.0, wSum / 2.0);
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

  return DiagnosticModel(
    lutSize: lutSize,
    lut3D: lut3D,
    confidenceGrid: confidenceGrid,
    globalAffineMatrix: globalAffineMatrix,
    globalOffset: globalOffset,
  );
}

const bayer4x4 = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];

double smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

img.Image applyDiagnosticModel(img.Image input, DiagnosticModel model) {
  final w = input.width; final h = input.height;
  final out = img.Image(width: w, height: h);
  final lutSize = model.lutSize;
  final lut = model.lut3D;
  final confGrid = model.confidenceGrid;
  final M = model.globalAffineMatrix;
  final bias = model.globalOffset;

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = input.getPixel(x, y);
      final rIn = p.r / 255.0; final gIn = p.g / 255.0; final bIn = p.b / 255.0;

      final rIndex = rIn * (lutSize - 1);
      final gIndex = gIn * (lutSize - 1);
      final bIndex = bIn * (lutSize - 1);

      final r0 = rIndex.floor().clamp(0, lutSize - 2);
      final g0 = gIndex.floor().clamp(0, lutSize - 2);
      final b0 = bIndex.floor().clamp(0, lutSize - 2);
      final r1 = r0 + 1; final g1 = g0 + 1; final b1 = b0 + 1;

      final dr = rIndex - r0; final dg = gIndex - g0; final db = bIndex - b0;

      final idx000 = r0 * lutSize * lutSize + g0 * lutSize + b0;
      final idx100 = r1 * lutSize * lutSize + g0 * lutSize + b0;
      final idx010 = r0 * lutSize * lutSize + g1 * lutSize + b0;
      final idx110 = r1 * lutSize * lutSize + g1 * lutSize + b0;
      final idx001 = r0 * lutSize * lutSize + g0 * lutSize + b1;
      final idx101 = r1 * lutSize * lutSize + g0 * lutSize + b1;
      final idx011 = r0 * lutSize * lutSize + g1 * lutSize + b1;
      final idx111 = r1 * lutSize * lutSize + g1 * lutSize + b1;

      final c00 = confGrid[idx000] * (1.0 - dr) + confGrid[idx100] * dr;
      final c01 = confGrid[idx001] * (1.0 - dr) + confGrid[idx101] * dr;
      final c10 = confGrid[idx010] * (1.0 - dr) + confGrid[idx100] * dr;
      final c11 = confGrid[idx011] * (1.0 - dr) + confGrid[idx111] * dr;
      final c0 = c00 * (1.0 - dg) + c10 * dg;
      final c1 = c01 * (1.0 - dg) + c11 * dg;
      final conf = c0 * (1.0 - db) + c1 * db;

      final lutColor = List<double>.filled(3, 0.0);
      for (int c = 0; c < 3; c++) {
        final v00 = lut[idx000 * 3 + c] * (1.0 - dr) + lut[idx100 * 3 + c] * dr;
        final v01 = lut[idx001 * 3 + c] * (1.0 - dr) + lut[idx100 * 3 + c] * dr;
        final v10 = lut[idx010 * 3 + c] * (1.0 - dr) + lut[idx110 * 3 + c] * dr;
        final v11 = lut[idx011 * 3 + c] * (1.0 - dr) + lut[idx111 * 3 + c] * dr;
        final v0 = v00 * (1.0 - dg) + v10 * dg;
        final v1 = v01 * (1.0 - dg) + v11 * dg;
        lutColor[c] = v0 * (1.0 - db) + v1 * db;
      }

      final rLin = srgbToLinear(rIn); final gLin = srgbToLinear(gIn); final bLin = srgbToLinear(bIn);
      final rAffLin = M[0] * rLin + M[1] * gLin + M[2] * bLin + bias[0];
      final gAffLin = M[3] * rLin + M[4] * gLin + M[5] * bLin + bias[1];
      final bAffLin = M[6] * rLin + M[7] * gLin + M[8] * bLin + bias[2];

      final rAff = linearToSrgb(rAffLin);
      final gAff = linearToSrgb(gAffLin);
      final bAff = linearToSrgb(bAffLin);

      // In high confidence regions (conf >= 0.8), blend is 1.0 (pure 3D LUT)
      final blend = smoothstep(0.10, 0.75, conf);
      final rOut = lutColor[0] * blend + rAff * (1.0 - blend);
      final gOut = lutColor[1] * blend + gAff * (1.0 - blend);
      final bOut = lutColor[2] * blend + bAff * (1.0 - blend);

      final dither = (bayer4x4[y % 4][x % 4] / 16.0 - 0.5) / 255.0;
      final rInt = ((rOut + dither).clamp(0.0, 1.0) * 255.0).round();
      final gInt = ((gOut + dither).clamp(0.0, 1.0) * 255.0).round();
      final bInt = ((bOut + dither).clamp(0.0, 1.0) * 255.0).round();

      out.setPixelRgb(x, y, rInt, gInt, bInt);
    }
  }

  return out;
}

void main() {
  test('Diagnose Error Region and Generate Heatmap', () async {
    final origFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483764674.jpg');
    final gradFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483764740.jpg');

    final origImg = img.decodeImage(await origFile.readAsBytes())!;
    final gradImg = img.decodeImage(await gradFile.readAsBytes())!;

    print('\n=== TESTING RESOLUTIONS AND SIGMA ===');
    for (final size in [33, 49, 65]) {
      for (final s in [0.70, 0.85, 1.0]) {
        final model = trainDiagnosticModel(origImg: origImg, gradImg: gradImg, lutSize: size, sigma: s);
        final graded = applyDiagnosticModel(origImg, model);

        final deltaEList = <double>[];
        final sampleW = math.min(graded.width, gradImg.width);
        final sampleH = math.min(graded.height, gradImg.height);

        for (int y = 0; y < sampleH; y += 2) {
          for (int x = 0; x < sampleW; x += 2) {
            final p1 = graded.getPixel(x, y);
            final p2 = gradImg.getPixel(x, y);
            final lab1 = rgbToLab(p1.r / 255.0, p1.g / 255.0, p1.b / 255.0);
            final lab2 = rgbToLab(p2.r / 255.0, p2.g / 255.0, p2.b / 255.0);
            final de = ciede2000(lab1[0], lab1[1], lab1[2], lab2[0], lab2[1], lab2[2]);
            deltaEList.add(de);
          }
        }

        deltaEList.sort();
        final count = deltaEList.length;
        final mean = deltaEList.reduce((a, b) => a + b) / count;
        final median = deltaEList[(count * 0.50).toInt()];
        final p90 = deltaEList[(count * 0.90).toInt()];
        final p95 = deltaEList[(count * 0.95).toInt()];
        final p99 = deltaEList[(count * 0.99).toInt()];
        final max = deltaEList.last;
        final pctLess1 = (deltaEList.where((e) => e < 1.0).length / count) * 100;
        final pctLess2 = (deltaEList.where((e) => e < 2.0).length / count) * 100;
        final pctLess5 = (deltaEList.where((e) => e < 5.0).length / count) * 100;
        final ssim = computeSSIM(graded, gradImg);

        print('LUT $size^3 (sigma=$s): Mean=${mean.toStringAsFixed(3)}, Median=${median.toStringAsFixed(3)}, P90=${p90.toStringAsFixed(3)}, P95=${p95.toStringAsFixed(3)}, P99=${p99.toStringAsFixed(3)}, Max=${max.toStringAsFixed(2)} | <1: ${pctLess1.toStringAsFixed(1)}%, <2: ${pctLess2.toStringAsFixed(1)}%, <5: ${pctLess5.toStringAsFixed(1)}% | SSIM: ${(ssim * 100).toStringAsFixed(3)}%');
      }
    }

    // Generate Heatmap with best 65^3 sigma=0.85
    final bestModel = trainDiagnosticModel(origImg: origImg, gradImg: gradImg, lutSize: 65, sigma: 0.85);
    final graded = applyDiagnosticModel(origImg, bestModel);
    final w = math.min(graded.width, gradImg.width);
    final h = math.min(graded.height, gradImg.height);

    final heatmapImg = img.Image(width: w, height: h);
    final overlayImg = img.Image(width: w, height: h);
    final highErrorPixels = <Map<String, dynamic>>[];

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p1 = graded.getPixel(x, y);
        final p2 = gradImg.getPixel(x, y);
        final pOrig = origImg.getPixel(x, y);

        final lab1 = rgbToLab(p1.r / 255.0, p1.g / 255.0, p1.b / 255.0);
        final lab2 = rgbToLab(p2.r / 255.0, p2.g / 255.0, p2.b / 255.0);
        final de = ciede2000(lab1[0], lab1[1], lab1[2], lab2[0], lab2[1], lab2[2]);

        final rgbThermal = deltaEToThermal(de);
        heatmapImg.setPixelRgb(x, y, rgbThermal[0], rgbThermal[1], rgbThermal[2]);

        final rOver = (p2.r * 0.45 + rgbThermal[0] * 0.55).round();
        final gOver = (p2.g * 0.45 + rgbThermal[1] * 0.55).round();
        final bOver = (p2.b * 0.45 + rgbThermal[2] * 0.55).round();
        overlayImg.setPixelRgb(x, y, rOver, gOver, bOver);

        if (de > 8.0) {
          highErrorPixels.add({
            'x': x,
            'y': y,
            'x_pct': (x / w * 100).toStringAsFixed(1),
            'y_pct': (y / h * 100).toStringAsFixed(1),
            'deltaE': de,
            'orig_rgb': [pOrig.r, pOrig.g, pOrig.b],
            'grad_rgb': [p2.r, p2.g, p2.b],
            'trans_rgb': [p1.r, p1.g, p1.b],
          });
        }
      }
    }

    highErrorPixels.sort((a, b) => (b['deltaE'] as double).compareTo(a['deltaE'] as double));

    print('\n=== TOP 10 MAX ΔE00 OUTLIER PIXELS ===');
    for (int i = 0; i < math.min(10, highErrorPixels.length); i++) {
      final p = highErrorPixels[i];
      print('Rank ${i + 1}: (${p['x']}, ${p['y']}) [${p['x_pct']}%, ${p['y_pct']}%] -> ΔE00 = ${(p['deltaE'] as double).toStringAsFixed(2)} | Orig RGB: ${p['orig_rgb']} | Target Graded RGB: ${p['grad_rgb']} | Graded Engine RGB: ${p['trans_rgb']}');
    }

    final heatmapPath = '/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/scratch/delta_e_heatmap.png';
    final overlayPath = '/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/scratch/delta_e_overlay.png';
    await File(heatmapPath).writeAsBytes(img.encodePng(heatmapImg));
    await File(overlayPath).writeAsBytes(img.encodePng(overlayImg));
    print('Saved Heatmap: $heatmapPath');
    print('Saved Overlay: $overlayPath');

    // Create 3-panel comparison for batch test UTSV3782: Original | Graded Engine | Reference Graded
    final batchOrigFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789486928884.jpg');
    final batchOrigImg = img.decodeImage(await batchOrigFile.readAsBytes())!;
    final engineProfile = await ColorGradeEngine.instance.analyzeReferencePair(
      refOriginal: origImg,
      refGraded: gradImg,
    );
    final batchGradedImg = ColorGradeEngine.instance.applyGrade(
      inputImage: batchOrigImg,
      profile: engineProfile,
    );

    // Save individual graded image
    final singleGradPath = '/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/scratch/UTSV3782_graded_fixed.jpg';
    await File(singleGradPath).writeAsBytes(img.encodeJpg(batchGradedImg, quality: 95));

    final panelW = 600;
    final panelH = (batchOrigImg.height * (panelW / batchOrigImg.width)).round();

    final rBatchOrig = img.copyResize(batchOrigImg, width: panelW, height: panelH);
    final rBatchGrad = img.copyResize(batchGradedImg, width: panelW, height: panelH);
    final rRefGrad = img.copyResize(gradImg, width: panelW, height: panelH);

    final comparison3Panel = img.Image(width: panelW * 3, height: panelH);
    for (int y = 0; y < panelH; y++) {
      for (int x = 0; x < panelW; x++) {
        comparison3Panel.setPixel(x, y, rBatchOrig.getPixel(x, y));
        comparison3Panel.setPixel(panelW + x, y, rBatchGrad.getPixel(x, y));
        comparison3Panel.setPixel(panelW * 2 + x, y, rRefGrad.getPixel(x, y));
      }
    }

    final compPath = '/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/scratch/UTSV3782_side_by_side_comparison.jpg';
    await File(compPath).writeAsBytes(img.encodeJpg(comparison3Panel, quality: 95));
    print('Saved 3-Panel Side-by-Side Comparison: $compPath');
    print('Saved Graded Batch Output: $singleGradPath');
  });

  test('Diagnose UTSV3782 Batch Issue Deeply', () async {
    final refOrigPath = '/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483764674.jpg';
    final refGradPath = '/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483764740.jpg';
    final batchPath = '/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789486928884.jpg';

    final origBytes = await File(refOrigPath).readAsBytes();
    final gradBytes = await File(refGradPath).readAsBytes();
    final batchBytes = await File(batchPath).readAsBytes();

    final refOrig = img.decodeImage(origBytes)!;
    final refGrad = img.decodeImage(gradBytes)!;
    final batchImg = img.decodeImage(batchBytes)!;

    print('\n==================================================');
    print('=== DIAGNOSING BATCH TEST IMAGE UTSV3782 ===');
    print('==================================================');

    final profile = await ColorGradeEngine.instance.analyzeReferencePair(
      refOriginal: refOrig,
      refGraded: refGrad,
    );

    final confGrid = profile.confidenceGrid;
    final lutSize = (math.pow(confGrid.length, 1.0 / 3.0)).round();

    int totalPixels = 0;
    int countHigh = 0;   // >= 0.75
    int countBlend = 0;  // 0.15 <= conf < 0.75
    int countLow = 0;    // < 0.15

    int redPixels = 0, redHigh = 0, redBlend = 0, redLow = 0;
    int greenPixels = 0, greenHigh = 0, greenBlend = 0, greenLow = 0;
    int skinPixels = 0, skinHigh = 0, skinBlend = 0, skinLow = 0;

    for (int y = 0; y < batchImg.height; y += 2) {
      for (int x = 0; x < batchImg.width; x += 2) {
        final p = batchImg.getPixel(x, y);
        final rCell = (p.r / 255.0 * (lutSize - 1)).round().clamp(0, lutSize - 1);
        final gCell = (p.g / 255.0 * (lutSize - 1)).round().clamp(0, lutSize - 1);
        final bCell = (p.b / 255.0 * (lutSize - 1)).round().clamp(0, lutSize - 1);
        final cIdx = rCell * lutSize * lutSize + gCell * lutSize + bCell;
        final conf = confGrid[cIdx];

        totalPixels++;
        if (conf >= 0.75) countHigh++;
        else if (conf >= 0.15) countBlend++;
        else countLow++;

        final hsl = ColorGradeEngine.instance.rgbToHsl(p.r / 255.0, p.g / 255.0, p.b / 255.0);
        final h = hsl[0]; final s = hsl[1]; final l = hsl[2];

        // Red check (lehenga)
        if ((h >= 320 || h <= 30) && s >= 0.15) {
          redPixels++;
          if (conf >= 0.75) redHigh++;
          else if (conf >= 0.15) redBlend++;
          else redLow++;
        }

        // Green check (foliage)
        if (h >= 55 && h <= 170 && s >= 0.06) {
          greenPixels++;
          if (conf >= 0.75) greenHigh++;
          else if (conf >= 0.15) greenBlend++;
          else greenLow++;
        }

        // Skin check
        if (h >= 15 && h <= 45 && s >= 0.12 && l >= 0.30) {
          skinPixels++;
          if (conf >= 0.75) skinHigh++;
          else if (conf >= 0.15) skinBlend++;
          else skinLow++;
        }
      }
    }

    print('Overall Pixel Confidence Histogram on UTSV3782:');
    print('  High Conf (>= 0.75): ${(countHigh / totalPixels * 100).toStringAsFixed(1)}% ($countHigh pixels)');
    print('  Blend Zone (0.15..0.75): ${(countBlend / totalPixels * 100).toStringAsFixed(1)}% ($countBlend pixels)');
    print('  Low/Fallback (< 0.15): ${(countLow / totalPixels * 100).toStringAsFixed(1)}% ($countLow pixels)');

    print('\nRed / Lehenga Region Pixels ($redPixels total):');
    if (redPixels > 0) {
      print('  High Conf: ${(redHigh / redPixels * 100).toStringAsFixed(1)}%, Blend: ${(redBlend / redPixels * 100).toStringAsFixed(1)}%, Low: ${(redLow / redPixels * 100).toStringAsFixed(1)}%');
    }

    print('\nGreen / Foliage Region Pixels ($greenPixels total):');
    if (greenPixels > 0) {
      print('  High Conf: ${(greenHigh / greenPixels * 100).toStringAsFixed(1)}%, Blend: ${(greenBlend / greenPixels * 100).toStringAsFixed(1)}%, Low: ${(greenLow / greenPixels * 100).toStringAsFixed(1)}%');
    }

    print('\nSkin Region Pixels ($skinPixels total):');
    if (skinPixels > 0) {
      print('  High Conf: ${(skinHigh / skinPixels * 100).toStringAsFixed(1)}%, Blend: ${(skinBlend / skinPixels * 100).toStringAsFixed(1)}%, Low: ${(skinLow / skinPixels * 100).toStringAsFixed(1)}%');
    }

    // Inspect Red Lehenga source colors in UTSV3782 vs UTSV3804
    print('\n=== SAMPLING RED LEHENGA IN UTSV3782 ===');
    final sampleHslList = <List<double>>[];
    for (int y = 0; y < batchImg.height; y += 10) {
      for (int x = 0; x < batchImg.width; x += 10) {
        final p = batchImg.getPixel(x, y);
        final hsl = ColorGradeEngine.instance.rgbToHsl(p.r / 255.0, p.g / 255.0, p.b / 255.0);
        if ((hsl[0] >= 320 || hsl[0] <= 30) && hsl[1] >= 0.20) {
          sampleHslList.add(hsl);
        }
      }
    }
    if (sampleHslList.isNotEmpty) {
      double avgH = 0, avgS = 0, avgL = 0;
      for (final s in sampleHslList) {
        double h = s[0]; if (h > 180) h -= 360;
        avgH += h; avgS += s[1]; avgL += s[2];
      }
      avgH /= sampleHslList.length; if (avgH < 0) avgH += 360;
      avgS /= sampleHslList.length;
      avgL /= sampleHslList.length;
      print('UTSV3782 Red Lehenga Avg Source HSL: H=${avgH.toStringAsFixed(1)}°, S=${avgS.toStringAsFixed(2)}, L=${avgL.toStringAsFixed(2)} (${sampleHslList.length} samples)');
    }

    // Inspect Green Foliage source colors in UTSV3782
    print('\n=== SAMPLING GREEN FOLIAGE IN UTSV3782 ===');
    final foliageHslList = <List<double>>[];
    for (int y = 0; y < batchImg.height; y += 10) {
      for (int x = 0; x < batchImg.width; x += 10) {
        final p = batchImg.getPixel(x, y);
        final hsl = ColorGradeEngine.instance.rgbToHsl(p.r / 255.0, p.g / 255.0, p.b / 255.0);
        if (hsl[0] >= 55 && hsl[0] <= 170 && hsl[1] >= 0.06) {
          foliageHslList.add(hsl);
        }
      }
    }
    if (foliageHslList.isNotEmpty) {
      double avgH = 0, avgS = 0, avgL = 0;
      for (final s in foliageHslList) {
        avgH += s[0]; avgS += s[1]; avgL += s[2];
      }
      avgH /= foliageHslList.length;
      avgS /= foliageHslList.length;
      avgL /= foliageHslList.length;
      print('UTSV3782 Foliage Avg Source HSL: H=${avgH.toStringAsFixed(1)}°, S=${avgS.toStringAsFixed(2)}, L=${avgL.toStringAsFixed(2)} (${foliageHslList.length} samples)');
    }
  });
}

