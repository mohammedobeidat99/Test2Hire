import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mobile_app/features/evaluation/domain/entities/candidate_scorecard.dart';
import 'package:mobile_app/features/evaluation/domain/repositories/evaluation_repository.dart';

enum RankingSortFilter {
  compositeScore,
  cvMatch,
  examScore,
  interviewScore,
}

class EvaluationProvider extends ChangeNotifier {
  final EvaluationRepository _repository;

  CandidateScorecard? _activeScorecard;
  List<CandidateScorecard> _jobRankings = [];
  RankingSortFilter _sortFilter = RankingSortFilter.compositeScore;
  ScorecardRecommendation? _recommendationFilter;

  bool _isLoading = false;
  bool _isCalculating = false;
  String? _errorMessage;
  String? _successMessage;

  StreamSubscription<CandidateScorecard?>? _scorecardSubscription;
  StreamSubscription<List<CandidateScorecard>>? _rankingsSubscription;

  EvaluationProvider({required EvaluationRepository repository})
      : _repository = repository;

  CandidateScorecard? get activeScorecard => _activeScorecard;
  List<CandidateScorecard> get jobRankings => _getFilteredRankings();
  RankingSortFilter get sortFilter => _sortFilter;
  ScorecardRecommendation? get recommendationFilter => _recommendationFilter;
  bool get isLoading => _isLoading;
  bool get isCalculating => _isCalculating;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void setSortFilter(RankingSortFilter filter) {
    _sortFilter = filter;
    notifyListeners();
  }

  void setRecommendationFilter(ScorecardRecommendation? recommendation) {
    _recommendationFilter = recommendation;
    notifyListeners();
  }

  List<CandidateScorecard> _getFilteredRankings() {
    var list = List<CandidateScorecard>.from(_jobRankings);

    if (_recommendationFilter != null) {
      list = list.where((s) => s.recommendation == _recommendationFilter).toList();
    }

    switch (_sortFilter) {
      case RankingSortFilter.compositeScore:
        list.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
        break;
      case RankingSortFilter.cvMatch:
        list.sort((a, b) => b.breakdown.cvMatchScore.compareTo(a.breakdown.cvMatchScore));
        break;
      case RankingSortFilter.examScore:
        list.sort((a, b) => b.breakdown.examScore.compareTo(a.breakdown.examScore));
        break;
      case RankingSortFilter.interviewScore:
        list.sort((a, b) => b.breakdown.interviewScore.compareTo(a.breakdown.interviewScore));
        break;
    }

    return list;
  }

  void listenScorecard(String applicationId) {
    _scorecardSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _scorecardSubscription = _repository.listenScorecard(applicationId).listen(
      (scorecard) {
        _activeScorecard = scorecard;
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

  void listenJobRankings(String jobId) {
    _rankingsSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _rankingsSubscription = _repository.listenJobRankings(jobId).listen(
      (items) {
        _jobRankings = items;
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

  Future<void> getJobRankings(String jobId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _jobRankings = await _repository.getJobRankings(jobId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> calculateScorecard({
    required String applicationId,
    ScorecardWeights? customWeights,
  }) async {
    _isCalculating = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final scorecard = await _repository.calculateScorecard(
        applicationId: applicationId,
        customWeights: customWeights,
      );
      _activeScorecard = scorecard;
      _isCalculating = false;
      _successMessage = 'تم حساب بطاقة تقييم المرشح بنجاح';
      notifyListeners();
    } catch (e) {
      _isCalculating = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> recalculateJobRankings(String jobId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.recalculateJobRankings(jobId);
      final rankings = await _repository.getJobRankings(jobId);
      _jobRankings = rankings;
      _isLoading = false;
      _successMessage = 'تمت إعادة ترتيب وتصنيف المرشحين';
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _scorecardSubscription?.cancel();
    _rankingsSubscription?.cancel();
    super.dispose();
  }
}
