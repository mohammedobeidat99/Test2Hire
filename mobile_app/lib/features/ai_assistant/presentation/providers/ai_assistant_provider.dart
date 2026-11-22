import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mobile_app/features/ai_assistant/domain/entities/candidate_ai_summary.dart';
import 'package:mobile_app/features/ai_assistant/domain/entities/candidate_comparison_result.dart';
import 'package:mobile_app/features/ai_assistant/domain/repositories/ai_assistant_repository.dart';

class AiAssistantProvider extends ChangeNotifier {
  final AiAssistantRepository _repository;

  CandidateAiSummary? _activeSummary;
  CandidateComparisonResult? _activeComparison;

  bool _isLoading = false;
  bool _isGenerating = false;
  bool _isComparing = false;
  String? _errorMessage;
  String? _successMessage;

  StreamSubscription<CandidateAiSummary?>? _summarySubscription;

  AiAssistantProvider({required AiAssistantRepository repository})
      : _repository = repository;

  CandidateAiSummary? get activeSummary => _activeSummary;
  CandidateComparisonResult? get activeComparison => _activeComparison;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  bool get isComparing => _isComparing;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void listenAiSummary(String applicationId) {
    _summarySubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _summarySubscription = _repository.listenAiSummary(applicationId).listen(
      (summary) {
        _activeSummary = summary;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = err.toString();
        notifyListeners();
      },
    );
  }

  Future<void> generateCandidateAiSummary(String applicationId) async {
    _isGenerating = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final summary = await _repository.generateCandidateAiSummary(applicationId);
      _activeSummary = summary;
      _isGenerating = false;
      _successMessage = 'تم توليد التحليل الذكي للمرشح بنجاح بواسطة Gemini AI';
      notifyListeners();
    } catch (e) {
      _isGenerating = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> compareCandidates({
    required List<String> applicationIds,
    required String jobId,
  }) async {
    _isComparing = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final comparison = await _repository.compareCandidates(
        applicationIds: applicationIds,
        jobId: jobId,
      );
      _activeComparison = comparison;
      _isComparing = false;
      _successMessage = 'تمت المقارنة التنافسية بين المرشحين بنجاح';
      notifyListeners();
    } catch (e) {
      _isComparing = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearComparison() {
    _activeComparison = null;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _summarySubscription?.cancel();
    super.dispose();
  }
}
