import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ai_video_generator/features/color_grade/services/color_grade_engine.dart';
import 'package:ai_video_generator/features/color_grade/models/color_grade_models.dart';

void main() {
  test('Validate Reference Grade Matching on Real User Images', () async {
    final refOrigFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483764674.jpg');
    final refGradFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483764740.jpg');
    final inputTestFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483763685.jpg');

    if (!refOrigFile.existsSync() || !refGradFile.existsSync() || !inputTestFile.existsSync()) {
      return;
    }

    final refOrigImg = img.decodeImage(refOrigFile.readAsBytesSync())!;
    final refGradImg = img.decodeImage(refGradFile.readAsBytesSync())!;
    final inputTestImg = img.decodeImage(inputTestFile.readAsBytesSync())!;

    final engine = ColorGradeEngine.instance;
    final profile = await engine.analyzeReferencePair(
      refOriginal: refOrigImg,
      refGraded: refGradImg,
    );

    expect(profile.method, equals('3d_adaptive_reference_lut'));
    expect(profile.lut3D.length, equals(17 * 17 * 17 * 3));
    expect(profile.toneCurve.length, equals(256));

    final gradedOutput = engine.applyGrade(
      inputImage: inputTestImg,
      profile: profile,
    );

    final outPath = '/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/scratch/UTSV3782_reference_matched.jpg';
    final outBytes = img.encodeJpg(gradedOutput, quality: 95);
    File(outPath).writeAsBytesSync(outBytes);

    expect(File(outPath).existsSync(), isTrue);
  });
}
