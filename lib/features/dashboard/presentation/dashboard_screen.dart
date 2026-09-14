import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/app_models.dart';
import '../../../widgets/animated_input.dart';
import '../../../widgets/user_avatar.dart';
import '../../prompts/presentation/saved_prompts_screen.dart';
import '../../prompts/providers/prompt_provider.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/shining_button.dart';
import '../../../core/ads/ad_manager.dart';
import '../../../core/ads/admob_manager.dart';
import '../../../core/network/connectivity_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../videos/providers/videos_provider.dart';
import '../../desktop/presentation/desktop_color_grade_studio.dart';
import 'app_drawer.dart';
import 'bottom_nav_bar.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  final _promptController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _bgController;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    // Preload ads so they're ready when user hits generate (mobile only)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      AdMobManager.instance.loadInterstitialAd();
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _bgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a prompt first'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Check internet connectivity
    final online = await ConnectivityService.instance.requireInternet(
      context,
      featureName: 'AI Video Generation',
    );
    if (!online) return;

    // Navigate directly to ads before generating
    if (!mounted) return;
    context.push('/pre-gen-ads', extra: {
      'prompt': prompt,
      'generationType': GenerationType.video,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopPlatform = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    // On desktop, AppShell (ShellRoute) already provides DesktopShell —
    // just render the color grade studio content directly.
    if (isDesktopPlatform || (!kIsWeb && MediaQuery.of(context).size.width >= 800)) {
      return const DesktopColorGradeStudio();
    }

    final user = ref.watch(authProvider).user;
    final recentVideos = ref.watch(currentUserVideosProvider).take(6).toList();
    final theme = context.appTheme;

    return Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.background,
        drawer: const AppDrawer(),
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: BoxDecoration(gradient: theme.backgroundGradient),
          child: Stack(
            children: [
              _buildBackgroundOrbs(),
              Column(
                children: [
                  Expanded(
                    child: SafeArea(
                      bottom: false,
                      child: RefreshIndicator(
                        onRefresh: () async =>
                            await Future.delayed(const Duration(milliseconds: 1000)),
                        color: theme.primary,
                        backgroundColor: theme.surface,
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(child: _buildAppBar(user)),
                            SliverToBoxAdapter(child: _buildGreeting(user)),
                            SliverToBoxAdapter(child: _buildRecentVideos(recentVideos)),
                            const SliverToBoxAdapter(child: SizedBox(height: 200)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildPromptBox(),
                  const BottomNavBar(currentIndex: 0),
                ],
              ),
            ],
          ),
        ),
      );
  }

  // ── Background orbs ────────────────────────────────────────────────────

  Widget _buildBackgroundOrbs() {
    final theme = context.appTheme;
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: -100 + (_bgController.value * 30),
              right: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.primary.withValues(alpha: theme.isLight ? 0.08 : 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: 100 - (_bgController.value * 20),
              left: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.accent.withValues(alpha: theme.isLight ? 0.06 : 0.1),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────

  Widget _buildAppBar(UserModel? user) {
    final theme = context.appTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.cardBorder),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.menu_rounded,
                        color: theme.textPrimary, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                ShaderMask(
                  shaderCallback: (b) =>
                      theme.primaryGradient.createShader(b),
                  child: const Text(
                    'VisionAI',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
                const Spacer(),
                UserAvatar(
                  user: user,
                  radius: 20,
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3);
  }

  // ── Greeting ───────────────────────────────────────────────────────────

  Widget _buildGreeting(UserModel? user) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final emoji = hour < 12 ? '☀️' : hour < 17 ? '👋' : '🌙';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, ${user?.name.split(' ').first ?? 'Creator'} $emoji',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2),
          const SizedBox(height: 6),
          Text(
            'What will you create today?',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 20),
          // Stats row
          Row(
            children: [
              _statPill(Icons.video_library_outlined,
                  '${user?.totalVideos ?? 0} creations'),
              const SizedBox(width: 10),
              _planPill(user?.plan ?? PlanType.free),
            ],
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _planPill(PlanType plan) {
    final colors = plan == PlanType.ultra
        ? [const Color(0xFFEC4899), const Color(0xFF7C3AED)]
        : plan == PlanType.pro
            ? [AppColors.primary, AppColors.secondary]
            : [AppColors.surfaceLight, AppColors.surfaceLight];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        plan.name.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
      ),
    );
  }

  // ── Recent Videos ──────────────────────────────────────────────────────

  Widget _buildRecentVideos(List<VideoModel> videos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Creations',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              GestureDetector(
                onTap: () => context.push('/my-videos'),
                child: Text('See all',
                    style: TextStyle(
                        color: AppColors.primaryLight, fontSize: 14)),
              ),
            ],
          ),
        ),
        if (videos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.image_outlined,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 14),
                    Text('No creations yet',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Describe your idea below to get started',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: videos.length,
            itemBuilder: (context, index) =>
                _buildVideoCard(videos[index], index),
          ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildVideoCard(VideoModel video, int index) {
    return GestureDetector(
      onTap: () => context.push('/result', extra: video),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                video.thumbnailUrl,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceLight,
                  child: Icon(
                    video.duration == Duration.zero
                        ? Icons.image_outlined
                        : Icons.video_library,
                    color: AppColors.textMuted,
                    size: 32,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75)
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  video.prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const Center(
                child: Icon(Icons.play_circle_outline,
                    color: Colors.white60, size: 32),
              ),
              if (video.hasWatermark)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('WM',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (400 + index * 60).ms)
        .scale(begin: const Offset(0.95, 0.95));
  }

  // ── Prompt box (pinned above navbar) ───────────────────────────────────

  Widget _buildPromptBox() {
    final theme = context.appTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: theme.isLight ? 0.96 : 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withValues(alpha: theme.isLight ? 0.08 : 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label
                Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          theme.primaryGradient.createShader(b),
                      child: const Text(
                        'Describe your image',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'AI Prompt',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Text input with save/open prompt buttons
                Row(
                  children: [
                    Expanded(
                      child: AnimatedInput(
                        hint: 'A majestic dragon flying over a medieval castle at sunset...',
                        controller: _promptController,
                        maxLines: 3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        IconButton(
                          tooltip: 'Save prompt',
                          onPressed: () async {
                            final current = _promptController.text.trim();
                            if (current.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Prompt is empty'), backgroundColor: AppColors.error),
                              );
                              return;
                            }
                            final titleController = TextEditingController();
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Save Prompt'),
                                content: TextField(controller: titleController, decoration: const InputDecoration(hintText: 'Enter a title')),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
                                ],
                              ),
                            );
                            if (ok == true && mounted) {
                              final title = titleController.text.trim();
                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Title is required'), backgroundColor: AppColors.error),
                                );
                                return;
                              }
                              final created = await ref.read(promptProvider.notifier).createPrompt(title, current);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(created ? 'Prompt saved' : 'Failed to save prompt'), backgroundColor: created ? AppColors.success : AppColors.error));
                            }
                          },
                          icon: const Icon(Icons.bookmark_add_outlined),
                        ),
                        IconButton(
                          tooltip: 'Saved prompts',
                          onPressed: () async {
                            final result = await Navigator.push<String?>(
                              context,
                              MaterialPageRoute(builder: (_) => const SavedPromptsScreen()),
                            );
                            if (result != null && result.isNotEmpty) {
                              _promptController.text = result;
                            }
                          },
                          icon: const Icon(Icons.storage_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Bottom row with Shining Button
                ShiningButton(
                  text: 'Generate Image',
                  onPressed: _generate,
                  height: 48,
                  width: double.infinity,
                  gradientColors: theme.accentGradient.colors,
                  icon: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3);
  }
}
