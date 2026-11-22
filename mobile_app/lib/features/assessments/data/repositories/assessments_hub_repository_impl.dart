import '../../../../core/errors/failures.dart';
import '../../domain/entities/take_home_challenge.dart';
import '../../domain/repositories/assessments_hub_repository.dart';
import '../datasources/assessments_remote_data_source.dart';
import '../models/take_home_challenge_model.dart';

class AssessmentsHubRepositoryImpl implements AssessmentsHubRepository {
  final AssessmentsRemoteDataSource _remoteDataSource;

  AssessmentsHubRepositoryImpl({AssessmentsRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? AssessmentsRemoteDataSourceImpl();

  @override
  Stream<List<TakeHomeChallenge>> listenCompanyChallenges(String companyId) {
    try {
      return _remoteDataSource.listenCompanyChallenges(companyId);
    } catch (e) {
      return Stream.error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<List<TakeHomeChallenge>> getCompanyChallenges(String companyId) async {
    try {
      return await _remoteDataSource.getCompanyChallenges(companyId);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<TakeHomeChallenge>> listenAvailableChallenges() {
    try {
      return _remoteDataSource.listenAvailableChallenges();
    } catch (e) {
      return Stream.error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<TakeHomeChallenge?> getChallengeById(String challengeId) async {
    try {
      return await _remoteDataSource.getChallengeById(challengeId);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> createChallenge(TakeHomeChallenge challenge) async {
    try {
      final model = TakeHomeChallengeModel(
        id: challenge.id,
        companyId: challenge.companyId,
        companyName: challenge.companyName,
        jobId: challenge.jobId,
        jobTitle: challenge.jobTitle,
        title: challenge.title,
        brief: challenge.brief,
        detailedInstructions: challenge.detailedInstructions,
        difficulty: challenge.difficulty,
        deadlineDays: challenge.deadlineDays,
        techStack: challenge.techStack,
        deliverables: challenge.deliverables,
        rubrics: challenge.rubrics,
        starterTemplateUrl: challenge.starterTemplateUrl,
        createdAt: challenge.createdAt ?? DateTime.now(),
      );
      await _remoteDataSource.createChallenge(model);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<ChallengeSubmission>> listenChallengeSubmissions(String challengeId) {
    try {
      return _remoteDataSource.listenChallengeSubmissions(challengeId);
    } catch (e) {
      return Stream.error(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<List<ChallengeSubmission>> listenCandidateSubmissions(String candidateId) {
    try {
      return _remoteDataSource.listenCandidateSubmissions(candidateId);
    } catch (e) {
      return Stream.error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<void> submitChallengeSolution({
    required String challengeId,
    required String companyId,
    required String candidateId,
    required String candidateName,
    required String candidateEmail,
    required String githubRepoUrl,
    String? liveDemoUrl,
    String? candidateNotes,
  }) async {
    try {
      final submission = ChallengeSubmissionModel(
        id: '${challengeId}_$candidateId',
        challengeId: challengeId,
        companyId: companyId,
        candidateId: candidateId,
        candidateName: candidateName,
        candidateEmail: candidateEmail,
        githubRepoUrl: githubRepoUrl,
        liveDemoUrl: liveDemoUrl,
        candidateNotes: candidateNotes,
        status: ChallengeSubmissionStatus.submitted,
        submittedAt: DateTime.now(),
      );
      await _remoteDataSource.submitChallengeSolution(submission);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> gradeSubmission({
    required String submissionId,
    required double score,
    required String reviewerFeedback,
    required ChallengeSubmissionStatus status,
  }) async {
    try {
      await _remoteDataSource.gradeSubmission(
        submissionId: submissionId,
        score: score,
        reviewerFeedback: reviewerFeedback,
        status: status,
      );
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
