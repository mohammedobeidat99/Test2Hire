import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/services/session_service.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus {
  uninitialized,
  authenticated,
  unauthenticated,
}

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  StreamSubscription<AppUser?>? _authSubscription;
  StreamSubscription<String?>? _idTokenSubscription;
  Timer? _initTimer;

  AppUser? _user;
  AuthStatus _status = AuthStatus.uninitialized;
  bool _isLoading = false;
  bool _isValidatingRole = false;
  String? _errorMessage;

  AuthProvider({required AuthRepository authRepository})
      : _authRepository = authRepository {
    _init();
  }

  AppUser? get user => _user;
  AuthStatus get status => _status;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _user != null;
  bool get isEmailVerified => _user?.isEmailVerified ?? false;
  UserRole? get role => _user?.role;

  void _init() {
    // 1. Instant cache recovery: restore session immediately from local disk if present
    final cached = SessionService.getCachedUser();
    if (cached != null) {
      _user = cached;
      _status = AuthStatus.authenticated;
      FcmService.registerTokenForUser(cached.uid);
      notifyListeners();
    }

    // 2. Listen to Firebase auth state changes
    _authSubscription = _authRepository.authStateChanges.listen((user) async {
      if (_isValidatingRole) return;
      _initTimer?.cancel();
      _user = user;
      _status = user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
      if (user != null) {
        await SessionService.saveUser(user);
        await FcmService.registerTokenForUser(user.uid);
      } else {
        await SessionService.clearSession();
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('AuthProvider error in authStateChanges: $e');
      _initTimer?.cancel();
      // Keep cached session if available; only invalidate if no user exists
      if (_user == null) {
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    });

    // 3. Listen to ID Token changes for seamless token refresh
    _idTokenSubscription = _authRepository.idTokenChanges.listen((token) {
      if (token != null) {
        debugPrint('AuthProvider: Firebase ID token refreshed successfully');
      }
    });

    // 4. Graceful failsafe timer for edge cases
    _initTimer = Timer(const Duration(seconds: 4), () async {
      if (_status == AuthStatus.uninitialized) {
        try {
          final currentUser = await _authRepository
              .getCurrentUser()
              .timeout(const Duration(seconds: 3));
          if (currentUser != null) {
            _user = currentUser;
            _status = AuthStatus.authenticated;
            await SessionService.saveUser(currentUser);
            await FcmService.registerTokenForUser(currentUser.uid);
          } else {
            final cachedUser = SessionService.getCachedUser();
            if (cachedUser != null) {
              _user = cachedUser;
              _status = AuthStatus.authenticated;
            } else {
              _status = AuthStatus.unauthenticated;
            }
          }
        } catch (_) {
          final cachedUser = SessionService.getCachedUser();
          if (cachedUser != null) {
            _user = cachedUser;
            _status = AuthStatus.authenticated;
          } else {
            _status = AuthStatus.unauthenticated;
          }
        }
        notifyListeners();
      }
    });
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      return await _authRepository.getIdToken(forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('AuthProvider: Error fetching ID token: $e');
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
    bool? expectedIsCompany,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    _isValidatingRole = true;
    try {
      final user = await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Enforce strict role matching: company accounts can only log in from the company portal,
      // and candidate accounts can only log in from the candidate portal.
      if (expectedIsCompany != null) {
        if (expectedIsCompany == true && !user.isCompany) {
          await _authRepository.signOut();
          await SessionService.clearSession();
          _user = null;
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'هذا الحساب مخصص للباحثين عن عمل. يرجى التبديل إلى قسم "باحث عن عمل" لتسجيل الدخول.';
          _isValidatingRole = false;
          _setLoading(false);
          return false;
        }

        if (expectedIsCompany == false && user.isCompany) {
          await _authRepository.signOut();
          await SessionService.clearSession();
          _user = null;
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'هذا الحساب مخصص لأصحاب الشركات. يرجى التبديل إلى قسم "أصحاب الشركات" لتسجيل الدخول.';
          _isValidatingRole = false;
          _setLoading(false);
          return false;
        }
      }

      _user = user;
      _status = AuthStatus.authenticated;
      await SessionService.saveUser(_user!);
      await FcmService.registerTokenForUser(_user!.uid);
      _isValidatingRole = false;
      _setLoading(false);
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      _isValidatingRole = false;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isValidatingRole = false;
      _setLoading(false);
      return false;
    } finally {
      _isValidatingRole = false;
    }
  }

  Future<bool> signInWithGoogle({bool isCompany = false}) async {
    _setLoading(true);
    _errorMessage = null;
    _isValidatingRole = true;
    try {
      final user = await _authRepository.signInWithGoogle(isCompany: isCompany);

      // Enforce strict role matching for Google Sign-in as well
      if (isCompany && !user.isCompany) {
        await _authRepository.signOut();
        await SessionService.clearSession();
        _user = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'هذا الحساب مخصص للباحثين عن عمل. يرجى التبديل إلى قسم "باحث عن عمل" لتسجيل الدخول.';
        _isValidatingRole = false;
        _setLoading(false);
        return false;
      }

      if (!isCompany && user.isCompany) {
        await _authRepository.signOut();
        await SessionService.clearSession();
        _user = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'هذا الحساب مخصص لأصحاب الشركات. يرجى التبديل إلى قسم "أصحاب الشركات" لتسجيل الدخول.';
        _isValidatingRole = false;
        _setLoading(false);
        return false;
      }

      _user = user;
      _status = AuthStatus.authenticated;
      await SessionService.saveUser(_user!);
      await FcmService.registerTokenForUser(_user!.uid);
      _isValidatingRole = false;
      _setLoading(false);
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      _isValidatingRole = false;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isValidatingRole = false;
      _setLoading(false);
      return false;
    } finally {
      _isValidatingRole = false;
    }
  }

  Future<bool> registerCandidate({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _user = await _authRepository.registerCandidate(
        email: email,
        password: password,
        fullName: fullName,
      );
      _status = AuthStatus.authenticated;
      if (_user != null) {
        await SessionService.saveUser(_user!);
        await SessionService.saveBiometricCredentials(email: email);
        await FcmService.registerTokenForUser(_user!.uid);
      }
      _setLoading(false);
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> registerCompany({
    required String email,
    required String password,
    required String companyName,
    required String industry,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _user = await _authRepository.registerCompany(
        email: email,
        password: password,
        companyName: companyName,
        industry: industry,
      );
      _status = AuthStatus.authenticated;
      if (_user != null) {
        await SessionService.saveUser(_user!);
        await SessionService.saveBiometricCredentials(email: email);
        await FcmService.registerTokenForUser(_user!.uid);
      }
      _setLoading(false);
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authRepository.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> sendEmailVerification() async {
    _errorMessage = null;
    try {
      await _authRepository.sendEmailVerification();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to resend email verification.';
      notifyListeners();
      return false;
    }
  }

  Future<void> checkEmailVerification() async {
    try {
      await _authRepository.reloadUser();
      final refreshedUser = await _authRepository.getCurrentUser();
      if (refreshedUser != null) {
        _user = refreshedUser;
        await SessionService.saveUser(refreshedUser);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error reloading user: $e');
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await SessionService.clearSession();
      await FcmService.removeToken();
      await _authRepository.signOut();
      _user = null;
      _status = AuthStatus.unauthenticated;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    _authSubscription?.cancel();
    _idTokenSubscription?.cancel();
    super.dispose();
  }
}
