import 'dart:typed_data';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/candidate_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';
import '../models/candidate_profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;

  ProfileRepositoryImpl({ProfileRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? ProfileRemoteDataSourceImpl();

  @override
  Future<CandidateProfile> getProfile(String uid) async {
    try {
      return await _remoteDataSource.getProfile(uid);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateProfile(CandidateProfile profile) async {
    try {
      final model = CandidateProfileModel(
        uid: profile.uid,
        email: profile.email,
        fullName: profile.fullName,
        headline: profile.headline,
        about: profile.about,
        phoneNumber: profile.phoneNumber,
        location: profile.location,
        photoUrl: profile.photoUrl,
        skills: profile.skills,
        education: profile.education,
        experience: profile.experience,
        certifications: profile.certifications,
        languages: profile.languages,
        cvUrl: profile.cvUrl,
        cvFileName: profile.cvFileName,
        isProfileComplete: profile.isProfileComplete,
      );
      await _remoteDataSource.updateProfile(model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<String> uploadAvatar(String uid, Uint8List fileBytes, String fileName) async {
    try {
      return await _remoteDataSource.uploadAvatar(uid, fileBytes, fileName);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<String> uploadCV(String uid, Uint8List fileBytes, String fileName) async {
    try {
      return await _remoteDataSource.uploadCV(uid, fileBytes, fileName);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteCV(String uid) async {
    try {
      await _remoteDataSource.deleteCV(uid);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
