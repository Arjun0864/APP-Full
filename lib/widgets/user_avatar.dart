import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/app_models.dart';

class UserAvatar extends StatelessWidget {
  final UserModel? user;
  final double radius;
  final VoidCallback? onTap;
  final bool showBorder;

  const UserAvatar({
    super.key,
    this.user,
    this.radius = 20,
    this.onTap,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatarUrl ?? '';
    final name = user?.name ?? 'Creator';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    ImageProvider? imageProvider;
    if (avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
        imageProvider = NetworkImage(avatarUrl);
      } else {
        final file = File(avatarUrl);
        if (file.existsSync()) {
          imageProvider = FileImage(file);
        }
      }
    }

    final avatarWidget = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.6),
                width: 1.5,
              )
            : null,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceLight,
        backgroundImage: imageProvider,
        child: imageProvider == null
            ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: radius * 0.9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatarWidget);
    }
    return avatarWidget;
  }
}
