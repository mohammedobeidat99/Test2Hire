import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/take_home_challenge.dart';
import '../../domain/repositories/assessments_hub_repository.dart';

class AssessmentsHubProvider extends ChangeNotifier {
  final AssessmentsHubRepository _repository;

  List<TakeHomeChallenge> _challenges = [];
  TakeHomeChallenge? _selectedChallenge;
  List<ChallengeSubmission> _submissions = [];
  List<ChallengeSubmission> _candidateSubmissions = [];

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  StreamSubscription<List<TakeHomeChallenge>>? _challengesSubscription;
  StreamSubscription<List<ChallengeSubmission>>? _submissionsSubscription;
  StreamSubscription<List<ChallengeSubmission>>? _candidateSubmissionsSubscription;
  String? _activeCandidateId;
  String? _activeCompanyId;

  AssessmentsHubProvider({required AssessmentsHubRepository repository})
      : _repository = repository;

  List<TakeHomeChallenge> get challenges => _challenges;
  TakeHomeChallenge? get selectedChallenge => _selectedChallenge;
  List<ChallengeSubmission> get submissions => _submissions;
  List<ChallengeSubmission> get candidateSubmissions => _candidateSubmissions;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void reset() {
    _challengesSubscription?.cancel();
    _challengesSubscription = null;
    _submissionsSubscription?.cancel();
    _submissionsSubscription = null;
    _candidateSubmissionsSubscription?.cancel();
    _candidateSubmissionsSubscription = null;
    _activeCandidateId = null;
    _activeCompanyId = null;
    _challenges = [];
    _selectedChallenge = null;
    _submissions = [];
    _candidateSubmissions = [];
    _isLoading = false;
    _isSubmitting = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void listenCompanyChallenges(String companyId) {
    if (_activeCompanyId != companyId) {
      _challenges = [];
      _submissions = [];
      _selectedChallenge = null;
    }
    _activeCompanyId = companyId;
    _challengesSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _challengesSubscription = _repository.listenCompanyChallenges(companyId).listen(
      (list) {
        if (_activeCompanyId != companyId) return;
        _challenges = list;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = err.toString();
        notifyListeners();
      },
    );
  }

  void listenAvailableChallenges() {
    if (_activeCompanyId != null) {
      _challenges = [];
      _submissions = [];
      _selectedChallenge = null;
      _activeCompanyId = null;
    }
    _challengesSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _challengesSubscription = _repository.listenAvailableChallenges().listen(
      (list) {
        _challenges = list;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = err.toString();
        notifyListeners();
      },
    );
  }

  Future<void> loadChallengeById(String challengeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedChallenge = await _repository.getChallengeById(challengeId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void listenChallengeSubmissions(String challengeId) {
    _submissionsSubscription?.cancel();
    _submissionsSubscription = _repository.listenChallengeSubmissions(challengeId).listen(
      (list) {
        _submissions = list;
        notifyListeners();
      },
      onError: (err) {
        _errorMessage = err.toString();
        notifyListeners();
      },
    );
  }

  void listenCandidateSubmissions(String candidateId) {
    if (_activeCandidateId != candidateId) {
      _candidateSubmissions = [];
      notifyListeners();
    }
    _activeCandidateId = candidateId;
    _candidateSubmissionsSubscription?.cancel();
    _candidateSubmissionsSubscription = _repository.listenCandidateSubmissions(candidateId).listen(
      (list) {
        if (_activeCandidateId != candidateId) return;
        _candidateSubmissions = list;
        notifyListeners();
      },
      onError: (err) {
        _errorMessage = err.toString();
        notifyListeners();
      },
    );
  }

  Future<bool> createChallenge(TakeHomeChallenge challenge) async {
    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _repository.createChallenge(challenge);
      _isSubmitting = false;
      _successMessage = 'تم إنشاء التحدي العملي بنجاح';
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitChallengeSolution({
    required String challengeId,
    required String companyId,
    required String candidateId,
    required String candidateName,
    required String candidateEmail,
    required String githubRepoUrl,
    String? liveDemoUrl,
    String? candidateNotes,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _repository.submitChallengeSolution(
        challengeId: challengeId,
        companyId: companyId,
        candidateId: candidateId,
        candidateName: candidateName,
        candidateEmail: candidateEmail,
        githubRepoUrl: githubRepoUrl,
        liveDemoUrl: liveDemoUrl,
        candidateNotes: candidateNotes,
      );
      _isSubmitting = false;
      _successMessage = 'تم تسليم المشروع بنجاح وسيتم إشعارك فور التقييم!';
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> gradeSubmission({
    required String submissionId,
    required double score,
    required String reviewerFeedback,
    required ChallengeSubmissionStatus status,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _repository.gradeSubmission(
        submissionId: submissionId,
        score: score,
        reviewerFeedback: reviewerFeedback,
        status: status,
      );
      _isSubmitting = false;
      _successMessage = 'تم تسجيل تقييم المشروع بنجاح';
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
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
    _challengesSubscription?.cancel();
    _submissionsSubscription?.cancel();
    _candidateSubmissionsSubscription?.cancel();
    super.dispose();
  }
}
