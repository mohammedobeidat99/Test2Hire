import 'dart:typed_data';
import '../entities/candidate_profile.dart';

abstract class ProfileRepository {
  Future<CandidateProfile> getProfile(String uid);
  Future<void> updateProfile(CandidateProfile profile);
  Future<String> uploadAvatar(String uid, Uint8List fileBytes, String fileName);
  Future<String> uploadCV(String uid, Uint8List fileBytes, String fileName);
  Future<void> deleteCV(String uid);
}
