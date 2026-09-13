import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/secure_http_client.dart';
import '../../../widgets/animated_input.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/glass_card.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  String? _newAvatarPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change Profile Picture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.photo_library_outlined,
                        color: AppColors.primaryLight),
                  ),
                  title: Text('Choose from Gallery',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _selectImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.camera_alt_outlined,
                        color: AppColors.primaryLight),
                  ),
                  title: Text('Take a Photo',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _selectImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (picked != null) {
        final docsDir = await getApplicationDocumentsDirectory();
        final ext = picked.path.split('.').last;
        final targetPath =
            '${docsDir.path}/profile_avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final savedFile = await File(picked.path).copy(targetPath);
        if (mounted) {
          setState(() {
            _newAvatarPath = savedFile.path;
          });
        }
      }
    } catch (e) {
      debugPrint('[EditProfile] Error picking image: $e');
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    final user = ref.read(authProvider).user;
    final finalAvatar = _newAvatarPath ?? user?.avatarUrl;

    // Update locally and persist
    await ref.read(authProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          avatarUrl: finalAvatar,
        );

    // Save to backend if available
    try {
      await SecureHttpClient.instance.patch(
        AppConfig.endpointUserProfile,
        body: {
          'name': _nameController.text.trim(),
          if (_newAvatarPath != null) 'avatar_url': _newAvatarPath,
        },
      );
    } catch (_) {}

    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Profile updated successfully'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    ImageProvider? avatarImage;
    if (_newAvatarPath != null && File(_newAvatarPath!).existsSync()) {
      avatarImage = FileImage(File(_newAvatarPath!));
    } else if (user?.avatarUrl.isNotEmpty == true) {
      if (user!.avatarUrl.startsWith('http')) {
        avatarImage = NetworkImage(user.avatarUrl);
      } else if (File(user.avatarUrl).existsSync()) {
        avatarImage = FileImage(File(user.avatarUrl));
      }
    }

    final initial = (user?.name.isNotEmpty == true)
        ? user!.name[0].toUpperCase()
        : 'U';

    final theme = context.appTheme;

    return Scaffold(
      backgroundColor: theme.background,
      body: Container(
        decoration: BoxDecoration(gradient: theme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.cardBorder),
                        ),
                        child: Icon(Icons.arrow_back_ios_new,
                            color: theme.textPrimary, size: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text('Edit Profile',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary)),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Avatar with tap to change
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.primaryGradient,
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: AppColors.surfaceLight,
                                backgroundImage: avatarImage,
                                child: avatarImage == null
                                    ? Text(
                                        initial,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 40,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.surface, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.camera_alt,
                                    color: Colors.white, size: 17),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 100.ms).scale(
                          begin: const Offset(0.9, 0.9)),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _pickAvatar,
                        child: Text(
                          'Change Profile Photo',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FULL NAME',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1)),
                            const SizedBox(height: 8),
                            AnimatedInput(
                              hint: 'Your full name',
                              controller: _nameController,
                              prefixIcon: Icon(Icons.person_outline,
                                  color: AppColors.textMuted, size: 18),
                            ),
                            const SizedBox(height: 20),
                            Text('EMAIL',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.email_outlined,
                                      color: AppColors.textMuted, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _emailController.text,
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: AppColors.textMuted),
                                    ),
                                  ),
                                  Icon(Icons.lock_outline,
                                      color: AppColors.textMuted, size: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 32),
                      GradientButton(
                        text: _isSaving ? 'Saving...' : 'Save Changes',
                        onPressed: _isSaving ? null : _save,
                        width: double.infinity,
                        height: 52,
                        gradientColors: [
                          AppColors.primary,
                          AppColors.secondary
                        ],
                      ).animate().fadeIn(delay: 300.ms),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
