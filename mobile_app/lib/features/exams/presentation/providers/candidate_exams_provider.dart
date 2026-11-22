import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/exam_template.dart';
import '../../domain/repositories/exam_repository.dart';

class CandidateExamsProvider extends ChangeNotifier {
  final ExamRepository _repository;
  StreamSubscription<List<ExamAttempt>>? _subscription;

  List<ExamAttempt> _attempts = [];
  bool _isLoading = false;
  String? _errorMessage;

  CandidateExamsProvider({required ExamRepository repository})
      : _repository = repository;

  List<ExamAttempt> get attempts => _attempts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<ExamAttempt> get pendingAttempts =>
      _attempts.where((a) => a.isPending).toList();

  List<ExamAttempt> get inProgressAttempts =>
      _attempts.where((a) => a.isInProgress).toList();

  List<ExamAttempt> get completedAttempts =>
      _attempts.where((a) => a.isCompleted).toList();

  int get pendingCount => pendingAttempts.length;
  int get inProgressCount => inProgressAttempts.length;
  int get completedCount => completedAttempts.length;

  String? _listeningCandidateId;

  void reset() {
    _subscription?.cancel();
    _subscription = null;
    _listeningCandidateId = null;
    _attempts = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void listenCandidateAttempts(String candidateId, {bool force = false}) {
    if (!force && _listeningCandidateId == candidateId && _subscription != null) {
      return;
    }
    if (_listeningCandidateId != null && _listeningCandidateId != candidateId) {
      _attempts = [];
    }
    _listeningCandidateId = candidateId;
    _subscription?.cancel();
    _errorMessage = null;
    if (_attempts.isEmpty) {
      _isLoading = true;
    }
    notifyListeners();

    _subscription = _repository.listenCandidateAttempts(candidateId).listen(
      (list) {
        _attempts = list;
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

  Future<void> loadCandidateAttempts(String candidateId, {bool isBackground = false}) async {
    if (_listeningCandidateId != null && _listeningCandidateId != candidateId) {
      _subscription?.cancel();
      _subscription = null;
      _attempts = [];
    }
    _listeningCandidateId = candidateId;
    if (!isBackground) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final fetched = await _repository.getCandidateAttempts(candidateId);
      if (_listeningCandidateId != candidateId) return;
      _attempts = fetched;
    } on Failure catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
