import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mobile_app/features/career_site/domain/entities/company_career_page.dart';
import 'package:mobile_app/features/career_site/domain/repositories/career_page_repository.dart';
import 'package:mobile_app/features/jobs/domain/entities/job_posting.dart';

class CareerPageProvider extends ChangeNotifier {
  final CareerPageRepository _repository;

  CompanyCareerPage? _careerPage;
  List<JobPosting> _publicJobs = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  StreamSubscription<CompanyCareerPage?>? _pageSubscription;
  StreamSubscription<List<JobPosting>>? _jobsSubscription;

  CareerPageProvider({required CareerPageRepository repository})
      : _repository = repository;

  CompanyCareerPage? get careerPage => _careerPage;
  List<JobPosting> get publicJobs => _publicJobs;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  String? _activeCompanyId;

  void listenCareerPage(String companyId) {
    _pageSubscription?.cancel();
    _jobsSubscription?.cancel();

    if (_activeCompanyId != companyId) {
      _careerPage = null;
      _publicJobs = [];
    }
    _activeCompanyId = companyId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _pageSubscription = _repository.listenCompanyCareerPage(companyId).listen(
      (page) {
        if (_activeCompanyId != companyId) return;
        _careerPage = page;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (err) {
        if (_activeCompanyId != companyId) return;
        _isLoading = false;
        final raw = err.toString().toLowerCase();
        if (raw.contains('permission-denied')) {
          _errorMessage =
              'This profile is currently unavailable or requires sign-in. Please try again.';
        } else {
          _errorMessage = 'Could not load company profile. Please try again.';
        }
        notifyListeners();
      },
    );

    _jobsSubscription = _repository.listenCompanyPublicJobs(companyId).listen(
      (jobs) {
        if (_activeCompanyId != companyId) return;
        _publicJobs = jobs;
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  Future<bool> updateCompanyBranding({
    required String companyId,
    required CompanyBranding branding,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _repository.updateCompanyBranding(
        companyId: companyId,
        branding: branding,
      );
      if (_careerPage != null) {
        _careerPage = CompanyCareerPage(
          companyId: _careerPage!.companyId,
          companyName: _careerPage!.companyName,
          logoUrl: _careerPage!.logoUrl,
          industry: _careerPage!.industry,
          description: _careerPage!.description,
          location: _careerPage!.location,
          branding: branding,
          activeJobsCount: _careerPage!.activeJobsCount,
          isApproved: _careerPage!.isApproved,
        );
      }
      _isSaving = false;
      _successMessage = 'تم حفظ إعدادات الهوية والبوابة المهنية بنجاح';
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pageSubscription?.cancel();
    _jobsSubscription?.cancel();
    super.dispose();
  }
}
