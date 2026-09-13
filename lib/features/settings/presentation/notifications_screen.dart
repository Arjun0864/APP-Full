import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notifications/providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Map<String, bool> _settings = {
    'video_ready': true,
    'credits_low': true,
    'new_features': false,
    'weekly_digest': true,
    'promotions': false,
    'tips': true,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
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
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Icon(Icons.arrow_back_ios_new,
                            color: AppColors.textPrimary, size: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text('Notifications',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
              // Top-level enable switch
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Consumer(builder: (context, ref, _) {
                  final notifState = ref.watch(notificationProvider);
                  return GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Enable Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        Switch(
                          value: notifState.enabled,
                          onChanged: (v) => ref.read(notificationProvider.notifier).setEnabled(v),
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 8),
                    _buildSection('Activity', [
                      const _NotifItem('video_ready', Icons.video_library_outlined,
                          'Video Ready', 'When your video finishes generating'),
                      const _NotifItem('credits_low', Icons.bolt_outlined,
                          'Low Credits', 'When you have less than 5 credits'),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Updates', [
                      const _NotifItem('new_features', Icons.new_releases_outlined,
                          'New Features', 'Product updates and new tools'),
                      const _NotifItem('weekly_digest', Icons.calendar_today_outlined,
                          'Weekly Digest', 'Summary of your creations'),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Marketing', [
                      const _NotifItem('promotions', Icons.local_offer_outlined,
                          'Promotions', 'Special offers and discounts'),
                      const _NotifItem('tips', Icons.lightbulb_outlined,
                          'Tips & Tricks', 'Get the most out of VisionAI'),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<_NotifItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.2),
          ),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.icon,
                              color: AppColors.textSecondary, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.label,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500)),
                              Text(item.desc,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _settings[item.key] ?? false,
                          onChanged: (v) =>
                              setState(() => _settings[item.key] = v),
                          activeThumbColor: AppColors.primary,
                          activeTrackColor:
                              AppColors.primary.withValues(alpha: 0.3),
                          inactiveThumbColor: AppColors.textMuted,
                          inactiveTrackColor:
                              AppColors.surfaceLight,
                        ),
                      ],
                    ),
                  ),
                  if (index < items.length - 1)
                    Divider(
                        height: 1,
                        color: AppColors.cardBorder,
                        indent: 66),
                ],
              );
            }).toList(),
          ),
        ).animate().fadeIn(delay: 100.ms),
      ],
    );
  }
}

class _NotifItem {
  final String key;
  final IconData icon;
  final String label;
  final String desc;
  const _NotifItem(this.key, this.icon, this.label, this.desc);
}
