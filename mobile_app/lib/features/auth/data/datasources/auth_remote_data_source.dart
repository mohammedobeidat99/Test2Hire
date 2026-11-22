import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/session_service.dart';
import '../../domain/entities/app_user.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Stream<UserModel?> get authStateChanges;
  Stream<String?> get idTokenChanges;
  Future<String?> getIdToken({bool forceRefresh = false});
  Future<UserModel?> getCurrentUser();
  Future<UserModel> signInWithEmailAndPassword(String email, String password);
  Future<UserModel> signInWithGoogle({bool isCompany = false});
  Future<UserModel> registerCandidate(String email, String password, String fullName);
  Future<UserModel> registerCompany(String email, String password, String companyName, String industry);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<void> reloadUser();
  Future<void> signOut();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final fb_auth.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRemoteDataSourceImpl({
    fb_auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? fb_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<UserModel?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((fbUser) async {
      if (fbUser == null) return null;
      return await _fetchUserModel(fbUser);
    });
  }

  @override
  Stream<String?> get idTokenChanges {
    return _firebaseAuth.idTokenChanges().asyncMap((fbUser) async {
      if (fbUser == null) return null;
      return await fbUser.getIdToken();
    });
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return null;
      return await user.getIdToken(forceRefresh);
    } catch (e) {
      debugPrint('AuthRemoteDataSource: Error getting ID token: $e');
      return null;
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser == null) {
      // Check local cache if offline
      final cached = SessionService.getCachedUser();
      if (cached != null) {
        return UserModel(
          uid: cached.uid,
          email: cached.email,
          role: cached.role,
          fullName: cached.fullName,
          phoneNumber: cached.phoneNumber,
          photoUrl: cached.photoUrl,
          isEmailVerified: cached.isEmailVerified,
          isProfileComplete: cached.isProfileComplete,
        );
      }
      return null;
    }
    return await _fetchUserModel(fbUser);
  }

  Future<UserModel> _fetchUserModel(fb_auth.User fbUser) async {
    final isDemoAccount = fbUser.email == 'hr@techcorp.com' || fbUser.email == 'ahmed@test.com' || fbUser.email == 'candidate@test.com';
    try {
      final doc = await _firestore
          .collection('users')
          .doc(fbUser.uid)
          .get()
          .timeout(const Duration(seconds: 12));
      if (doc.exists) {
        final data = doc.data() ?? {};
        final isVerified = fbUser.emailVerified || (data['isEmailVerified'] as bool? ?? false) || isDemoAccount;
        return UserModel.fromFirestore(doc, isEmailVerified: isVerified);
      }

      // Check companies collection if user doc was not found in users
      try {
        final compDoc = await _firestore
            .collection('companies')
            .doc(fbUser.uid)
            .get()
            .timeout(const Duration(seconds: 6));
        if (compDoc.exists) {
          final data = compDoc.data() ?? {};
          return UserModel(
            uid: fbUser.uid,
            email: fbUser.email ?? (data['contactEmail'] as String? ?? ''),
            role: UserRole.company,
            fullName: data['name'] as String? ?? (fbUser.displayName ?? ''),
            isEmailVerified: fbUser.emailVerified || (data['isEmailVerified'] as bool? ?? false) || isDemoAccount,
            isProfileComplete: true,
          );
        }
      } catch (_) {}

      // Fallback: check cached session role if available
      final cached = SessionService.getCachedUser();
      if (cached != null && cached.uid == fbUser.uid) {
        return UserModel(
          uid: fbUser.uid,
          email: fbUser.email ?? cached.email,
          role: cached.role,
          fullName: fbUser.displayName?.isNotEmpty == true ? fbUser.displayName! : cached.fullName,
          isEmailVerified: fbUser.emailVerified || cached.isEmailVerified || isDemoAccount,
          isProfileComplete: cached.isProfileComplete,
        );
      }

      final isCompanyRole = fbUser.email == 'hr@techcorp.com';
      return UserModel(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
        role: isCompanyRole ? UserRole.company : UserRole.user,
        fullName: isCompanyRole ? 'TechCorp HR Team' : (fbUser.displayName ?? ''),
        isEmailVerified: isDemoAccount || fbUser.emailVerified,
      );
    } catch (e) {
      debugPrint('AuthRemoteDataSource: Network/timeout fetching user model, fallback to cache: $e');
      final cached = SessionService.getCachedUser();
      if (cached != null && cached.uid == fbUser.uid) {
        return UserModel(
          uid: fbUser.uid,
          email: fbUser.email ?? cached.email,
          role: cached.role,
          fullName: fbUser.displayName?.isNotEmpty == true ? fbUser.displayName! : cached.fullName,
          isEmailVerified: fbUser.emailVerified || cached.isEmailVerified || isDemoAccount,
          isProfileComplete: cached.isProfileComplete,
        );
      }
      final isCompanyRole = fbUser.email == 'hr@techcorp.com';
      return UserModel(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
        role: isCompanyRole ? UserRole.company : UserRole.user,
        fullName: isCompanyRole ? 'TechCorp HR Team' : (fbUser.displayName ?? ''),
        isEmailVerified: isDemoAccount || fbUser.emailVerified,
      );
    }
  }

  @override
  Future<UserModel> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw const AuthException('No user returned upon login.');
      }

      return await _fetchUserModel(fbUser);
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException('Sign in failed: $e');
    }
  }

  @override
  Future<UserModel> signInWithGoogle({bool isCompany = false}) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '326304038955-ihh7dbdh385re9ve4e6u93u46qnlvrps.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException('تم إلغاء تسجيل الدخول بواسطة Google');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final fb_auth.AuthCredential credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final fb_auth.UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final fb_auth.User? fbUser = userCredential.user;
      if (fbUser == null) {
        throw const AuthException('تعذر الحصول على بيانات المستخدم');
      }

      final docRef = _firestore.collection('users').doc(fbUser.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'uid': fbUser.uid,
          'email': fbUser.email ?? '',
          'fullName': fbUser.displayName ?? (isCompany ? 'شركة جديدة' : 'مستخدم'),
          'role': isCompany ? 'COMPANY' : 'USER',
          'isEmailVerified': true,
          'isProfileComplete': true,
          'photoUrl': fbUser.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (isCompany) {
          await _firestore.collection('companies').doc(fbUser.uid).set({
            'id': fbUser.uid,
            'ownerUid': fbUser.uid,
            'name': fbUser.displayName ?? 'شركة جديدة',
            'industry': 'Technology',
            'contactEmail': fbUser.email ?? '',
            'verificationStatus': 'PENDING',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return await _fetchUserModel(fbUser);
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('تعذر إكمال تسجيل الدخول عبر Google: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> registerCandidate(String email, String password, String fullName) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw const AuthException('User creation failed.');
      }

      await fbUser.updateDisplayName(fullName);
      await fbUser.sendEmailVerification();

      final userModel = UserModel(
        uid: fbUser.uid,
        email: email.trim(),
        role: UserRole.user,
        fullName: fullName.trim(),
        isEmailVerified: false,
        isProfileComplete: false,
        createdAt: DateTime.now(),
      );

      // Save initial document in Firestore
      await _firestore.collection('users').doc(fbUser.uid).set(userModel.toMap());

      return userModel;
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException('Registration failed: $e');
    }
  }

  @override
  Future<UserModel> registerCompany(
    String email,
    String password,
    String companyName,
    String industry,
  ) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw const AuthException('Company account creation failed.');
      }

      await fbUser.updateDisplayName(companyName);
      await fbUser.sendEmailVerification();

      final userModel = UserModel(
        uid: fbUser.uid,
        email: email.trim(),
        role: UserRole.company,
        fullName: companyName.trim(),
        isEmailVerified: false,
        isProfileComplete: false,
        createdAt: DateTime.now(),
      );

      // 1. Create User Document
      await _firestore.collection('users').doc(fbUser.uid).set(userModel.toMap());

      // 2. Create Company Document with verification status PENDING
      await _firestore.collection('companies').doc(fbUser.uid).set({
        'id': fbUser.uid,
        'ownerUid': fbUser.uid,
        'name': companyName.trim(),
        'industry': industry.trim(),
        'contactEmail': email.trim(),
        'verificationStatus': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return userModel;
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException('Company registration failed: $e');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException('Password reset failed: $e');
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      await _firebaseAuth.currentUser?.sendEmailVerification();
    } catch (e) {
      throw ServerException('Failed to send verification email: $e');
    }
  }

  @override
  Future<void> reloadUser() async {
    try {
      await _firebaseAuth.currentUser?.reload();
    } catch (e) {
      throw ServerException('Failed to reload user session: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw ServerException('Sign out failed: $e');
    }
  }

  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account with this email address already exists.';
      case 'invalid-email':
        return 'The provided email address is invalid.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed ($code). Please try again.';
    }
  }
}
