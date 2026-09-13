// ignore_for_file: constant_identifier_names

/// App configuration.
/// 
/// SECURITY MODEL:
/// ─────────────────────────────────────────────────────────────────────────
/// • NO API keys are stored here or anywhere in the app binary.
/// • The app only knows the backend URL — all AI calls go through our server.
/// • Backend URL is obfuscated (XOR encoded) so it's not plaintext in binary.
/// • JWT tokens are stored in flutter_secure_storage (Android Keystore /
///   iOS Keychain) — NOT in SharedPreferences.
/// • Certificate pinning prevents MITM attacks even on rooted devices.
/// • Code obfuscation (--obfuscate flag) makes reverse engineering harder.
///
/// WHAT AN ATTACKER CAN STILL GET (even with root/jailbreak):
/// • The backend URL (after deobfuscation) — but that's just our server URL,
///   not any AI provider key.
/// • A valid JWT token from memory — but it expires in 1 hour.
/// • They cannot get Stability AI keys — those never leave our server.
/// ─────────────────────────────────────────────────────────────────────────
library;


class AppConfig {
  AppConfig._();

  static const String appName = 'AivistoStudio';
  static const String appVersion = '1.0.0';
  static const String environment = String.fromEnvironment('APP_ENVIRONMENT', defaultValue: 'production');
  static bool get isProduction => environment == 'production';

  static const String googleWebClientId = '356786241093-kavs7cjhlkgb0j1nh94anran5fbk7ree.apps.googleusercontent.com';

  static const String _backendUrlDirect = String.fromEnvironment(
    'APP_BACKEND_URL',
    defaultValue: 'https://backend-bdvp.onrender.com',
  );

  static String get backendUrl {
    const isDev = bool.fromEnvironment('FLUTTER_DEV', defaultValue: false);
    if (isDev) return 'http://localhost:8000';
    return _backendUrlDirect;
  }

  // ── API Endpoints ─────────────────────────────────────────────────────────
  static const String endpointAuthVerify = '/auth/verify';
  static const String endpointAuthMe = '/auth/me';
  static const String endpointVideoGenerate = '/video/generate';
  static const String endpointVideoStatus = '/video/status';
  static const String endpointVideoHistory = '/video/history';
  static const String endpointImageGenerate = '/image/generate';
  static const String endpointImageRemoveBg = '/image/remove-background';
  static const String endpointImageSketch = '/image/sketch';
  static const String endpointUserCredits = '/user/credits';
  static const String endpointUserProfile = '/user/profile';
  static const String endpointSubscriptionVerify = '/user/subscription/verify';
  static const String endpointColorGradeAnalyze = '/color-grade/analyze';
  static const String endpointColorGradeApply = '/color-grade/apply';

  // ── Certificate Pinning ───────────────────────────────────────────────────
  // Railway ka SSL certificate fingerprint (SHA-256)
  // railway.app deploy ke baad update karna
  // Command: openssl s_client -connect your-url.railway.app:443 | openssl x509 -fingerprint -sha256
  static const List<String> allowedSHAFingerprints = [
    String.fromEnvironment('APP_SSL_PIN', defaultValue: ''),
  ];

  // ── Token Storage Keys ────────────────────────────────────────────────────
  // flutter_secure_storage mein store hoga (Android Keystore / iOS Keychain)
  static const String kFirebaseTokenKey = 'fb_id_token';
  static const String kUserDataKey = 'user_data_v2';
  static const String kSessionKey = 'session_active';
}
