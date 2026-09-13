import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

/// Secure token storage — Android Keystore / iOS Keychain use karta hai.
/// 
/// SharedPreferences use NAHI karta — wo plain XML mein store hota hai.
/// flutter_secure_storage:
///   Android: EncryptedSharedPreferences backed by Android Keystore (AES-256)
///   iOS: Keychain Services (Secure Enclave on supported devices)
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    keyCipherAlgorithm:
        KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
  );

  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false, // iCloud sync band — key device pe hi rahe
  );

  final _storage = const FlutterSecureStorage();

  /// Firebase ID token lo — agar expire hua toh auto-refresh karo.
  /// Yeh token backend ko bheja jaata hai verification ke liye.
  Future<String?> getValidToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Firebase automatically refresh karta hai agar expire hua
      // forceRefresh: false — cached token use karo agar valid hai
      final token = await user.getIdToken(false);
      return token;
    } catch (e) {
      return null;
    }
  }

  /// Force refresh token (session restore ke baad)
  Future<String?> forceRefreshToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken(true);
    } catch (e) {
      return null;
    }
  }

  /// User data securely store karo (credits, plan etc.)
  Future<void> saveUserData(String jsonData) async {
    await _storage.write(
      key: AppConfig.kUserDataKey,
      value: jsonData,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  /// User data read karo
  Future<String?> getUserData() async {
    return await _storage.read(
      key: AppConfig.kUserDataKey,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  /// Session active mark karo
  Future<void> setSessionActive(bool active) async {
    if (active) {
      await _storage.write(
        key: AppConfig.kSessionKey,
        value: 'true',
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
    } else {
      await _storage.delete(
        key: AppConfig.kSessionKey,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
    }
  }

  /// Session active hai?
  Future<bool> isSessionActive() async {
    final val = await _storage.read(
      key: AppConfig.kSessionKey,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    return val == 'true';
  }

  /// Logout — saara secure storage clear karo
  Future<void> clearAll() async {
    await _storage.deleteAll(
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }
}
