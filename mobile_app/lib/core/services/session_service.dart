import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/domain/entities/app_user.dart';

class SessionService {
  static SharedPreferences? _prefs;
  static AppUser? _memoryCache;

  static const String _keyIsLoggedIn = 'auth_is_logged_in';
  static const String _keyUid = 'auth_uid';
  static const String _keyEmail = 'auth_email';
  static const String _keyRole = 'auth_role';
  static const String _keyFullName = 'auth_full_name';
  static const String _keyPhoneNumber = 'auth_phone_number';
  static const String _keyPhotoUrl = 'auth_photo_url';
  static const String _keyIsEmailVerified = 'auth_is_email_verified';
  static const String _keyIsProfileComplete = 'auth_is_profile_complete';
  static const String _keyLastLoginAt = 'auth_last_login_at';

  static Future<void> init([SharedPreferences? customPrefs]) async {
    try {
      _prefs = customPrefs ?? await SharedPreferences.getInstance();
      // Remove any legacy plaintext biometric password stored by older versions
      if (_prefs!.containsKey(_legacyKeyBioPassword)) {
        await _prefs!.remove(_legacyKeyBioPassword);
      }
      _loadToMemoryCache();
    } catch (e) {
      debugPrint('SessionService: Failed to initialize SharedPreferences: $e');
    }
  }

  static void _loadToMemoryCache() {
    if (_prefs == null) return;
    final isLoggedIn = _prefs!.getBool(_keyIsLoggedIn) ?? false;
    final uid = _prefs!.getString(_keyUid);
    if (!isLoggedIn || uid == null || uid.isEmpty) {
      _memoryCache = null;
      return;
    }

    final email = _prefs!.getString(_keyEmail) ?? '';
    final roleStr = _prefs!.getString(_keyRole) ?? 'USER';
    final fullName = _prefs!.getString(_keyFullName) ?? '';
    final phoneNumber = _prefs!.getString(_keyPhoneNumber);
    final photoUrl = _prefs!.getString(_keyPhotoUrl);
    final isEmailVerified = _prefs!.getBool(_keyIsEmailVerified) ?? false;
    final isProfileComplete = _prefs!.getBool(_keyIsProfileComplete) ?? false;

    _memoryCache = AppUser(
      uid: uid,
      email: email,
      role: UserRoleExtension.fromString(roleStr),
      fullName: fullName,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
      isEmailVerified: isEmailVerified,
      isProfileComplete: isProfileComplete,
    );
  }

  static AppUser? getCachedUser() {
    if (_memoryCache != null) return _memoryCache;
    _loadToMemoryCache();
    return _memoryCache;
  }

  static bool get hasCachedSession {
    final cached = getCachedUser();
    return cached != null;
  }

