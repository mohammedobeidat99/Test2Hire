import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/company_profile.dart';
import '../../domain/repositories/company_repository.dart';

class CompanyProvider extends ChangeNotifier {
  final CompanyRepository _companyRepository;
  StreamSubscription<CompanyProfile>? _profileSubscription;

  CompanyProfile? _company;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  CompanyProvider({required CompanyRepository companyRepository})
      : _companyRepository = companyRepository;

  CompanyProfile? get company => _company;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get isApproved => _company?.isApproved ?? false;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void listenToCompany(String companyId) {
    _profileSubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _profileSubscription = _companyRepository.listenCompanyProfile(companyId).listen(
      (profile) {
        _company = profile;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> loadCompany(String companyId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _company = await _companyRepository.getCompanyProfile(companyId);
    } on Failure catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateCompanyDetails({
    required String name,
    String? legalName,
    required String industry,
    String? website,
    required String description,
    String? contactPhone,
    String? teamSize,
    CompanyLocation? location,
  }) async {
    if (_company == null) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = CompanyProfile(
        id: _company!.id,
        ownerUid: _company!.ownerUid,
        name: name.trim(),
        legalName: legalName?.trim(),
        industry: industry.trim(),
        website: website?.trim(),
        logoUrl: _company!.logoUrl,
        coverUrl: _company!.coverUrl,
        description: description.trim(),
        location: location,
        contactEmail: _company!.contactEmail,
        contactPhone: contactPhone?.trim(),
        teamSize: teamSize,
        verificationStatus: _company!.verificationStatus,
        verificationNotes: _company!.verificationNotes,
        verifiedAt: _company!.verifiedAt,
        createdAt: _company!.createdAt,
        updatedAt: DateTime.now(),
      );

      await _companyRepository.updateCompanyProfile(updated);
      _company = updated;
      _successMessage = 'Company profile updated successfully.';
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

  Future<bool> uploadLogo(Uint8List fileBytes, String fileName) async {
    if (_company == null) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final logoUrl = await _companyRepository.uploadCompanyLogo(
        _company!.id,
        fileBytes,
        fileName,
      );

      _company = CompanyProfile(
        id: _company!.id,
        ownerUid: _company!.ownerUid,
        name: _company!.name,
        legalName: _company!.legalName,
        industry: _company!.industry,
        website: _company!.website,
        logoUrl: logoUrl,
        coverUrl: _company!.coverUrl,
        description: _company!.description,
        location: _company!.location,
        contactEmail: _company!.contactEmail,
        contactPhone: _company!.contactPhone,
        teamSize: _company!.teamSize,
        verificationStatus: _company!.verificationStatus,
        verificationNotes: _company!.verificationNotes,
        verifiedAt: _company!.verifiedAt,
        createdAt: _company!.createdAt,
        updatedAt: DateTime.now(),
      );

      _successMessage = 'Company logo uploaded.';
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

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }
}
