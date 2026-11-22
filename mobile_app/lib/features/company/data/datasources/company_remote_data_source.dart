import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/company_profile_model.dart';

abstract class CompanyRemoteDataSource {
  Future<CompanyProfileModel> getCompanyProfile(String companyId);
  Stream<CompanyProfileModel> listenCompanyProfile(String companyId);
  Future<void> updateCompanyProfile(CompanyProfileModel profile);
  Future<String> uploadCompanyLogo(String companyId, Uint8List fileBytes, String fileName);
}

class CompanyRemoteDataSourceImpl implements CompanyRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CompanyRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<CompanyProfileModel> getCompanyProfile(String companyId) async {
    try {
      final doc = await _firestore.collection('companies').doc(companyId).get();
      if (!doc.exists) {
        throw const ServerException('Company profile does not exist.');
      }
      return CompanyProfileModel.fromFirestore(doc);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to load company profile: $e');
    }
  }

  @override
  Stream<CompanyProfileModel> listenCompanyProfile(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        throw const ServerException('Company document not found.');
      }
      return CompanyProfileModel.fromFirestore(snapshot);
    });
  }

  @override
  Future<void> updateCompanyProfile(CompanyProfileModel profile) async {
    try {
      await _firestore.collection('companies').doc(profile.id).update(profile.toFirestore());
    } catch (e) {
      throw ServerException('Failed to update company profile: $e');
    }
  }

  @override
  Future<String> uploadCompanyLogo(String companyId, Uint8List fileBytes, String fileName) async {
    try {
      final ext = fileName.split('.').last.toLowerCase();
      final mimeType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : ext == 'gif'
                  ? 'image/gif'
                  : 'image/jpeg';
      final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final ref = _storage.ref().child('companies/$companyId/logo/$cleanFileName');
      final uploadTask = await ref.putData(
        fileBytes,
        SettableMetadata(
          contentType: mimeType,
          customMetadata: {'companyId': companyId},
        ),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update company profile document with new logoUrl
      await _firestore.collection('companies').doc(companyId).update({
        'logoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Keep users.photoUrl in sync for community/avatar displays
      try {
        await _firestore.collection('users').doc(companyId).update({
          'photoUrl': downloadUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      return downloadUrl;
    } catch (e) {
      throw ServerException('Failed to upload company logo: $e');
    }
  }
}
