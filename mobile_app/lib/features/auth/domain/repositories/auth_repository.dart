import '../entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  Stream<String?> get idTokenChanges;
  Future<String?> getIdToken({bool forceRefresh = false});
  Future<AppUser?> getCurrentUser();

  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AppUser> signInWithGoogle({
    bool isCompany = false,
  });

  Future<AppUser> registerCandidate({
    required String email,
    required String password,
    required String fullName,
  });

  Future<AppUser> registerCompany({
    required String email,
    required String password,
    required String companyName,
    required String industry,
  });

  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<void> reloadUser();
  Future<void> signOut();
}
