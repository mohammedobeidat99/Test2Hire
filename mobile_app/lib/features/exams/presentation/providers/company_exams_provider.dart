import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/exam_template.dart';
import '../../domain/repositories/exam_repository.dart';

class CompanyExamsProvider extends ChangeNotifier {
  final ExamRepository _repository;
  StreamSubscription<List<ExamTemplate>>? _subscription;

  List<ExamTemplate> _exams = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  CompanyExamsProvider({required ExamRepository repository})
      : _repository = repository;

  List<ExamTemplate> get exams => _exams;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  int get totalExamsCount => _exams.length;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void listenCompanyExams(String companyId) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _repository.listenCompanyExams(companyId).listen(
      (list) {
        _exams = list;
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

  Future<void> loadCompanyExams(String companyId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _exams = await _repository.getCompanyExams(companyId);
    } on Failure catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createExam({
    required String companyId,
    required String title,
    required String description,
    int durationMinutes = 45,
    int passingPercentage = 70,
    List<String> questionIds = const [],
    List<String> bankIds = const [],
    bool randomizeQuestions = true,
    bool randomizeOptions = true,
    bool proctoringEnabled = true,
    int totalQuestions = 0,
    int totalPoints = 0,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newExam = ExamTemplate(
        id: '',
        companyId: companyId,
        title: title.trim(),
        description: description.trim(),
        durationMinutes: durationMinutes,
        passingPercentage: passingPercentage,
        questionIds: questionIds,
        bankIds: bankIds,
        randomizeQuestions: randomizeQuestions,
        randomizeOptions: randomizeOptions,
        proctoringEnabled: proctoringEnabled,
        totalQuestions: totalQuestions,
        totalPoints: totalPoints,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final examId = await _repository.createExam(newExam);
      _successMessage = 'Assessment template created successfully!';
      return examId;
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

  Future<bool> updateExam(ExamTemplate exam) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateExam(exam);
      _successMessage = 'Assessment template updated.';
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

  Future<bool> deleteExam(String examId) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteExam(examId);
      _exams.removeWhere((e) => e.id == examId);
      _successMessage = 'Assessment template deleted.';
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

  Future<AssignExamResult?> assignExam({
    required String examId,
    required String applicationId,
    required String candidateId,
    String? jobId,
    int? durationMinutes,
    int? deadlineDays,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.assignExam(
        examId: examId,
        applicationId: applicationId,
        candidateId: candidateId,
        jobId: jobId,
        durationMinutes: durationMinutes,
        deadlineDays: deadlineDays,
      );
      _successMessage = 'Assessment invitation sent to candidate!';
      return result;
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

  Future<String?> quickGenerateExamForRole({
    required String companyId,
    required String roleTitle,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final examId = await _repository.quickGenerateExamForRole(
        companyId: companyId,
        roleTitle: roleTitle,
      );
      _successMessage = 'Assessment template generated successfully!';
      await loadCompanyExams(companyId);
      return examId;
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
