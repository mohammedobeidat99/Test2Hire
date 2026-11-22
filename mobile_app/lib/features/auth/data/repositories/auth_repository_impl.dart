import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl({AuthRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? AuthRemoteDataSourceImpl();

  @override
  Stream<AppUser?> get authStateChanges => _remoteDataSource.authStateChanges;

  @override
  Stream<String?> get idTokenChanges => _remoteDataSource.idTokenChanges;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return await _remoteDataSource.getIdToken(forceRefresh: forceRefresh);
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    try {
      return await _remoteDataSource.getCurrentUser();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _remoteDataSource.signInWithEmailAndPassword(email, password);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<AppUser> signInWithGoogle({
    bool isCompany = false,
  }) async {
    try {
      return await _remoteDataSource.signInWithGoogle(isCompany: isCompany);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<AppUser> registerCandidate({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      return await _remoteDataSource.registerCandidate(email, password, fullName);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<AppUser> registerCompany({
    required String email,
    required String password,
    required String companyName,
    required String industry,
  }) async {
    try {
      return await _remoteDataSource.registerCompany(email, password, companyName, industry);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _remoteDataSource.sendPasswordResetEmail(email);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      await _remoteDataSource.sendEmailVerification();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> reloadUser() async {
    try {
      await _remoteDataSource.reloadUser();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _remoteDataSource.signOut();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
