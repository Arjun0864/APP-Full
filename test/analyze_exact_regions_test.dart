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
  test('Exact Regional Ground Truth Analysis', () {
    final origFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483764674.jpg');
    final gradFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483764740.jpg');

    final imgOrig = img.decodeImage(origFile.readAsBytesSync())!;
    final imgGrad = img.decodeImage(gradFile.readAsBytesSync())!;
    final w = imgOrig.width;
    final h = imgOrig.height;
    final gradResized = img.copyResize(imgGrad, width: w, height: h);

    // 1. Red Dress (Orig: hot pink / magenta H 330..350)
    double rOrigDress = 0, gOrigDress = 0, bOrigDress = 0;
    double rGradDress = 0, gGradDress = 0, bGradDress = 0;
    int countDress = 0;

    // 2. Green Leaves (Orig: H 75..140)
    double rOrigGreen = 0, gOrigGreen = 0, bOrigGreen = 0;
    double rGradGreen = 0, gGradGreen = 0, bGradGreen = 0;
    int countGreen = 0;

    // 3. Skin (Orig: H 15..45, L 0.35..0.85)
    double rOrigSkin = 0, gOrigSkin = 0, bOrigSkin = 0;
    double rGradSkin = 0, gGradSkin = 0, bGradSkin = 0;
    int countSkin = 0;

    // 4. Sherwani Cream (Orig: L 0.60..0.85, S < 0.25, not skin)
    double rOrigSher = 0, gOrigSher = 0, bOrigSher = 0;
    double rGradSher = 0, gGradSher = 0, bGradSher = 0;
    int countSher = 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final po = imgOrig.getPixel(x, y);
        final pg = gradResized.getPixel(x, y);

        final ro = po.r / 255.0; final go = po.g / 255.0; final bo = po.b / 255.0;
        final rg = pg.r / 255.0; final gg = pg.g / 255.0; final bg = pg.b / 255.0;

        final hslo = rgbToHsl(ro, go, bo);
        final hslg = rgbToHsl(rg, gg, bg);

        // Dress: strong red/pink
        if ((hslo[0] >= 325 || hslo[0] <= 15) && hslo[1] >= 0.30 && po.r > 100) {
          rOrigDress += ro; gOrigDress += go; bOrigDress += bo;
          rGradDress += rg; gGradDress += gg; bGradDress += bg;
          countDress++;
        }

        // Green leaves:
        if (hslo[0] >= 65 && hslo[0] <= 155 && hslo[1] >= 0.12) {
          rOrigGreen += ro; gOrigGreen += go; bOrigGreen += bo;
          rGradGreen += rg; gGradGreen += gg; bGradGreen += bg;
          countGreen++;
        }

        // Skin (faces):
        if (hslo[0] >= 15 && hslo[0] <= 45 && hslo[1] >= 0.15 && hslo[1] <= 0.60 && hslo[2] >= 0.35 && hslo[2] <= 0.80 && po.r > po.g && po.g > po.b) {
          rOrigSkin += ro; gOrigSkin += go; bOrigSkin += bo;
          rGradSkin += rg; gGradSkin += gg; bGradSkin += bg;
          countSkin++;
        }
      }
    }

    if (countDress > 0) {
      final hsloD = rgbToHsl(rOrigDress/countDress, gOrigDress/countDress, bOrigDress/countDress);
      final hslgD = rgbToHsl(rGradDress/countDress, gGradDress/countDress, bGradDress/countDress);
      print('LEHENGA DRESS:');
      print('  Orig: RGB=(${(rOrigDress/countDress*255).round()}, ${(gOrigDress/countDress*255).round()}, ${(bOrigDress/countDress*255).round()}), HSL=(${hsloD[0].toStringAsFixed(1)}°, ${(hsloD[1]*100).toStringAsFixed(1)}%, ${(hsloD[2]*100).toStringAsFixed(1)}%)');
      print('  Grad: RGB=(${(rGradDress/countDress*255).round()}, ${(gGradDress/countDress*255).round()}, ${(bGradDress/countDress*255).round()}), HSL=(${hslgD[0].toStringAsFixed(1)}°, ${(hslgD[1]*100).toStringAsFixed(1)}%, ${(hslgD[2]*100).toStringAsFixed(1)}%)');
    }

    if (countGreen > 0) {
      final hsloG = rgbToHsl(rOrigGreen/countGreen, gOrigGreen/countGreen, bOrigGreen/countGreen);
      final hslgG = rgbToHsl(rGradGreen/countGreen, gGradGreen/countGreen, bGradGreen/countGreen);
      print('\nGREEN LEAVES:');
      print('  Orig: RGB=(${(rOrigGreen/countGreen*255).round()}, ${(gOrigGreen/countGreen*255).round()}, ${(bOrigGreen/countGreen*255).round()}), HSL=(${hsloG[0].toStringAsFixed(1)}°, ${(hsloG[1]*100).toStringAsFixed(1)}%, ${(hsloG[2]*100).toStringAsFixed(1)}%)');
      print('  Grad: RGB=(${(rGradGreen/countGreen*255).round()}, ${(gGradGreen/countGreen*255).round()}, ${(bGradGreen/countGreen*255).round()}), HSL=(${hslgG[0].toStringAsFixed(1)}°, ${(hslgG[1]*100).toStringAsFixed(1)}%, ${(hslgG[2]*100).toStringAsFixed(1)}%)');
    }

    if (countSkin > 0) {
      final hsloS = rgbToHsl(rOrigSkin/countSkin, gOrigSkin/countSkin, bOrigSkin/countSkin);
      final hslgS = rgbToHsl(rGradSkin/countSkin, gGradSkin/countSkin, bGradSkin/countSkin);
      print('\nSKIN TONES:');
      print('  Orig: RGB=(${(rOrigSkin/countSkin*255).round()}, ${(gOrigSkin/countSkin*255).round()}, ${(bOrigSkin/countSkin*255).round()}), HSL=(${hsloS[0].toStringAsFixed(1)}°, ${(hsloS[1]*100).toStringAsFixed(1)}%, ${(hsloS[2]*100).toStringAsFixed(1)}%)');
      print('  Grad: RGB=(${(rGradSkin/countSkin*255).round()}, ${(gGradSkin/countSkin*255).round()}, ${(bGradSkin/countSkin*255).round()}), HSL=(${hslgS[0].toStringAsFixed(1)}°, ${(hslgS[1]*100).toStringAsFixed(1)}%, ${(hslgS[2]*100).toStringAsFixed(1)}%)');
    }
  });
}
