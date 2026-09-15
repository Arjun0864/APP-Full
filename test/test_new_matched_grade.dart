import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ai_video_generator/features/color_grade/services/color_grade_engine.dart';
import 'package:ai_video_generator/features/color_grade/models/color_grade_models.dart';

void main() {
  test('Generate UTSV3782_reference_matched and compare', () async {
    final refOrigFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483764674.jpg');
    final refGradFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483764740.jpg');
    final testInputFile = File('/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/.user_uploaded/media_1789483763685.jpg');

    final refOrigImg = img.decodeImage(refOrigFile.readAsBytesSync())!;
    final refGradImg = img.decodeImage(refGradFile.readAsBytesSync())!;
    final testInputImg = img.decodeImage(testInputFile.readAsBytesSync())!;

    final engine = ColorGradeEngine.instance;
    final profile = await engine.analyzeReferencePair(
      refOriginal: refOrigImg,
      refGraded: refGradImg,
    );

    final gradedOutput = engine.applyGrade(
      inputImage: testInputImg,
      profile: profile,
    );

    final outPath = '/Users/codekajugad/.gemini/antigravity/brain/d14b2b34-227d-446f-ae72-79387e16a3ad/scratch/UTSV3782_reference_matched.jpg';
    final outBytes = img.encodeJpg(gradedOutput, quality: 95);
    File(outPath).writeAsBytesSync(outBytes);

    print('Generated new UTSV3782_reference_matched.jpg: ${outBytes.length} bytes');

    // Measure stats of graded test image
    double rSum = 0, gSum = 0, bSum = 0;
    for (final p in gradedOutput) {
      rSum += p.r; gSum += p.g; bSum += p.b;
    }
    final n = gradedOutput.width * gradedOutput.height;
    print('UTSV3782 Graded Mean RGB: R=${(rSum/n).toStringAsFixed(1)}, G=${(gSum/n).toStringAsFixed(1)}, B=${(bSum/n).toStringAsFixed(1)}');
  });
}
