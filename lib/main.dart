import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/network/connectivity_service.dart';
import 'core/ads/admob_manager.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final appRouterWithNavKey = createAppRouter(navigatorKey: navigatorKey);

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error: $error');
    return true;
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp warning: $e');
  }

  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  if (isMobile) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('FirebaseMessaging background error: $e');
    }

    try {
      await AdMobManager.instance.initialize();
      AdMobManager.instance.loadInterstitialAd();
      AdMobManager.instance.loadRewardedAd();
    } catch (e) {
      debugPrint('AdMobManager error: $e');
    }

    // System UI
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // Portrait only on mobile
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(ProviderScope(overrides: [
    navigatorKeyProvider.overrideWithValue(navigatorKey),
  ], child: const AIVideoGeneratorApp()));
}

class AIVideoGeneratorApp extends ConsumerWidget {
  const AIVideoGeneratorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start connectivity monitoring
    ref.watch(connectivityProvider);

    // Ensure notification provider initializes
    ref.watch(notificationProvider);

    final themeState = ref.watch(themeProvider);
    AppColors.updateCurrentTheme(themeState);

    return MaterialApp.router(
      title: 'VisionAI',
      debugShowCheckedModeBanner: false,
      themeMode: themeState.themeMode,
      theme: AppTheme.getLightTheme(themeState.preset),
      darkTheme: AppTheme.getDarkTheme(themeState.preset),
      routerConfig: appRouterWithNavKey,
      builder: (context, child) {
        // Wrap every screen with offline banner
        return _AppWrapper(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

class _AppWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const _AppWrapper({required this.child});

  @override
  ConsumerState<_AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends ConsumerState<_AppWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateSystemUI();
      WidgetsBinding.instance.handleMetricsChanged();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _updateSystemUI() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? const Color(0xFF050505) : const Color(0xFFF6F7F9),
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  void didChangeMetrics() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateSystemUI();
    final isOnline = ref.watch(connectivityProvider);
    final theme = Theme.of(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          if (!isOnline)
            Material(
              color: const Color(0xFFEF4444),
              child: SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 7),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 13),
                      SizedBox(width: 7),
                      Text(
                        'No internet connection',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
