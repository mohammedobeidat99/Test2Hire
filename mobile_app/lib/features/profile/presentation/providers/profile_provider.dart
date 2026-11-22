import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/candidate_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileRepository _profileRepository;

  String? _activeUid;
  CandidateProfile? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  void reset() {
    _activeUid = null;
    _profile = null;
    _isLoading = false;
    _isSaving = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  ProfileProvider({required ProfileRepository profileRepository})
      : _profileRepository = profileRepository;

  CandidateProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> loadProfile(String uid) async {
    if (_activeUid != null && _activeUid != uid) {
      _profile = null;
      _successMessage = null;
    }
    _activeUid = uid;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _profileRepository.getProfile(uid);
      if (_activeUid != uid) return;
      _profile = fetched;
    } on Failure catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePersonalInfo({
    required String fullName,
    required String headline,
    required String about,
    required String phoneNumber,
    required String location,
  }) async {
    if (_profile == null) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = CandidateProfile(
        uid: _profile!.uid,
        email: _profile!.email,
        fullName: fullName.trim(),
        headline: headline.trim(),
        about: about.trim(),
        phoneNumber: phoneNumber.trim(),
        location: location.trim(),
        photoUrl: _profile!.photoUrl,
        skills: _profile!.skills,
        education: _profile!.education,
        experience: _profile!.experience,
        certifications: _profile!.certifications,
        languages: _profile!.languages,
        cvUrl: _profile!.cvUrl,
        cvFileName: _profile!.cvFileName,
        isProfileComplete: _profile!.completionPercentage >= 70,
        updatedAt: DateTime.now(),
      );

      await _profileRepository.updateProfile(updated);
      _profile = updated;
      _successMessage = 'Personal information updated.';
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateSkills(List<String> newSkills) async {
    if (_profile == null) return false;

    _isSaving = true;
    notifyListeners();

    try {
      final updated = CandidateProfile(
        uid: _profile!.uid,
        email: _profile!.email,
        fullName: _profile!.fullName,
        headline: _profile!.headline,
        about: _profile!.about,
        phoneNumber: _profile!.phoneNumber,
        location: _profile!.location,
        photoUrl: _profile!.photoUrl,
        skills: newSkills,
        education: _profile!.education,
        experience: _profile!.experience,
        certifications: _profile!.certifications,
        languages: _profile!.languages,
        cvUrl: _profile!.cvUrl,
        cvFileName: _profile!.cvFileName,
        isProfileComplete: _profile!.completionPercentage >= 70,
        updatedAt: DateTime.now(),
      );

      await _profileRepository.updateProfile(updated);
      _profile = updated;
      _successMessage = 'Skills updated successfully.';
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> addEducation(EducationItem item) async {
    if (_profile == null) return false;

    final updatedEducation = List<EducationItem>.from(_profile!.education)..add(item);
    return _saveEducationList(updatedEducation);
  }

  Future<bool> removeEducation(int index) async {
    if (_profile == null || index < 0 || index >= _profile!.education.length) {
      return false;
    }

    final updatedEducation = List<EducationItem>.from(_profile!.education)..removeAt(index);
    return _saveEducationList(updatedEducation);
  }

  Future<bool> _saveEducationList(List<EducationItem> list) async {
    _isSaving = true;
    notifyListeners();

    try {
      final updated = CandidateProfile(
        uid: _profile!.uid,
        email: _profile!.email,
        fullName: _profile!.fullName,
        headline: _profile!.headline,
        about: _profile!.about,
        phoneNumber: _profile!.phoneNumber,
        location: _profile!.location,
        photoUrl: _profile!.photoUrl,
        skills: _profile!.skills,
        education: list,
        experience: _profile!.experience,
        certifications: _profile!.certifications,
        languages: _profile!.languages,
        cvUrl: _profile!.cvUrl,
        cvFileName: _profile!.cvFileName,
        isProfileComplete: _profile!.completionPercentage >= 70,
        updatedAt: DateTime.now(),
      );

      await _profileRepository.updateProfile(updated);
      _profile = updated;
      _successMessage = 'Education updated.';
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> addExperience(ExperienceItem item) async {
    if (_profile == null) return false;

    final updatedExperience = List<ExperienceItem>.from(_profile!.experience)..add(item);
    return _saveExperienceList(updatedExperience);
  }

  Future<bool> removeExperience(int index) async {
    if (_profile == null || index < 0 || index >= _profile!.experience.length) {
      return false;
    }

    final updatedExperience = List<ExperienceItem>.from(_profile!.experience)..removeAt(index);
    return _saveExperienceList(updatedExperience);
  }

  Future<bool> _saveExperienceList(List<ExperienceItem> list) async {
    _isSaving = true;
    notifyListeners();

    try {
      final updated = CandidateProfile(
        uid: _profile!.uid,
        email: _profile!.email,
        fullName: _profile!.fullName,
        headline: _profile!.headline,
        about: _profile!.about,
        phoneNumber: _profile!.phoneNumber,
        location: _profile!.location,
        photoUrl: _profile!.photoUrl,
        skills: _profile!.skills,
        education: _profile!.education,
        experience: list,
        certifications: _profile!.certifications,
        languages: _profile!.languages,
        cvUrl: _profile!.cvUrl,
        cvFileName: _profile!.cvFileName,
        isProfileComplete: _profile!.completionPercentage >= 70,
        updatedAt: DateTime.now(),
      );

      await _profileRepository.updateProfile(updated);
      _profile = updated;
      _successMessage = 'Work experience updated.';
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateCertificationsAndLanguages({
    required List<CertificationItem> certifications,
    required List<LanguageItem> languages,
  }) async {
    if (_profile == null) return false;

    _isSaving = true;
    notifyListeners();

    try {
      final updated = CandidateProfile(
        uid: _profile!.uid,
        email: _profile!.email,
        fullName: _profile!.fullName,
        headline: _profile!.headline,
        about: _profile!.about,
        phoneNumber: _profile!.phoneNumber,
        location: _profile!.location,
        photoUrl: _profile!.photoUrl,
        skills: _profile!.skills,
        education: _profile!.education,
        experience: _profile!.experience,
        certifications: certifications,
        languages: languages,
        cvUrl: _profile!.cvUrl,
        cvFileName: _profile!.cvFileName,
        isProfileComplete: _profile!.completionPercentage >= 70,
        updatedAt: DateTime.now(),
      );

      await _profileRepository.updateProfile(updated);
      _profile = updated;
      _successMessage = 'Certifications and languages saved.';
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> uploadCV(Uint8List fileBytes, String fileName) async {
    if (_profile == null) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cvUrl = await _profileRepository.uploadCV(_profile!.uid, fileBytes, fileName);
      _profile = CandidateProfile(
        uid: _profile!.uid,
        email: _profile!.email,
        fullName: _profile!.fullName,
        headline: _profile!.headline,
        about: _profile!.about,
        phoneNumber: _profile!.phoneNumber,
        location: _profile!.location,
        photoUrl: _profile!.photoUrl,
        skills: _profile!.skills,
        education: _profile!.education,
        experience: _profile!.experience,
        certifications: _profile!.certifications,
        languages: _profile!.languages,
        cvUrl: cvUrl,
        cvFileName: fileName,
        isProfileComplete: _profile!.completionPercentage >= 70,
        updatedAt: DateTime.now(),
      );
      _successMessage = 'Resume uploaded successfully.';
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCV() async {
    if (_profile == null) return false;

    _isSaving = true;
    notifyListeners();

    try {
      await _profileRepository.deleteCV(_profile!.uid);
      _profile = CandidateProfile(
        uid: _profile!.uid,
        email: _profile!.email,
        fullName: _profile!.fullName,
        headline: _profile!.headline,
        about: _profile!.about,
        phoneNumber: _profile!.phoneNumber,
        location: _profile!.location,
        photoUrl: _profile!.photoUrl,
        skills: _profile!.skills,
        education: _profile!.education,
        experience: _profile!.experience,
        certifications: _profile!.certifications,
        languages: _profile!.languages,
        cvUrl: null,
        cvFileName: null,
        isProfileComplete: _profile!.completionPercentage >= 70,
        updatedAt: DateTime.now(),
      );
      _successMessage = 'CV removed.';
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updatePhotoUrl(String photoUrl) async {
    if (_profile == null) return false;

    _isSaving = true;
    notifyListeners();

    try {
      final updated = CandidateProfile(
        uid: _profile!.uid,
        email: _profile!.email,
        fullName: _profile!.fullName,
        headline: _profile!.headline,
        about: _profile!.about,
        phoneNumber: _profile!.phoneNumber,
        location: _profile!.location,
        photoUrl: photoUrl,
        skills: _profile!.skills,
        education: _profile!.education,
        experience: _profile!.experience,
        certifications: _profile!.certifications,
        languages: _profile!.languages,
        cvUrl: _profile!.cvUrl,
        cvFileName: _profile!.cvFileName,
        isProfileComplete: _profile!.completionPercentage >= 70,
        updatedAt: DateTime.now(),
      );
      await _profileRepository.updateProfile(updated);
      _profile = updated;
      _successMessage = 'Profile photo updated.';
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