  static Future<void> saveUser(AppUser user) async {
    _memoryCache = user;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_keyIsLoggedIn, true);
      await _prefs!.setString(_keyUid, user.uid);
      await _prefs!.setString(_keyEmail, user.email);
      await _prefs!.setString(_keyRole, user.role.toShortString());
      await _prefs!.setString(_keyFullName, user.fullName);
      if (user.phoneNumber != null) {
        await _prefs!.setString(_keyPhoneNumber, user.phoneNumber!);
      } else {
        await _prefs!.remove(_keyPhoneNumber);
      }
      if (user.photoUrl != null) {
        await _prefs!.setString(_keyPhotoUrl, user.photoUrl!);
      } else {
        await _prefs!.remove(_keyPhotoUrl);
      }
      await _prefs!.setBool(_keyIsEmailVerified, user.isEmailVerified);
      await _prefs!.setBool(_keyIsProfileComplete, user.isProfileComplete);
      await _prefs!.setString(_keyLastLoginAt, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('SessionService: Error saving user to SharedPreferences: $e');
    }
  }

  static Future<void> updateEmailVerified(bool verified) async {
    if (_memoryCache != null) {
      _memoryCache = AppUser(
        uid: _memoryCache!.uid,
        email: _memoryCache!.email,
        role: _memoryCache!.role,
        fullName: _memoryCache!.fullName,
        phoneNumber: _memoryCache!.phoneNumber,
        photoUrl: _memoryCache!.photoUrl,
        isEmailVerified: verified,
        isProfileComplete: _memoryCache!.isProfileComplete,
        createdAt: _memoryCache!.createdAt,
      );
    }
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_keyIsEmailVerified, verified);
    } catch (e) {
      debugPrint('SessionService: Error updating email verified in SharedPreferences: $e');
    }
  }

  static const String _keyBioEmail = 'auth_biometric_email';
  static const String _keyBioEnabled = 'auth_biometric_enabled';
  static const String _legacyKeyBioPassword = 'auth_biometric_password';

  /// Records the user's opted-in biometric email without persisting any password
  /// or secret in SharedPreferences. Biometric unlock gates access on an active
  /// Firebase session via [authenticateBiometricSession].
  static Future<void> saveBiometricCredentials({
    required String email,
    String password = '',
  }) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final trimmed = email.trim();
      if (trimmed.isEmpty) return;
      await _prefs!.setString(_keyBioEmail, trimmed);
      await _prefs!.setBool(_keyBioEnabled, true);
      if (_prefs!.containsKey(_legacyKeyBioPassword)) {
        await _prefs!.remove(_legacyKeyBioPassword);
      }
    } catch (e) {
      debugPrint('SessionService: Error saving biometric settings: $e');
    }
  }

  /// Returns biometric enrollment info only (never returns a stored password).
  static Future<({String email, String password})?> getBiometricCredentials() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (_prefs!.containsKey(_legacyKeyBioPassword)) {
        await _prefs!.remove(_legacyKeyBioPassword);
      }
      final email = _prefs!.getString(_keyBioEmail);
      final enabled = _prefs!.getBool(_keyBioEnabled) ?? false;
      if (email != null && email.isNotEmpty && (enabled || FirebaseAuth.instance.currentUser != null)) {
        return (email: email, password: '');
      }
    } catch (e) {
      debugPrint('SessionService: Error reading biometric settings: $e');
    }
    return null;
  }

  /// Performs OS biometric verification only when a live Firebase Auth session
  /// is still active. If the Firebase session has expired, standard sign-in is required.
  static Future<bool> authenticateBiometricSession({
    LocalAuthentication? localAuth,
    bool Function()? hasActiveFirebaseSession,
  }) async {
    try {
      final activeSession = hasActiveFirebaseSession?.call() ??
          (FirebaseAuth.instance.currentUser != null);
      if (!activeSession) return false;

      final auth = localAuth ?? LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final isSupported = await auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;

      return await auth.authenticate(
        localizedReason: 'Verify your identity to unlock your Test2Hire session',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('SessionService: Biometric authentication failed: $e');
      return false;
    }
  }

  static const String _keyHasSeenOnboarding = 'app_has_seen_onboarding';

  static bool get hasSeenOnboarding {
    return _prefs?.getBool(_keyHasSeenOnboarding) ?? false;
  }

  static Future<void> setOnboardingSeen() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_keyHasSeenOnboarding, true);
    } catch (e) {
      debugPrint('SessionService: Error saving onboarding state: $e');
    }
  }

  static Future<void> clearSession() async {
    _memoryCache = null;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_keyIsLoggedIn);
      await _prefs!.remove(_keyUid);
      await _prefs!.remove(_keyEmail);
      await _prefs!.remove(_keyRole);
      await _prefs!.remove(_keyFullName);
      await _prefs!.remove(_keyPhoneNumber);
      await _prefs!.remove(_keyPhotoUrl);
      await _prefs!.remove(_keyIsEmailVerified);
      await _prefs!.remove(_keyIsProfileComplete);
      await _prefs!.remove(_keyLastLoginAt);
    } catch (e) {
      debugPrint('SessionService: Error clearing session from SharedPreferences: $e');
    }
  }
}
