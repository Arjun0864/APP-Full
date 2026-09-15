import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

List<double> rgbToHsl(double r, double g, double b) {
  final max = [r, g, b].reduce((a, b) => a > b ? a : b);
  final min = [r, g, b].reduce((a, b) => a < b ? a : b);
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
    h *= 60.0;
  }
  return [h, s, l];
}

void main() {
  test('Analyze ground truth vs latest output', () {
    final refGradFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483764740.jpg');
    final latestOutputFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789486928884.jpg');

    final imgRef = img.decodeImage(refGradFile.readAsBytesSync())!;
    final imgOut = img.decodeImage(latestOutputFile.readAsBytesSync())!;

    void analyze(String label, img.Image image) {
      print('\n=== $label ===');
      double rTot = 0, gTot = 0, bTot = 0;
      double sTot = 0;
      for (final p in image) {
        rTot += p.r; gTot += p.g; bTot += p.b;
        final hsl = rgbToHsl(p.r/255.0, p.g/255.0, p.b/255.0);
        sTot += hsl[1];
      }
      final n = image.width * image.height;
      print('GLOBAL: RGB=(${(rTot/n).toStringAsFixed(1)}, ${(gTot/n).toStringAsFixed(1)}, ${(bTot/n).toStringAsFixed(1)}) Mean Sat=${(sTot/n*100).toStringAsFixed(1)}% R-B=${((rTot-bTot)/n).toStringAsFixed(1)}, G-B=${((gTot-bTot)/n).toStringAsFixed(1)}');

      // Ground / Dirt (lower 25% of image, excluding dress):
      double rDirt = 0, gDirt = 0, bDirt = 0; int countDirt = 0;
      for (int y = (image.height * 0.75).toInt(); y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final p = image.getPixel(x, y);
          final hsl = rgbToHsl(p.r/255.0, p.g/255.0, p.b/255.0);
          if (!(hsl[0] >= 340 || hsl[0] <= 15) || hsl[1] < 0.25) {
            rDirt += p.r; gDirt += p.g; bDirt += p.b; countDirt++;
          }
        }
      }
      if (countDirt > 0) {
        final hslD = rgbToHsl(rDirt/countDirt/255.0, gDirt/countDirt/255.0, bDirt/countDirt/255.0);
        print('GROUND/DIRT: RGB=(${(rDirt/countDirt).toStringAsFixed(1)}, ${(gDirt/countDirt).toStringAsFixed(1)}, ${(bDirt/countDirt).toStringAsFixed(1)}), HSL=(${hslD[0].toStringAsFixed(1)}°, ${(hslD[1]*100).toStringAsFixed(1)}%, ${(hslD[2]*100).toStringAsFixed(1)}%) (Warmth R-B=${((rDirt-bDirt)/countDirt).toStringAsFixed(1)})');
      }

      // Trees / Vegetation (upper right / background, not sky):
      double rTree = 0, gTree = 0, bTree = 0; int countTree = 0;
      for (int y = 0; y < (image.height * 0.50).toInt(); y++) {
        for (int x = (image.width * 0.50).toInt(); x < image.width; x++) {
          final p = image.getPixel(x, y);
          final hsl = rgbToHsl(p.r/255.0, p.g/255.0, p.b/255.0);
          if (hsl[2] < 0.70 && p.r < 180) {
            rTree += p.r; gTree += p.g; bTree += p.b; countTree++;
          }
        }
      }
      if (countTree > 0) {
        final hslT = rgbToHsl(rTree/countTree/255.0, gTree/countTree/255.0, bTree/countTree/255.0);
        print('TREES/FOLIAGE: RGB=(${(rTree/countTree).toStringAsFixed(1)}, ${(gTree/countTree).toStringAsFixed(1)}, ${(bTree/countTree).toStringAsFixed(1)}), HSL=(${hslT[0].toStringAsFixed(1)}°, ${(hslT[1]*100).toStringAsFixed(1)}%, ${(hslT[2]*100).toStringAsFixed(1)}%)');
      }
    }

    analyze('TARGET REFERENCE (UTSV3804 2.jpg)', imgRef);
    analyze('USER LATEST OUTPUT (media_1789486928884.jpg)', imgOut);
  });
}
