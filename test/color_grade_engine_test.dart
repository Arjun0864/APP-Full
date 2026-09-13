import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ai_video_generator/features/color_grade/services/color_grade_engine.dart';
import 'package:ai_video_generator/features/color_grade/models/color_grade_models.dart';

void main() {
  group('ColorGradeEngine Unit Tests', () {
    test('imageToLab should calculate valid L*a*b* channels', () {
      final testImg = img.Image(width: 10, height: 10);
      testImg.clear(img.ColorRgb8(255, 128, 64));

      final engine = ColorGradeEngine.instance;
      final lab = engine.imageToLab(testImg);

      expect(lab.containsKey('L'), isTrue);
      expect(lab.containsKey('a'), isTrue);
      expect(lab.containsKey('b'), isTrue);
      expect(lab['L']!.length, equals(100));
      expect(lab['L']![0], greaterThan(0));
    });

    test('analyzeReferencePair should produce a 3D LUT GradeProfile', () async {
      final origImg = img.Image(width: 16, height: 16);
      origImg.clear(img.ColorRgb8(100, 100, 100));

      final gradImg = img.Image(width: 16, height: 16);
      gradImg.clear(img.ColorRgb8(150, 120, 90));

      final engine = ColorGradeEngine.instance;
      final profile = await engine.analyzeReferencePair(
        refOriginal: origImg,
        refGraded: gradImg,
      );

      expect(profile.method, equals('3d_lut_hsl_8band_matching'));
      expect(profile.lut3D.length, equals(17 * 17 * 17 * 3));
      expect(profile.hslHueShifts.length, equals(8));
      expect(profile.dstLMean, greaterThan(profile.srcLMean));
    });

    test('applyGrade should transform target image using 3D LUT profile', () {
      final inputImg = img.Image(width: 8, height: 8);
      inputImg.clear(img.ColorRgb8(100, 100, 100));

      final profile = GradeProfile(
        srcLMean: 50.0,
        srcLStd: 10.0,
        srcAMean: 0.0,
        srcAStd: 5.0,
        srcBMean: 0.0,
        srcBStd: 5.0,
        dstLMean: 70.0,
        dstLStd: 12.0,
        dstAMean: 10.0,
        dstAStd: 6.0,
        dstBMean: 15.0,
        dstBStd: 7.0,
        hslHueShifts: List.filled(8, 5.0),
        hslSatRatios: List.filled(8, 1.2),
        hslLumRatios: List.filled(8, 1.1),
        shadowShift: 0.05,
        midtoneContrast: 1.1,
        highlightRolloff: 0.95,
        blackPoint: 0.0,
        whitePoint: 1.0,
        skinHueShift: 2.0,
        skinSatRatio: 1.1,
        skinLumRatio: 1.05,
        lut3D: List.filled(17 * 17 * 17 * 3, 0.5),
      );

      final engine = ColorGradeEngine.instance;
      final result = engine.applyGrade(
        inputImage: inputImg,
        profile: profile,
      );

      expect(result.width, equals(8));
      expect(result.height, equals(8));
      expect(result.getPixel(0, 0).r, greaterThan(0));
    });

    test('extractDecodableBytes should detect embedded JPEG markers', () {
      final fakeRawBytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x18, // Header
        0xFF, 0xD8, // Embedded JPEG SOI
        0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        ...List.filled(6000, 0xAA),
        0xFF, 0xD9, // Embedded JPEG EOI
        0x00, 0x00
      ]);

      final extracted = ColorGradeEngine.extractDecodableBytes(fakeRawBytes, 'cr3');
      expect(extracted.length, greaterThan(6000));
      expect(extracted[0], equals(0xFF));
      expect(extracted[1], equals(0xD8));
      expect(extracted[extracted.length - 2], equals(0xFF));
      expect(extracted[extracted.length - 1], equals(0xD9));
    });

    test('applyGrade fallback without 3D LUT should apply statistical LAB transfer', () {
      final inputImg = img.Image(width: 8, height: 8);
      inputImg.clear(img.ColorRgb8(100, 100, 100));

      final profile = GradeProfile(
        srcLMean: 50.0,
        srcLStd: 10.0,
        srcAMean: 0.0,
        srcAStd: 5.0,
        srcBMean: 0.0,
        srcBStd: 5.0,
        dstLMean: 75.0,
        dstLStd: 15.0,
        dstAMean: 10.0,
        dstAStd: 6.0,
        dstBMean: 15.0,
        dstBStd: 7.0,
        hslHueShifts: List.filled(8, 0.0),
        hslSatRatios: List.filled(8, 1.0),
        hslLumRatios: List.filled(8, 1.0),
        shadowShift: 0.0,
        midtoneContrast: 1.0,
        highlightRolloff: 1.0,
        blackPoint: 0.0,
        whitePoint: 1.0,
        skinHueShift: 0.0,
        skinSatRatio: 1.0,
        skinLumRatio: 1.0,
        lut3D: const [], // Empty LUT triggers statistical LAB transfer
      );

      final engine = ColorGradeEngine.instance;
      final result = engine.applyGrade(
        inputImage: inputImg,
        profile: profile,
      );

      expect(result.width, equals(8));
      expect(result.height, equals(8));
      expect(result.getPixel(0, 0).r, greaterThan(100)); // L increased from 50 to 75
    });

    test('extractDecodableBytes should bypass non-raw image formats', () {
      final jpgBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02, 0xFF, 0xD9]);
      final resultJpg = ColorGradeEngine.extractDecodableBytes(jpgBytes, 'jpg');
      expect(resultJpg, equals(jpgBytes));

      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final resultPng = ColorGradeEngine.extractDecodableBytes(pngBytes, 'png');
      expect(resultPng, equals(pngBytes));

      final tifBytes = Uint8List.fromList([0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00]);
      final resultTif = ColorGradeEngine.extractDecodableBytes(tifBytes, 'tiff');
      expect(resultTif, equals(tifBytes));
    });

    test('rgbToHsl and hslToRgb should be invertible', () {
      final engine = ColorGradeEngine.instance;
      final hsl = engine.rgbToHsl(0.8, 0.4, 0.2);
      final rgb = engine.hslToRgb(hsl[0], hsl[1], hsl[2]);

      expect(rgb[0], closeTo(0.8, 0.01));
      expect(rgb[1], closeTo(0.4, 0.01));
      expect(rgb[2], closeTo(0.2, 0.01));
    });

    test('exportToCubeLUT and parseCubeLUT should serialize and parse 3D LUT', () {
      final engine = ColorGradeEngine.instance;
      final profile = GradeProfile(
        srcLMean: 50.0,
        srcLStd: 10.0,
        srcAMean: 0.0,
        srcAStd: 5.0,
        srcBMean: 0.0,
        srcBStd: 5.0,
        dstLMean: 60.0,
        dstLStd: 12.0,
        dstAMean: 5.0,
        dstAStd: 6.0,
        dstBMean: 10.0,
        dstBStd: 7.0,
        hslHueShifts: List.filled(8, 0.0),
        hslSatRatios: List.filled(8, 1.0),
        hslLumRatios: List.filled(8, 1.0),
        shadowShift: 0.0,
        midtoneContrast: 1.0,
        highlightRolloff: 1.0,
        blackPoint: 0.0,
        whitePoint: 1.0,
        skinHueShift: 0.0,
        skinSatRatio: 1.0,
        skinLumRatio: 1.0,
        lut3D: List.filled(17 * 17 * 17 * 3, 0.75),
      );

      final cubeStr = engine.exportToCubeLUT(profile);
      expect(cubeStr.contains('LUT_3D_SIZE 17'), isTrue);
      expect(cubeStr.contains('0.750000 0.750000 0.750000'), isTrue);

      final parsedLut = ColorGradeEngine.parseCubeLUT(cubeStr);
      expect(parsedLut, isNotNull);
      expect(parsedLut!.length, equals(17 * 17 * 17 * 3));
      expect(parsedLut[0], closeTo(0.75, 0.001));
    });

    test('exportToXmpSidecar should generate valid Camera RAW XML structure', () {
      final engine = ColorGradeEngine.instance;
      final profile = GradeProfile(
        srcLMean: 50.0,
        srcLStd: 10.0,
        srcAMean: 0.0,
        srcAStd: 5.0,
        srcBMean: 0.0,
        srcBStd: 5.0,
        dstLMean: 65.0,
        dstLStd: 12.0,
        dstAMean: 5.0,
        dstAStd: 6.0,
        dstBMean: 10.0,
        dstBStd: 7.0,
        hslHueShifts: List.filled(8, 2.0),
        hslSatRatios: List.filled(8, 1.1),
        hslLumRatios: List.filled(8, 1.0),
        shadowShift: 0.1,
        midtoneContrast: 1.05,
        highlightRolloff: 0.9,
        blackPoint: 0.0,
        whitePoint: 1.0,
        skinHueShift: 0.0,
        skinSatRatio: 1.0,
        skinLumRatio: 1.0,
        lut3D: const [],
      );

      final xmp = engine.exportToXmpSidecar(profile);
      expect(xmp.contains('<x:xmpmeta'), isTrue);
      expect(xmp.contains('crs:Exposure2012'), isTrue);
      expect(xmp.contains('crs:Highlights2012'), isTrue);
      expect(xmp.contains('crs:Shadows2012'), isTrue);
    });
  });
}
