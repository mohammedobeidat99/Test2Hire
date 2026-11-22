import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/job_application.dart';
import '../../domain/repositories/application_repository.dart';

class CandidateApplicationsProvider extends ChangeNotifier {
  final ApplicationRepository _repository;
  StreamSubscription<List<JobApplication>>? _subscription;

  List<JobApplication> _applications = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  final Map<String, bool> _appliedJobsMap = {};

  CandidateApplicationsProvider({required ApplicationRepository repository})
      : _repository = repository;

  List<JobApplication> get applications => _applications;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  int get totalCount => _applications.length;
  int get activeCount =>
      _applications.where((a) => !a.isTerminal).length;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  String? _listeningCandidateId;

  void reset() {
    _subscription?.cancel();
    _subscription = null;
    _listeningCandidateId = null;
    _applications = [];
    _appliedJobsMap.clear();
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  bool isJobApplied(String jobId) {
    if (_appliedJobsMap.containsKey(jobId)) {
      return _appliedJobsMap[jobId]!;
    }
    return _applications.any((a) => a.jobId == jobId && a.status != ApplicationStatus.withdrawn);
  }

  void listenApplications(String candidateId, {bool force = false}) {
    if (!force && _listeningCandidateId == candidateId && _subscription != null) {
      return;
    }
    if (_listeningCandidateId != null && _listeningCandidateId != candidateId) {
      _applications = [];
      _appliedJobsMap.clear();
    }
    _listeningCandidateId = candidateId;
    _subscription?.cancel();
    _errorMessage = null;
    if (_applications.isEmpty) {
      _isLoading = true;
    }
    notifyListeners();

    _subscription = _repository.listenCandidateApplications(candidateId).listen(
      (apps) {
        if (_listeningCandidateId != candidateId) return;
        final unsynced = _applications.where(
          (local) =>
              local.candidateId == candidateId &&
              !apps.any((remote) => remote.id == local.id || (remote.jobId == local.jobId && remote.candidateId == local.candidateId)),
        ).toList();

        _applications = [...apps, ...unsynced];
        _applications.sort((a, b) {
          final dateA = a.appliedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.appliedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });

        _appliedJobsMap.clear();
        for (final a in _applications) {
          if (a.candidateId == candidateId && a.status != ApplicationStatus.withdrawn) {
            _appliedJobsMap[a.jobId] = true;
          }
        }
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        if (_listeningCandidateId != candidateId) return;
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> loadApplications(String candidateId, {bool isBackground = false}) async {
    if (_listeningCandidateId != null && _listeningCandidateId != candidateId) {
      _subscription?.cancel();
      _subscription = null;
      _applications = [];
      _appliedJobsMap.clear();
    }
    _listeningCandidateId = candidateId;
    if (!isBackground && _applications.isEmpty) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final freshApps = await _repository.getCandidateApplications(candidateId);
      if (_listeningCandidateId != candidateId) return;
      final unsynced = _applications.where(
        (local) =>
            local.candidateId == candidateId &&
            !freshApps.any((remote) => remote.id == local.id || (remote.jobId == local.jobId && remote.candidateId == local.candidateId)),
      ).toList();

      _applications = [...freshApps, ...unsynced];
      _applications.sort((a, b) {
        final dateA = a.appliedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.appliedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      _appliedJobsMap.clear();
      for (final a in _applications) {
        if (a.candidateId == candidateId && a.status != ApplicationStatus.withdrawn) {
          _appliedJobsMap[a.jobId] = true;
        }
      }
    } on Failure catch (e) {
      if (!isBackground) _errorMessage = e.message;
    } catch (e) {
      if (!isBackground) _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> checkHasApplied(String jobId, String candidateId) async {
    try {
      final applied = await _repository.hasCandidateApplied(jobId, candidateId);
      _appliedJobsMap[jobId] = applied;
      notifyListeners();
      return applied;
    } catch (e) {
      return false;
    }
  }

  Future<String?> submitApplication({
    required String jobId,
    required String jobTitle,
    required String companyId,
    required String companyName,
    String? companyLogoUrl,
    required String candidateId,
    required String candidateName,
    required String candidateEmail,
    String? candidatePhone,
    String? candidateHeadline,
    String? candidatePhotoUrl,
    required String cvUrl,
    required String cvFileName,
    String? coverLetter,
    Map<String, dynamic>? questionnaireAnswers,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newApp = JobApplication(
        id: '', // Firestore doc ID
        jobId: jobId,
        jobTitle: jobTitle,
        companyId: companyId,
        companyName: companyName,
        companyLogoUrl: companyLogoUrl,
        candidateId: candidateId,
        candidateName: candidateName,
        candidateEmail: candidateEmail,
        candidatePhone: candidatePhone,
        candidateHeadline: candidateHeadline,
        candidatePhotoUrl: candidatePhotoUrl,
        cvUrl: cvUrl,
        cvFileName: cvFileName,
        coverLetter: coverLetter?.trim(),
        questionnaireAnswers: questionnaireAnswers,
        status: ApplicationStatus.applied,
        appliedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final appId = await _repository.submitApplication(newApp);
      final createdApp = newApp.copyWith(id: appId);
      _applications = [
        createdApp,
        ..._applications.where((a) => a.id != appId && a.jobId != jobId),
      ];
      _appliedJobsMap[jobId] = true;
      _successMessage = 'Application submitted successfully!';
      return appId;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> withdraw(String applicationId) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.withdrawApplication(applicationId);
      final index = _applications.indexWhere((a) => a.id == applicationId);
      if (index != -1) {
        _appliedJobsMap[_applications[index].jobId] = false;
        _applications[index] = _applications[index]
            .copyWith(status: ApplicationStatus.withdrawn);
      }
      _successMessage = 'Application withdrawn.';
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
