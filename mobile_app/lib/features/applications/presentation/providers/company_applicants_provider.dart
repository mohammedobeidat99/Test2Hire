import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/job_application.dart';
import '../../domain/repositories/application_repository.dart';

class CompanyApplicantsProvider extends ChangeNotifier {
  final ApplicationRepository _repository;
  StreamSubscription<List<JobApplication>>? _subscription;

  List<JobApplication> _allApplicants = [];
  ApplicationStatus? _statusFilter;
  bool _sortByFitScore = false;
  bool _sortByExamScore = false;
  bool _filterTopPerformers = false;
  bool _isLoading = false;
  bool _isUpdating = false;
  bool _isAiParsing = false;
  String? _parsingApplicationId;
  String? _errorMessage;
  String? _successMessage;

  CompanyApplicantsProvider({required ApplicationRepository repository})
      : _repository = repository;

  List<JobApplication> get applicants {
    List<JobApplication> list = _statusFilter == null
        ? List.from(_allApplicants)
        : _allApplicants.where((a) => a.status == _statusFilter).toList();

    if (_filterTopPerformers) {
      list = list.where((a) =>
          (a.examScore != null && a.examScore! >= 70) ||
          a.status == ApplicationStatus.passed ||
          (a.overallFitScore != null && a.overallFitScore! >= 75)
      ).toList();
    }

    if (_sortByExamScore) {
      list.sort((a, b) => (b.examScore ?? -1).compareTo(a.examScore ?? -1));
    } else if (_sortByFitScore) {
      list.sort((a, b) => (b.overallFitScore ?? -1).compareTo(a.overallFitScore ?? -1));
    }
    return list;
  }

  List<JobApplication> get allApplicants => _allApplicants;
  ApplicationStatus? get statusFilter => _statusFilter;
  bool get sortByFitScore => _sortByFitScore;
  bool get sortByExamScore => _sortByExamScore;
  bool get filterTopPerformers => _filterTopPerformers;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  bool get isAiParsing => _isAiParsing;
  String? get parsingApplicationId => _parsingApplicationId;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  int get totalCount => _allApplicants.length;
  int get appliedCount =>
      _allApplicants.where((a) => a.status == ApplicationStatus.applied).length;
  int get underReviewCount => _allApplicants
      .where((a) =>
          a.status == ApplicationStatus.underReview ||
          a.status == ApplicationStatus.shortlisted)
      .length;
  int get topPerformersCount => _allApplicants
      .where((a) =>
          (a.examScore != null && a.examScore! >= 70) ||
          a.status == ApplicationStatus.passed ||
          (a.overallFitScore != null && a.overallFitScore! >= 75))
      .length;
  int get examCount => _allApplicants
      .where((a) =>
          a.status == ApplicationStatus.examPending ||
          a.status == ApplicationStatus.examAssigned ||
          a.status == ApplicationStatus.examInProgress ||
          a.status == ApplicationStatus.examCompleted ||
          a.status == ApplicationStatus.passed ||
          a.status == ApplicationStatus.failed)
      .length;
  int get interviewCount => _allApplicants
      .where((a) =>
          a.status == ApplicationStatus.interviewInvited ||
          a.status == ApplicationStatus.interviewScheduled)
      .length;
  int get selectedCount => _allApplicants
      .where((a) =>
          a.status == ApplicationStatus.selected ||
          a.status == ApplicationStatus.offerExtended ||
          a.status == ApplicationStatus.hired)
      .length;
  int get rejectedCount => _allApplicants
      .where((a) => a.status == ApplicationStatus.rejected)
      .length;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void setStatusFilter(ApplicationStatus? filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  void toggleTopPerformersFilter() {
    _filterTopPerformers = !_filterTopPerformers;
    notifyListeners();
  }

  void toggleSortByExamScore() {
    _sortByExamScore = !_sortByExamScore;
    if (_sortByExamScore) _sortByFitScore = false;
    notifyListeners();
  }

  void toggleSortByFitScore() {
    _sortByFitScore = !_sortByFitScore;
    if (_sortByFitScore) _sortByExamScore = false;
    notifyListeners();
  }

  Future<AiParsedCv?> parseApplicantCv(String applicationId) async {
    _isAiParsing = true;
    _parsingApplicationId = applicationId;
    _errorMessage = null;
    notifyListeners();

    try {
      final parsedCv = await _repository.parseResumeWithAI(applicationId);

      final index = _allApplicants.indexWhere((a) => a.id == applicationId);
      if (index != -1) {
        final existing = _allApplicants[index];
        final overallScore = existing.examScore != null
            ? ((existing.examScore! * 0.6) + (parsedCv.cvMatchScore * 0.4)).round()
            : parsedCv.cvMatchScore;

        _allApplicants[index] = existing.copyWith(
          aiParsedCv: parsedCv,
          cvMatchScore: parsedCv.cvMatchScore,
          overallFitScore: overallScore,
          aiRecommendation: parsedCv.aiRecommendation,
          updatedAt: DateTime.now(),
        );
      }

      _successMessage = 'Resume parsed and scored by AI successfully!';
      return parsedCv;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isAiParsing = false;
      _parsingApplicationId = null;
      notifyListeners();
    }
  }

  void listenJobApplicants(String jobId) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _repository.listenJobApplicants(jobId).listen(
      (list) {
        _allApplicants = list;
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

  Future<void> loadJobApplicants(String jobId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allApplicants = await _repository.getJobApplicants(jobId);
    } on Failure catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateApplicantStatus(
    String applicationId,
    ApplicationStatus newStatus, {
    String? reason,
  }) async {
    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateApplicationStatus(
        applicationId,
        newStatus,
        reason: reason,
      );

      final index = _allApplicants.indexWhere((a) => a.id == applicationId);
      if (index != -1) {
        _allApplicants[index] = _allApplicants[index].copyWith(
          status: newStatus,
          rejectionReason: reason,
          updatedAt: DateTime.now(),
        );
      }

      _successMessage = 'Candidate moved to ${newStatus.displayName}.';
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
