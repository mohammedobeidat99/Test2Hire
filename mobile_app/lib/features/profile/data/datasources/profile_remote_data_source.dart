import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/candidate_profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<CandidateProfileModel> getProfile(String uid);
  Future<void> updateProfile(CandidateProfileModel profile);
  Future<String> uploadAvatar(String uid, Uint8List fileBytes, String fileName);
  Future<String> uploadCV(String uid, Uint8List fileBytes, String fileName);
  Future<void> deleteCV(String uid);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  ProfileRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<CandidateProfileModel> getProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        throw const ServerException('Candidate profile document does not exist.');
      }
      return CandidateProfileModel.fromFirestore(doc);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to fetch profile: $e');
    }
  }

  @override
  Future<void> updateProfile(CandidateProfileModel profile) async {
    try {
      await _firestore.collection('users').doc(profile.uid).update(profile.toFirestore());
    } catch (e) {
      throw ServerException('Failed to update candidate profile: $e');
    }
  }

  @override
  Future<String> uploadAvatar(String uid, Uint8List fileBytes, String fileName) async {
    try {
      final ref = _storage.ref().child('users/$uid/avatar/$fileName');
      final uploadTask = await ref.putData(
        fileBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update user doc with avatar
      await _firestore.collection('users').doc(uid).update({
        'photoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return downloadUrl;
    } catch (e) {
      throw ServerException('Failed to upload avatar: $e');
    }
  }

  @override
  Future<String> uploadCV(String uid, Uint8List fileBytes, String fileName) async {
    try {
      String contentType = 'application/pdf';
      final lower = fileName.toLowerCase();
      if (lower.endsWith('.docx')) {
        contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      } else if (lower.endsWith('.doc')) {
        contentType = 'application/msword';
      }

      final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final ref = _storage.ref().child('users/$uid/cv/$cleanFileName');
      final uploadTask = await ref.putData(
        fileBytes,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update user doc with CV URL and filename
      await _firestore.collection('users').doc(uid).set({
        'cvUrl': downloadUrl,
        'cvFileName': fileName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return downloadUrl;
    } catch (e) {
      throw ServerException('Failed to upload CV: $e');
    }
  }

  @override
  Future<void> deleteCV(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'cvUrl': FieldValue.delete(),
        'cvFileName': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException('Failed to delete CV: $e');
    }
  }
}
