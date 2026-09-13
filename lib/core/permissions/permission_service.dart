import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized permission management.
/// Handles all app permissions with proper rationale dialogs.
///
/// Android permission tiers:
///   API 34+ (Android 14): READ_MEDIA_VISUAL_USER_SELECTED (partial access)
///   API 33  (Android 13): READ_MEDIA_IMAGES + READ_MEDIA_VIDEO (granular)
///   API 32- (Android 12-): READ_EXTERNAL_STORAGE (legacy)
///
/// iOS:
///   Photos: NSPhotoLibraryUsageDescription
///   Camera: NSCameraUsageDescription
///   Microphone: NSMicrophoneUsageDescription
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  // ── Request permissions ───────────────────────────────────────────────────

  /// Request storage/media permissions for reading files.
  /// Handles Android 14 partial access, Android 13 granular, and legacy.
  Future<bool> requestMediaPermission(BuildContext context) async {
    if (Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkVersion();

      if (sdkInt >= 34) {
        // Android 14+: try full access first, fall back to partial
        final images = await Permission.photos.request();
        final videos = await Permission.videos.request();

        if (images.isGranted && videos.isGranted) return true;

        // Partial access (user selected specific photos)
        if (images.isLimited || videos.isLimited) return true;

        if (images.isPermanentlyDenied || videos.isPermanentlyDenied) {
          if (context.mounted) {
            await _showSettingsDialog(
              context,
              title: 'Media Access Required',
              message:
                  'VisionAI needs access to your photos and videos to select '
                  'images for AI processing and save generated content. '
                  'Please enable in Settings → Apps → VisionAI → Permissions.',
            );
          }
          return false;
        }
        return false;
      } else if (sdkInt >= 33) {
        // Android 13: granular media permissions
        final images = await Permission.photos.request();
        final videos = await Permission.videos.request();

        if (images.isPermanentlyDenied || videos.isPermanentlyDenied) {
          if (context.mounted) {
            await _showSettingsDialog(
              context,
              title: 'Media Access Required',
              message:
                  'VisionAI needs access to your photos and videos. '
                  'Please enable in Settings.',
            );
          }
        }
        return images.isGranted && videos.isGranted;
      } else {
        // Android 12 and below: legacy storage permission
        final storage = await Permission.storage.request();
        if (storage.isPermanentlyDenied && context.mounted) {
          await _showSettingsDialog(
            context,
            title: 'Storage Access Required',
            message:
                'VisionAI needs storage access to read and save media files. '
                'Please enable in Settings.',
          );
        }
        return storage.isGranted;
      }
    } else if (Platform.isIOS) {
      final photos = await Permission.photos.request();
      if (photos.isPermanentlyDenied && context.mounted) {
        await _showSettingsDialog(
          context,
          title: 'Photo Library Access Required',
          message:
              'VisionAI needs access to your photo library to select images '
              'and save generated content. Please enable in Settings.',
        );
      }
      // Limited access (user selected specific photos) is also acceptable
      return photos.isGranted || photos.isLimited;
    }
    return true;
  }

  /// Request camera permission
  Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied && context.mounted) {
      await _showSettingsDialog(
        context,
        title: 'Camera Permission Required',
        message:
            'Camera access is needed to capture photos and videos for AI '
            'processing. Please enable it in Settings.',
      );
    }
    return status.isGranted;
  }

  /// Request microphone permission (for video recording)
  Future<bool> requestMicrophonePermission(BuildContext context) async {
    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied && context.mounted) {
      await _showSettingsDialog(
        context,
        title: 'Microphone Permission Required',
        message:
            'Microphone access is needed to record audio with videos. '
            'Please enable it in Settings.',
      );
    }
    return status.isGranted;
  }

  /// Request notification permission (Android 13+, iOS)
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Check if media permission is granted (without requesting)
  Future<bool> hasMediaPermission() async {
    if (Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkVersion();
      if (sdkInt >= 33) {
        final images = await Permission.photos.status;
        final videos = await Permission.videos.status;
        return (images.isGranted || images.isLimited) &&
            (videos.isGranted || videos.isLimited);
      }
      return await Permission.storage.status.then((s) => s.isGranted);
    } else if (Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  /// Request all permissions needed at app startup (non-blocking)
  Future<void> requestStartupPermissions(BuildContext context) async {
    // Notification permission — ask once, non-blocking
    await requestNotificationPermission();
  }

  /// Request media + camera permissions together (for image picker)
  Future<bool> requestImagePickerPermissions(BuildContext context) async {
    final media = await requestMediaPermission(context);
    // Camera is optional for image picker (user can choose gallery only)
    return media;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<int> _getAndroidSdkVersion() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return 33; // Safe default — Android 13
    }
  }

  Future<void> _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Not Now',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(
                  color: Color(0xFF7C3AED), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
