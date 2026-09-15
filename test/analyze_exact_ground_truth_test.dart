import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('Exact Ground Truth Analysis', () {
    final origFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483764674.jpg');
    final gradFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483764740.jpg');

    final imgOrig = img.decodeImage(origFile.readAsBytesSync())!;
    final imgGrad = img.decodeImage(gradFile.readAsBytesSync())!;

    print('Orig: ${imgOrig.width}x${imgOrig.height}, Grad: ${imgGrad.width}x${imgGrad.height}');

    final w = imgOrig.width;
    final h = imgOrig.height;
    final gradResized = img.copyResize(imgGrad, width: w, height: h);

    double minRo = 255, minGo = 255, minBo = 255;
    double maxRo = 0, maxGo = 0, maxBo = 0;
    double sumRo = 0, sumGo = 0, sumBo = 0;

    double minRg = 255, minGg = 255, minBg = 255;
    double maxRg = 0, maxGg = 0, maxBg = 0;
    double sumRg = 0, sumGg = 0, sumBg = 0;

    int total = w * h;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final po = imgOrig.getPixel(x, y);
        final pg = gradResized.getPixel(x, y);

        if (po.r < minRo) minRo = po.r.toDouble();
        if (po.g < minGo) minGo = po.g.toDouble();
        if (po.b < minBo) minBo = po.b.toDouble();
        if (po.r > maxRo) maxRo = po.r.toDouble();
        if (po.g > maxGo) maxGo = po.g.toDouble();
        if (po.b > maxBo) maxBo = po.b.toDouble();
        sumRo += po.r; sumGo += po.g; sumBo += po.b;

        if (pg.r < minRg) minRg = pg.r.toDouble();
        if (pg.g < minGg) minGg = pg.g.toDouble();
        if (pg.b < minBg) minBg = pg.b.toDouble();
        if (pg.r > maxRg) maxRg = pg.r.toDouble();
        if (pg.g > maxGg) maxGg = pg.g.toDouble();
        if (pg.b > maxBg) maxBg = pg.b.toDouble();
        sumRg += pg.r; sumGg += pg.g; sumBg += pg.b;
      }
    }

    print('\n--- Channel Statistics ---');
    print('ORIGINAL: R=[$minRo..$maxRo] mean=${(sumRo/total).toStringAsFixed(1)}, G=[$minGo..$maxGo] mean=${(sumGo/total).toStringAsFixed(1)}, B=[$minBo..$maxBo] mean=${(sumBo/total).toStringAsFixed(1)}');
    print('GRADED:   R=[$minRg..$maxRg] mean=${(sumRg/total).toStringAsFixed(1)}, G=[$minGg..$maxGg] mean=${(sumGg/total).toStringAsFixed(1)}, B=[$minBg..$maxBg] mean=${(sumBg/total).toStringAsFixed(1)}');

    final binSums = List<double>.filled(11, 0.0);
    final binCounts = List<int>.filled(11, 0);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final po = imgOrig.getPixel(x, y);
        final pg = gradResized.getPixel(x, y);
        final lo = 0.2126 * po.r + 0.7152 * po.g + 0.0722 * po.b;
        final lg = 0.2126 * pg.r + 0.7152 * pg.g + 0.0722 * pg.b;
        final bin = (lo / 25.0).round().clamp(0, 10);
        binSums[bin] += lg;
        binCounts[bin]++;
      }
    }

    print('\n--- Tonal Transfer Curve (Input Lum -> Graded Lum) ---');
    for (int i = 0; i <= 10; i++) {
      final inL = i * 25;
      final outL = binCounts[i] > 0 ? (binSums[i] / binCounts[i]).toStringAsFixed(1) : 'N/A';
      print('Input $inL -> Graded $outL (count: ${binCounts[i]})');
    }
  });
}
