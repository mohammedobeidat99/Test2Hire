import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/interview.dart';
import '../../domain/repositories/interview_repository.dart';

class CandidateInterviewsProvider extends ChangeNotifier {
  final InterviewRepository _repository;
  StreamSubscription<List<Interview>>? _subscription;

  List<Interview> _interviews = [];
  bool _isLoading = false;
  bool _isResponding = false;
  String? _errorMessage;
  String? _successMessage;

  CandidateInterviewsProvider({required InterviewRepository repository})
      : _repository = repository;

  List<Interview> get interviews => _interviews;
  bool get isLoading => _isLoading;
  bool get isResponding => _isResponding;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  List<Interview> get pendingInterviews =>
      _interviews.where((i) => i.status == InterviewStatus.pendingCandidate).toList();

  List<Interview> get confirmedInterviews =>
      _interviews.where((i) => i.status == InterviewStatus.confirmed).toList();

  List<Interview> get pastInterviews => _interviews
      .where((i) =>
          i.status == InterviewStatus.completed ||
          i.status == InterviewStatus.cancelled ||
          i.status == InterviewStatus.declined)
      .toList();

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
    _interviews = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void listenCandidateInterviews(String candidateId, {bool force = false}) {
    if (!force && _listeningCandidateId == candidateId && _subscription != null) {
      return;
    }
    if (_listeningCandidateId != null && _listeningCandidateId != candidateId) {
      _interviews = [];
    }
    _listeningCandidateId = candidateId;
    _subscription?.cancel();
    _errorMessage = null;
    if (_interviews.isEmpty) {
      _isLoading = true;
    }
    notifyListeners();

    _subscription = _repository.listenCandidateInterviews(candidateId).listen(
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

  Future<void> loadCandidateInterviews(String candidateId) async {
    if (_listeningCandidateId != null && _listeningCandidateId != candidateId) {
      _subscription?.cancel();
      _subscription = null;
      _interviews = [];
    }
    _listeningCandidateId = candidateId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.getCandidateInterviews(candidateId);
      if (_listeningCandidateId != candidateId) return;
      _interviews = fetched;
    } on Failure catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> respondToInterview({
    required String interviewId,
    required String response, // "ACCEPT" | "DECLINE"
    int? selectedSlotIndex,
    String? declineReason,
  }) async {
    _isResponding = true;
    _errorMessage = null;

    // 0ms Optimistic UI Update
    final index = _interviews.indexWhere((i) => i.id == interviewId);
    Interview? previousInterview;
    if (index != -1) {
      previousInterview = _interviews[index];
      final newStatus = response == 'ACCEPT'
          ? InterviewStatus.confirmed
          : InterviewStatus.declined;

      List<InterviewSlot> updatedSlots = previousInterview.slots;
      if (selectedSlotIndex != null && selectedSlotIndex < updatedSlots.length) {
        updatedSlots = updatedSlots.asMap().entries.map((e) {
          return e.value.copyWith(isSelected: e.key == selectedSlotIndex);
        }).toList();
      }

      _interviews = List<Interview>.from(_interviews);
      _interviews[index] = previousInterview.copyWith(
        status: newStatus,
        selectedSlotIndex: selectedSlotIndex ?? 0,
        slots: updatedSlots,
        declineReason: declineReason,
        updatedAt: DateTime.now(),
      );
    }
    notifyListeners();

    try {
      await _repository.respondToInterview(
        interviewId: interviewId,
        response: response,
        selectedSlotIndex: selectedSlotIndex,
        declineReason: declineReason,
      );

      _successMessage = response == 'ACCEPT'
          ? 'تم تأكيد موعد المقابلة بنجاح!'
          : 'تم الاعتذار عن المقابلة.';
      return true;
    } on Failure catch (e) {
      if (index != -1 && previousInterview != null) {
        _interviews = List<Interview>.from(_interviews);
        _interviews[index] = previousInterview;
      }
      _errorMessage = e.message;
      return false;
    } catch (e) {
      if (index != -1 && previousInterview != null) {
        _interviews = List<Interview>.from(_interviews);
        _interviews[index] = previousInterview;
      }
      _errorMessage = e.toString();
      return false;
    } finally {
      _isResponding = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
