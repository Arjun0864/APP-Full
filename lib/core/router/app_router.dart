import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/terms_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dashboard/presentation/templates_screen.dart';
import '../../features/generation/presentation/generating_screen.dart';
import '../../features/generation/presentation/video_generator_screen.dart';
import '../../features/generation/presentation/result_screen.dart';
import '../../features/generation/presentation/pre_generation_ads_screen.dart';
import '../../features/videos/presentation/my_videos_screen.dart';
import '../../features/credits/presentation/buy_credits_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/edit_profile_screen.dart';
import '../../features/settings/presentation/notifications_screen.dart';
import '../../features/referral/presentation/referral_screen.dart';
import '../../features/referral/presentation/apply_referral_screen.dart';
import '../../features/image_tools/presentation/image_tools_screen.dart';
import '../../features/image_tools/presentation/image_hub_screen.dart';
import '../../features/media_player/presentation/universal_video_player.dart';
import '../../features/media_player/presentation/universal_image_viewer.dart';
import '../../features/color_grade/presentation/color_grade_reference_screen.dart';
import '../../features/color_grade/presentation/color_grade_batch_screen.dart';
import '../../features/color_grade/presentation/color_grade_result_screen.dart';
import '../../features/desktop/presentation/desktop_shell.dart';
import '../../models/app_models.dart';
import '../../core/ads/ad_manager.dart';

