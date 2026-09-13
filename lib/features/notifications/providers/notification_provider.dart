import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/secure_http_client.dart';
import '../../auth/providers/auth_provider.dart';

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref);
});

class NotificationState {
  final bool enabled;
  final String? token;
  final bool initialized;
  final String? error;
  NotificationState({this.enabled = false, this.token, this.initialized = false, this.error});

  NotificationState copyWith({bool? enabled, String? token, bool? initialized, String? error}) {
    return NotificationState(
      enabled: enabled ?? this.enabled,
      token: token ?? this.token,
      initialized: initialized ?? this.initialized,
      error: error,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final Ref _ref;
  StreamSubscription<String?>? _tokenSub;

  NotificationNotifier(this._ref) : super(NotificationState()) { 
    developer.log('NotificationNotifier: initializing', name: 'notifications');
    _init();

    // Listen to auth changes — register token after successful backend verify
    _ref.listen<AuthState>(authProvider, (previous, next) async {
      if (next.status == AuthStatus.authenticated && state.enabled) {
        developer.log('Auth changed → authenticated; registering token', name: 'notifications');
        await _registerTokenWithServer(state.token);
      }
      if (next.status == AuthStatus.unauthenticated) {
        developer.log('Auth changed → unauthenticated; unregistering token if present', name: 'notifications');
        // Optionally remove token from server when user logs out
        if (state.token != null) _unregisterTokenFromServer(state.token!);
      }
    });
  }

  Future<void> _init() async {
    try {
      final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
      if (!isMobile) {
        state = state.copyWith(initialized: true);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notifications_enabled') ?? true;
      state = state.copyWith(enabled: enabled);

      if (enabled) {
        developer.log('Notifications enabled — requesting permission and fetching token', name: 'notifications');
        final messaging = FirebaseMessaging.instance;
        await requestPermissionIfNeeded();
        final token = await messaging.getToken();
        developer.log('FCM token fetched: ${token ?? '<null>'}', name: 'notifications');
        state = state.copyWith(token: token, initialized: true);
        if (token != null) {
          await _registerTokenWithServer(token);
        }

        // Token refresh
        _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          developer.log('FCM token refreshed: $newToken', name: 'notifications');
          state = state.copyWith(token: newToken);
          await _registerTokenWithServer(newToken);
        });

        // Message handlers
        FirebaseMessaging.onMessage.listen((message) {
          developer.log('Foreground message received: ${message.messageId}', name: 'notifications');
          _handleForegroundMessage(message);
        });

        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          developer.log('Message opened app (background -> foreground): ${message.messageId}', name: 'notifications');
          _handleMessageTap(message);
        });

        // Initial message when app opened from terminated state
        FirebaseMessaging.instance.getInitialMessage().then((message) {
          if (message != null) {
            developer.log('App opened from terminated state via message: ${message.messageId}', name: 'notifications');
            _handleMessageTap(message);
          }
        });
      } else {
        state = state.copyWith(initialized: true);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> requestPermissionIfNeeded() async {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (!isMobile) return;
    final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    developer.log('Notification permission status: ${settings.authorizationStatus}', name: 'notifications');
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      state = state.copyWith(error: 'Notification permission denied');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    state = state.copyWith(enabled: enabled);
    developer.log('Notifications setEnabled -> $enabled', name: 'notifications');
    if (enabled) {
      final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
      if (isMobile) {
        await requestPermissionIfNeeded();
        final token = await FirebaseMessaging.instance.getToken();
        developer.log('Token after enabling notifications: ${token ?? '<null>'}', name: 'notifications');
        state = state.copyWith(token: token);
        if (token != null) await _registerTokenWithServer(token);
      }
    } else {
      if (state.token != null) await _unregisterTokenFromServer(state.token!);
    }
  }

  Future<void> _registerTokenWithServer(String? token) async {
    if (token == null) return;
    try {
      final platform = Theme.of(_ref.read(navigatorKeyProvider).currentContext!).platform == TargetPlatform.android ? 'android' : 'ios';
      developer.log('Registering token with backend: $token (platform: $platform)', name: 'notifications');
      await SecureHttpClient.instance.post('/user/fcm-token', body: {'token': token, 'platform': platform});
      developer.log('Token registered with backend successfully', name: 'notifications');
    } catch (e) {
      developer.log('Failed registering token with backend: $e', name: 'notifications');
      // ignore errors
    }
  }

  Future<void> _unregisterTokenFromServer(String token) async {
    try {
      developer.log('Unregistering token from backend: $token', name: 'notifications');
      await SecureHttpClient.instance.delete('/user/fcm-token', body: {'token': token});
      developer.log('Token unregistered from backend', name: 'notifications');
    } catch (e) {
      developer.log('Failed to unregister token: $e', name: 'notifications');
      // ignore
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    final ctx = _ref.read(navigatorKeyProvider).currentContext;
    if (ctx != null) {
      showDialog(
        context: ctx,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            TextButton(onPressed: () {
              Navigator.pop(ctx);
              _navigateFromMessageData(data, ctx);
            }, child: const Text('Open')),
          ],
        ),
      );
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    final ctx = _ref.read(navigatorKeyProvider).currentContext;
    if (ctx != null) _navigateFromMessageData(data, ctx);
  }

  void _navigateFromMessageData(Map<String, dynamic> data, BuildContext ctx) {
    final type = data['type'] as String? ?? '';
    if (type == 'image_ready') {
      // Open image hub/history
      GoRouter.of(ctx).go('/image-tools-hub');
    } else if (type == 'video_ready') {
      GoRouter.of(ctx).go('/my-videos');
    } else if (type == 'daily_reward') {
      GoRouter.of(ctx).go('/dashboard');
    }
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    super.dispose();
  }
}

// Provide navigator key via Riverpod so provider can access context
final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  throw UnimplementedError('navigatorKeyProvider must be overridden in main');
});
