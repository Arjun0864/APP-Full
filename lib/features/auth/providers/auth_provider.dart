import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/secure_http_client.dart';
import '../../../core/security/token_storage.dart';
import '../../../models/app_models.dart';
import '../../../features/videos/providers/videos_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Auth Flow:
//
// 1. User Firebase se login karta hai (Google/Email/Apple)
// 2. Firebase ID Token milta hai
// 3. Backend ko /auth/verify call karte hain token ke saath
// 4. Backend user create/fetch karta hai PostgreSQL se
// 5. User data Riverpod state mein store hota hai
// 6. Secure storage mein session save hota hai (Android Keystore / iOS Keychain)
//
// Local SQLite NAHI hai — sab data backend se aata hai.
// ─────────────────────────────────────────────────────────────────────────────

enum AuthStatus { initial, loading, authenticated, unauthenticated, error, verificationPending }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState(status: AuthStatus.initial)) {
    _init();
  }

  final _firebaseAuth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn(
    serverClientId: AppConfig.googleWebClientId,
    scopes: ['email', 'profile'],
  );

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> _init() async {
    // ── TEMPORARILY COMMENTED OUT FOR TESTING DIRECT APP ACCESS ──
    // final existingUser = _firebaseAuth.currentUser;
    // if (existingUser != null) {
    //   state = AuthState(
    //     status: AuthStatus.authenticated,
    //     user: _userFromFirebase(existingUser),
    //   );
    //   _applyCachedProfile(existingUser.uid);
    //   // Sync in background
    //   Future(() => _syncFromBackend(existingUser.uid, existingUser)).ignore();
    // } else {
    //   state = const AuthState(status: AuthStatus.unauthenticated);
    // }
    //
    // _firebaseAuth.authStateChanges().listen((firebaseUser) async {
    //   if (firebaseUser == null) {
    //     if (state.status != AuthStatus.loading &&
    //         state.status != AuthStatus.verificationPending) {
    //       state = const AuthState(status: AuthStatus.unauthenticated);
    //     }
    //     return;
    //   }
    //   if (state.status == AuthStatus.authenticated ||
    //       state.status == AuthStatus.loading ||
    //       state.status == AuthStatus.verificationPending) {
    //     return;
    //   }
    //
    //   state = AuthState(
    //     status: AuthStatus.authenticated,
    //     user: _userFromFirebase(firebaseUser),
    //   );
    //   Future(() => _syncFromBackend(firebaseUser.uid, firebaseUser)).ignore();
    // });
    // ─────────────────────────────────────────────────────────────

    // Direct guest/creator user for testing without login
    const defaultUser = UserModel(
      id: 'guest_user',
      email: 'creator@visionai.app',
      name: 'Creator',
      avatarUrl: '',
      plan: PlanType.pro,
      credits: 100,
      totalVideos: 12,
    );
    state = const AuthState(
      status: AuthStatus.authenticated,
      user: defaultUser,
    );
    _applyCachedProfile('guest_user');
  }

  Future<void> _syncFromBackend(String uid, User firebaseUser) async {
    try {
      // Backend ko verify call karo — user create/fetch hoga PostgreSQL mein
      final response = await SecureHttpClient.instance.post(
        AppConfig.endpointAuthVerify,
      ).timeout(const Duration(seconds: 10));

      if (response.success && response.data != null) {
        final userData = response.data as Map<String, dynamic>;

        // Secure storage mein cache karo
        await TokenStorage.instance.saveUserData(jsonEncode(userData));
        await TokenStorage.instance.setSessionActive(true);

        // State update karo only if still authenticated
        if (state.status == AuthStatus.authenticated) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: _userFromBackend(userData, uid, firebaseUser),
          );
        }
      } else if (response.isUnauthorized) {
        // Token expire — but don't logout immediately, try refreshing token
        try {
          await TokenStorage.instance.forceRefreshToken();
          // Retry once with fresh token
          final retryResponse = await SecureHttpClient.instance.post(
            AppConfig.endpointAuthVerify,
          ).timeout(const Duration(seconds: 10));
          
          if (retryResponse.success && retryResponse.data != null) {
            final userData = retryResponse.data as Map<String, dynamic>;
            await TokenStorage.instance.saveUserData(jsonEncode(userData));
            await TokenStorage.instance.setSessionActive(true);
            if (state.status == AuthStatus.authenticated) {
              state = AuthState(
                status: AuthStatus.authenticated,
                user: _userFromBackend(userData, uid, firebaseUser),
              );
            }
          }
        } catch (_) {
          // Still failed — user stays authenticated with Firebase data
          debugPrint('[Auth] Backend verify retry failed — using Firebase data');
        }
      }
    } catch (e) {
      // Backend unreachable — continue with Firebase user data
      // User can still use the app with basic features
      debugPrint('[Auth] Backend sync failed: $e — using Firebase user data');
    }
  }

  // ── Email/Password Login ──────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Login failed. Please try again.',
        );
        return false;
      }

      // Reload user to get fresh emailVerified status
      try {
        await user.reload();
      } catch (_) {
        // reload failed (network issue) — use cached emailVerified
      }

      // Get fresh reference after reload
      final freshUser = _firebaseAuth.currentUser ?? user;

      // ── Email verification check ──────────────────────────────────────────
      // Block login if email is not verified (only for email/password accounts)
      if (!freshUser.emailVerified) {
        // Sign out so they can't bypass the check
        await _firebaseAuth.signOut();
        state = state.copyWith(
          status: AuthStatus.verificationPending,
          error: null,
        );
        return false;
      }

      // Set authenticated state immediately
      state = AuthState(
        status: AuthStatus.authenticated,
        user: _userFromFirebase(freshUser),
      );

      // Sync with backend in background (don't block login)
      Future(() => _syncFromBackend(freshUser.uid, freshUser)).ignore();

      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _firebaseErrorMessage(e.code),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Login failed. Please try again.',
      );
      return false;
    }
  }

  // ── Email/Password Signup (with email verification) ──────────────────────

  Future<bool> signup(String name, String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      // Check if email already exists by attempting sign-in (Firebase doesn't
      // expose a direct "email exists" check without creating the account)
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Display name set karo
      await credential.user?.updateDisplayName(name);

      // Send email verification — account is created but user must verify
      await credential.user?.sendEmailVerification();

      // Sign out immediately — user must verify email before logging in
      await _firebaseAuth.signOut();

      // Set state to show verification pending (not authenticated)
      state = const AuthState(
        status: AuthStatus.verificationPending,
        error: null,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _firebaseErrorMessage(e.code),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Account could not be created. Please try again.',
      );
      return false;
    }
  }

  // ── Resend verification email ─────────────────────────────────────────────

  Future<bool> resendVerificationEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user?.emailVerified == false) {
        await credential.user?.sendEmailVerification();
        await _firebaseAuth.signOut();
        return true;
      }
      await _firebaseAuth.signOut();
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Google Sign In ────────────────────────────────────────────────────────

  Future<bool> loginWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return false;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Google sign-in failed. Could not retrieve Firebase user credentials.',
        );
        return false;
      }

      debugPrint('[Auth] Google sign-in successful for Firebase user: ${user.uid}');

      // Set authenticated immediately — don't block on backend/storage
      state = AuthState(
        status: AuthStatus.authenticated,
        user: _userFromFirebase(user),
      );

      // Sync with backend in background
      Future(() => _syncFromBackend(user.uid, user)).ignore();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] FirebaseAuthException in Google sign-in: ${e.code} - ${e.message}');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _firebaseErrorMessage(e.code),
      );
      return false;
    } catch (e) {
      debugPrint('[Auth] Exception in Google sign-in: $e');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Google sign-in failed. Please check network and try again.',
      );
      return false;
    }
  }

  // ── Apple Sign In (App Store ke liye zaroori) ─────────────────────────────

  Future<bool> loginWithApple() async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final appleProvider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('fullName');
      final userCredential = await _firebaseAuth.signInWithProvider(appleProvider);
      final user = userCredential.user;
      if (user == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Apple sign-in failed.',
        );
        return false;
      }

      // Set authenticated immediately — don't block on backend/storage
      state = AuthState(
        status: AuthStatus.authenticated,
        user: _userFromFirebase(user),
      );

      // Sync with backend in background
      Future(() => _syncFromBackend(user.uid, user)).ignore();
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _firebaseErrorMessage(e.code),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Apple sign-in failed. Please try again.',
      );
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final uid = _firebaseAuth.currentUser?.uid ?? '';

    // Firebase logout
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();

    // Secure storage clear karo (cached user data + session)
    await TokenStorage.instance.clearAll();

    // Clear user-scoped video history so next user can't see it
    if (uid.isNotEmpty) {
      try {
        _ref.read(videosProvider(uid).notifier).state = [];
      } catch (_) {}
    }
    try {
      _ref.read(currentUserVideosProvider.notifier).state = [];
    } catch (_) {}

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // ── State updates (optimistic — backend se sync hoga) ────────────────────

  void deductCredit({int amount = 1}) {
    if (state.user == null) return;
    final newCredits = (state.user!.credits - amount).clamp(0, 999999);
    state = AuthState(
      status: AuthStatus.authenticated,
      user: state.user!.copyWith(
        credits: newCredits,
        totalVideos: state.user!.totalVideos + 1,
      ),
    );
    // Sync with backend to get real balance
    _refreshUserData();
  }

  void upgradePlan(PlanType plan) {
    if (state.user == null) return;
    final credits = plan == PlanType.pro
        ? 50
        : plan == PlanType.ultra
            ? 999
            : 5;
    state = state.copyWith(
      user: state.user!.copyWith(plan: plan, credits: credits),
    );
    _refreshUserData();
  }

  Future<void> updateProfile({String? name, String? email, String? avatarUrl}) async {
    if (state.user == null) return;
    final updated = state.user!.copyWith(
      name: name ?? state.user!.name,
      email: email ?? state.user!.email,
      avatarUrl: avatarUrl ?? state.user!.avatarUrl,
    );
    state = state.copyWith(user: updated);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        await prefs.setString('custom_user_avatar_${updated.id}', avatarUrl);
      }
      if (name != null && name.isNotEmpty) {
        await prefs.setString('custom_user_name_${updated.id}', name);
      }
    } catch (_) {}
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Return from the "Verify Your Email" screen back to the login form.
  /// (verificationPending is now a stable state, so it must be exited
  /// explicitly.)
  void backToLogin() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Public method to refresh user data from backend
  Future<void> refreshUserData() async {
    await _refreshUserData();
  }

  /// Add credits optimistically (for rewarded ads)
  void addCredits(int amount) {
    if (state.user == null) return;
    state = state.copyWith(
      user: state.user!.copyWith(
        credits: state.user!.credits + amount,
      ),
    );
  }

  /// Backend se fresh user data lo aur state update karo
  Future<void> _refreshUserData() async {
    try {
      final response = await SecureHttpClient.instance.get(
        AppConfig.endpointAuthMe,
      );
      if (response.success && response.data != null) {
        final userData = response.data as Map<String, dynamic>;
        final firebaseUser = _firebaseAuth.currentUser;
        if (firebaseUser != null) {
          await TokenStorage.instance.saveUserData(jsonEncode(userData));
          state = state.copyWith(
            user: _userFromBackend(
                userData, firebaseUser.uid, firebaseUser),
          );
        }
      }
    } catch (_) {
      // Fail silently — optimistic update already applied
    }
  }

  Future<void> _applyCachedProfile(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedAvatar = prefs.getString('custom_user_avatar_$uid');
      final cachedName = prefs.getString('custom_user_name_$uid');
      if (state.user != null && (cachedAvatar != null || cachedName != null)) {
        state = state.copyWith(
          user: state.user!.copyWith(
            avatarUrl: cachedAvatar ?? state.user!.avatarUrl,
            name: cachedName ?? state.user!.name,
          ),
        );
      }
    } catch (_) {}
  }

  // ── Model helpers ─────────────────────────────────────────────────────────

  UserModel _userFromBackend(
      Map<String, dynamic> m, String uid, User firebaseUser) {
    return UserModel(
      id: uid,
      name: m['name'] as String? ?? firebaseUser.displayName ?? 'User',
      email: m['email'] as String? ?? firebaseUser.email ?? '',
      avatarUrl: m['avatar_url'] as String? ??
          firebaseUser.photoURL ??
          'https://i.pravatar.cc/150?img=3',
      plan: _parsePlan(m['plan'] as String? ?? 'free'),
      credits: (m['credits'] as int?) ?? 5,
      totalVideos: (m['total_videos'] as int?) ?? 0,
    );
  }

  UserModel _userFromFirebase(User firebaseUser) {
    return UserModel(
      id: firebaseUser.uid,
      name: firebaseUser.displayName ?? 'User',
      email: firebaseUser.email ?? '',
      avatarUrl:
          firebaseUser.photoURL ?? 'https://i.pravatar.cc/150?img=3',
      plan: PlanType.free,
      credits: 5,
      totalVideos: 0,
    );
  }

  PlanType _parsePlan(String plan) {
    switch (plan) {
      case 'pro':
        return PlanType.pro;
      case 'ultra':
        return PlanType.ultra;
      default:
        return PlanType.free;
    }
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Please sign in.';
      case 'weak-password':
        return 'Password must be at least 8 characters with uppercase, lowercase, and a number.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
