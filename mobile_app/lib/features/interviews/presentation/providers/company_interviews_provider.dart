import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/interview.dart';
import '../../domain/repositories/interview_repository.dart';

class CompanyInterviewsProvider extends ChangeNotifier {
  final InterviewRepository _repository;
  StreamSubscription<List<Interview>>? _subscription;

  List<Interview> _interviews = [];
  InterviewStatus? _statusFilter;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  CompanyInterviewsProvider({required InterviewRepository repository})
      : _repository = repository;

  List<Interview> get interviews {
    if (_statusFilter == null) return _interviews;
    return _interviews.where((i) => i.status == _statusFilter).toList();
  }

  List<Interview> get allInterviews => _interviews;
  InterviewStatus? get statusFilter => _statusFilter;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  int get totalCount => _interviews.length;
  int get pendingCount =>
      _interviews.where((i) => i.status == InterviewStatus.pendingCandidate).length;
  int get confirmedCount =>
      _interviews.where((i) => i.status == InterviewStatus.confirmed).length;
  int get completedCount =>
      _interviews.where((i) => i.status == InterviewStatus.completed).length;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void setStatusFilter(InterviewStatus? filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  void listenCompanyInterviews(String companyId) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _repository.listenCompanyInterviews(companyId).listen(
      (list) {
        _interviews = list;
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

  Future<void> loadCompanyInterviews(String companyId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _interviews = await _repository.getCompanyInterviews(companyId);
    } on Failure catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> scheduleInterview({
    required String applicationId,
    required String title,
    required String description,
    required InterviewType interviewType,
    String? meetingUrl,
    String? location,
    required List<InterviewSlot> slots,
    List<String> interviewerNames = const [],
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final interviewId = await _repository.scheduleInterview(
        applicationId: applicationId,
        title: title,
        description: description,
        interviewType: interviewType,
        meetingUrl: meetingUrl,
        location: location,
        slots: slots,
        interviewerNames: interviewerNames,
      );

      _successMessage = 'Interview invitation successfully dispatched to candidate!';
      return interviewId;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> submitFeedback({
    required String interviewId,
    required int score,
    required String recommendation,
    required String notes,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.submitInterviewFeedback(
        interviewId: interviewId,
        score: score,
        recommendation: recommendation,
        notes: notes,
      );

      final index = _interviews.indexWhere((i) => i.id == interviewId);
      if (index != -1) {
        final existing = _interviews[index];
        _interviews[index] = existing.copyWith(
          status: InterviewStatus.completed,
          feedback: InterviewFeedback(
            interviewerId: 'company_evaluator',
            score: score,
            recommendation: recommendation,
            notes: notes,
            submittedAt: DateTime.now(),
          ),
          updatedAt: DateTime.now(),
        );
      }

      _successMessage = 'Interview evaluation feedback saved successfully!';
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

  Future<bool> cancelInterview(String interviewId, {String? reason}) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.cancelInterview(interviewId, reason: reason);

      final index = _interviews.indexWhere((i) => i.id == interviewId);
      if (index != -1) {
        _interviews[index] = _interviews[index].copyWith(
          status: InterviewStatus.cancelled,
          declineReason: reason,
          updatedAt: DateTime.now(),
        );
      }

      _successMessage = 'Interview cancelled.';
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
    _subscription?.cancel();
    super.dispose();
  }
}