GoRouter createAppRouter({GlobalKey<NavigatorState>? navigatorKey}) => GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    // Redirect handled inside splash screen after session restore
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => _buildPage(
        state,
        const SplashScreen(),
        transitionType: _TransitionType.fade,
      ),
    ),
    GoRoute(
      path: '/terms',
      pageBuilder: (context, state) => _buildPage(
        state,
        const TermsScreen(),
        transitionType: _TransitionType.slideUp,
      ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _buildPage(
        state,
        const LoginScreen(),
        transitionType: _TransitionType.fadeSlide,
      ),
    ),

    // ── Shell-wrapped main navigation routes ──────────────────────────────
    // On desktop: AppShell renders DesktopShell (persistent top TabBar,
    //   no bottom nav). Each child screen returns its body content only.
    // On mobile: AppShell passes through child unchanged (each screen has
    //   its own Scaffold + BottomNavBar).
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => _buildPage(
            state,
            const DashboardScreen(),
            transitionType: _TransitionType.fadeSlide,
          ),
        ),
        GoRoute(
          path: '/video-generator',
          pageBuilder: (context, state) => _buildPage(
            state,
            const VideoGeneratorScreen(),
            transitionType: _TransitionType.fadeSlide,
          ),
        ),
        GoRoute(
          path: '/my-videos',
          pageBuilder: (context, state) => _buildPage(
            state,
            const MyVideosScreen(),
            transitionType: _TransitionType.slideRight,
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _buildPage(
            state,
            const SettingsScreen(),
            transitionType: _TransitionType.slideRight,
          ),
        ),
        GoRoute(
          path: '/image-tools-hub',
          pageBuilder: (context, state) => _buildPage(
            state,
            const ImageHubScreen(),
            transitionType: _TransitionType.fadeSlide,
          ),
        ),
      ],
    ),

    GoRoute(
      path: '/pre-gen-ads',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final prompt = extra?['prompt'] as String? ?? state.extra as String? ?? '';
        final genType = extra?['generationType'] as GenerationType? ?? GenerationType.video;
        return _buildPage(
          state,
          PreGenerationAdsScreen(prompt: prompt, generationType: genType),
          transitionType: _TransitionType.scaleUp,
        );
      },
    ),
    GoRoute(
      path: '/generating',
      pageBuilder: (context, state) => _buildPage(
        state,
        const GeneratingScreen(),
        transitionType: _TransitionType.scaleUp,
      ),
    ),
    GoRoute(
      path: '/result',
      pageBuilder: (context, state) => _buildPage(
        state,
        ResultScreen(video: state.extra as VideoModel?),
        transitionType: _TransitionType.slideUp,
      ),
    ),
    GoRoute(
      path: '/templates',
      pageBuilder: (context, state) => _buildPage(
        state,
        const TemplatesScreen(),
        transitionType: _TransitionType.slideRight,
      ),
    ),
    GoRoute(
      path: '/paywall',
      pageBuilder: (context, state) => _buildPage(
        state,
        const BuyCreditsScreen(),
        transitionType: _TransitionType.slideUp,
      ),
    ),
    GoRoute(
      path: '/buy-credits',
      pageBuilder: (context, state) => _buildPage(
        state,
        const BuyCreditsScreen(),
        transitionType: _TransitionType.slideUp,
      ),
    ),
    GoRoute(
      path: '/edit-profile',
      pageBuilder: (context, state) => _buildPage(
        state,
        const EditProfileScreen(),
        transitionType: _TransitionType.slideRight,
      ),
    ),
    GoRoute(
      path: '/notifications',
      pageBuilder: (context, state) => _buildPage(
        state,
        const NotificationsScreen(),
        transitionType: _TransitionType.slideRight,
      ),
    ),
    GoRoute(
      path: '/referral',
      pageBuilder: (context, state) => _buildPage(
        state,
        const ReferralScreen(),
        transitionType: _TransitionType.slideRight,
      ),
    ),
    GoRoute(
      path: '/referral/apply',
      pageBuilder: (context, state) => _buildPage(
        state,
        const ApplyReferralScreen(),
        transitionType: _TransitionType.slideRight,
      ),
    ),
    GoRoute(
      path: '/image-tools',
      pageBuilder: (context, state) => _buildPage(
        state,
        ImageToolsScreen(tool: state.extra as String? ?? 'generate'),
        transitionType: _TransitionType.slideRight,
      ),
    ),
    GoRoute(
      path: '/video-player',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return _buildPage(
          state,
          UniversalVideoPlayer(
            filePath: extra?['filePath'] as String?,
            networkUrl: extra?['networkUrl'] as String?,
            title: extra?['title'] as String?,
            autoPlay: extra?['autoPlay'] as bool? ?? true,
          ),
          transitionType: _TransitionType.slideUp,
        );
      },
    ),
    GoRoute(
      path: '/image-viewer',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final images = extra?['images'] as List<ImageSource>?;
        final singlePath = extra?['filePath'] as String?;
        final singleUrl = extra?['networkUrl'] as String?;
        final title = extra?['title'] as String?;
        final initialIndex = extra?['initialIndex'] as int? ?? 0;

        List<ImageSource> sourceList;
        if (images != null && images.isNotEmpty) {
          sourceList = images;
        } else if (singlePath != null) {
          sourceList = [ImageSource.file(singlePath)];
        } else if (singleUrl != null) {
          sourceList = [ImageSource.network(singleUrl)];
        } else {
          sourceList = [];
        }

        return _buildPage(
          state,
          sourceList.isEmpty
              ? const Scaffold(body: Center(child: Text('No image provided')))
              : UniversalImageViewer(
                  images: sourceList,
                  initialIndex: initialIndex,
                  title: title,
                ),
          transitionType: _TransitionType.slideUp,
        );
      },
    ),
    GoRoute(
      path: '/color-grade',
      pageBuilder: (context, state) => _buildPage(
        state,
        const ColorGradeReferenceScreen(),
        transitionType: _TransitionType.slideRight,
      ),
    ),
    GoRoute(
      path: '/color-grade/batch',
      pageBuilder: (context, state) => _buildPage(
        state,
        const ColorGradeBatchScreen(),
        transitionType: _TransitionType.slideRight,
      ),
    ),
    GoRoute(
      path: '/color-grade/result',
      pageBuilder: (context, state) => _buildPage(
        state,
        const ColorGradeResultScreen(),
        transitionType: _TransitionType.slideUp,
      ),
    ),
  ],
);

final appRouter = createAppRouter();

enum _TransitionType { fade, fadeSlide, slideRight, slideUp, scaleUp }

CustomTransitionPage _buildPage(
  GoRouterState state,
  Widget child, {
  _TransitionType transitionType = _TransitionType.fadeSlide,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      switch (transitionType) {
        case _TransitionType.fade:
          return FadeTransition(opacity: curved, child: child);

        case _TransitionType.fadeSlide:
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );

        case _TransitionType.slideRight:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );

        case _TransitionType.slideUp:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );

        case _TransitionType.scaleUp:
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
              child: child,
            ),
          );
      }
    },
  );
}
