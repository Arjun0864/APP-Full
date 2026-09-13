import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  /// Requests storage/photos permission for saving exported images
  Future<bool> requestStoragePermission(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        // Android 13+ (API 33+) uses photos permission
        final photosStatus = await Permission.photos.status;
        if (photosStatus.isGranted) return true;

        final requestPhotos = await Permission.photos.request();
        if (requestPhotos.isGranted) return true;

        // Fallback for older Android
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) return true;

        final requestStorage = await Permission.storage.request();
        if (requestStorage.isGranted) return true;
      } else if (Platform.isIOS) {
        final status = await Permission.photos.status;
        if (status.isGranted || status.isLimited) return true;

        final request = await Permission.photos.request();
        if (request.isGranted || request.isLimited) return true;
      } else {
        // Desktop / macOS / Windows / Linux / Web does not require mobile permission
        return true;
      }
    } catch (e) {
      debugPrint('[PermissionService] Permission check error: $e');
      return true; // Fallback to allowing share
    }

    // Permission denied or permanently denied
    if (context.mounted) {
      _showPermissionDialog(context);
    }
    return false;
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Storage Permission Required',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Please grant storage permission in Settings to export graded photos to your device.',
          style: TextStyle(color: Color(0xFFB0B0D0), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B8A))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
