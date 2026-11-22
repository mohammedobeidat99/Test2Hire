import 'package:mobile_app/features/evaluation/domain/entities/candidate_scorecard.dart';

abstract class EvaluationRepository {
  Stream<CandidateScorecard?> listenScorecard(String applicationId);
  Future<CandidateScorecard?> getScorecard(String applicationId);
  Stream<List<CandidateScorecard>> listenJobRankings(String jobId);
  Future<List<CandidateScorecard>> getJobRankings(String jobId);
  Future<CandidateScorecard> calculateScorecard({
    required String applicationId,
    ScorecardWeights? customWeights,
  });
  Future<void> recalculateJobRankings(String jobId);
}
