import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/color_grade_models.dart';

class ColorGradePersistence {
  ColorGradePersistence._();
  static final ColorGradePersistence instance = ColorGradePersistence._();

  static const _hiddenFileName = '.cg_session_data.bin';
  static const List<int> _xorKey = [0x7A, 0x3F, 0x91, 0xE4, 0x2B, 0x8C];

  Future<File> _getCacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_hiddenFileName');
  }

  List<int> _obfuscate(List<int> input) {
    final result = List<int>.filled(input.length, 0);
    for (int i = 0; i < input.length; i++) {
      result[i] = input[i] ^ _xorKey[i % _xorKey.length];
    }
    return result;
  }

  List<int> _deobfuscate(List<int> input) {
    return _obfuscate(input);
  }

  Future<void> saveColorGradeState(ColorGradeState state) async {
    try {
      final file = await _getCacheFile();
      final map = {
        'version': 2,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ref_raw_path': state.referenceRawPath,
        'ref_graded_path': state.referenceGradedPath,
        'profile': state.profile?.toJson(),
        'input_paths': state.batchItems.map((e) => e.sourcePath).toList(),
        'export_format': state.exportFormat.name,
        'jpeg_quality': state.jpegQuality,
      };

      final jsonStr = jsonEncode(map);
      final rawBytes = utf8.encode(jsonStr);
      final obfuscatedBytes = _obfuscate(rawBytes);
      final b64Str = base64Encode(obfuscatedBytes);

      await file.writeAsString(b64Str, flush: true);
    } catch (e) {
      debugPrint('[ColorGradePersistence] Save error: $e');
    }
  }

  Future<ColorGradeState?> loadColorGradeState() async {
    try {
      final file = await _getCacheFile();
      if (!await file.exists()) return null;

      final b64Str = await file.readAsString();
      if (b64Str.isEmpty) return null;

      final obfuscatedBytes = base64Decode(b64Str);
      final rawBytes = _deobfuscate(obfuscatedBytes);
      final jsonStr = utf8.decode(rawBytes);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      GradeProfile? profile;
      if (map['profile'] != null) {
        profile = GradeProfile.fromJson(map['profile'] as Map<String, dynamic>);
      }

      final inputPaths = (map['input_paths'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final batchItems = inputPaths.map((p) => ColorGradeItem(sourcePath: p)).toList();

      return ColorGradeState(
        referenceRawPath: map['ref_raw_path'] as String?,
        referenceGradedPath: map['ref_graded_path'] as String?,
        profile: profile,
        batchItems: batchItems,
        exportFormat: map['export_format'] == 'tiff' ? ExportFormat.tiff : ExportFormat.jpeg,
        jpegQuality: map['jpeg_quality'] as int? ?? 95,
        status: profile != null ? ColorGradeStatus.readyToBatch : ColorGradeStatus.idle,
      );
    } catch (e) {
      debugPrint('[ColorGradePersistence] Load error: $e');
      return null;
    }
  }

  Future<void> clearState() async {
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[ColorGradePersistence] Clear error: $e');
    }
  }
}
