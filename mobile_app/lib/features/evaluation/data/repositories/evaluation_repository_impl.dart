import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/candidate_scorecard.dart';
import '../../domain/repositories/evaluation_repository.dart';
import '../datasources/evaluation_remote_data_source.dart';

class EvaluationRepositoryImpl implements EvaluationRepository {
  final EvaluationRemoteDataSource _remoteDataSource;

  EvaluationRepositoryImpl({required EvaluationRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Stream<CandidateScorecard?> listenScorecard(String applicationId) {
    return _remoteDataSource.listenScorecard(applicationId);
  }

  @override
  Future<CandidateScorecard?> getScorecard(String applicationId) async {
    try {
      return await _remoteDataSource.getScorecard(applicationId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to get scorecard.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<CandidateScorecard>> listenJobRankings(String jobId) {
    return _remoteDataSource.listenJobRankings(jobId);
  }

  @override
  Future<List<CandidateScorecard>> getJobRankings(String jobId) async {
    try {
      return await _remoteDataSource.getJobRankings(jobId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to get job rankings.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<CandidateScorecard> calculateScorecard({
    required String applicationId,
    ScorecardWeights? customWeights,
  }) async {
    try {
      return await _remoteDataSource.calculateScorecard(
        applicationId: applicationId,
        customWeights: customWeights,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to calculate scorecard.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> recalculateJobRankings(String jobId) async {
    try {
      await _remoteDataSource.recalculateJobRankings(jobId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to recalculate rankings.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
