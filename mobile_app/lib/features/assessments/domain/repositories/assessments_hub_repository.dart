import '../entities/take_home_challenge.dart';

abstract class AssessmentsHubRepository {
  Stream<List<TakeHomeChallenge>> listenCompanyChallenges(String companyId);
  Future<List<TakeHomeChallenge>> getCompanyChallenges(String companyId);

  Stream<List<TakeHomeChallenge>> listenAvailableChallenges();
  Future<TakeHomeChallenge?> getChallengeById(String challengeId);

  Future<void> createChallenge(TakeHomeChallenge challenge);

  Stream<List<ChallengeSubmission>> listenChallengeSubmissions(String challengeId);
  Stream<List<ChallengeSubmission>> listenCandidateSubmissions(String candidateId);

  Future<void> submitChallengeSolution({
    required String challengeId,
    required String companyId,
    required String candidateId,
    required String candidateName,
    required String candidateEmail,
    required String githubRepoUrl,
    String? liveDemoUrl,
    String? candidateNotes,
  });

  Future<void> gradeSubmission({
    required String submissionId,
    required double score,
    required String reviewerFeedback,
    required ChallengeSubmissionStatus status,
  });
}
