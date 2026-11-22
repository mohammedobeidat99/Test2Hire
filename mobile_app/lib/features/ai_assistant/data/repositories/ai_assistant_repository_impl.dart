import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/candidate_ai_summary.dart';
import '../../domain/entities/candidate_comparison_result.dart';
import '../../domain/repositories/ai_assistant_repository.dart';
import '../datasources/ai_assistant_remote_data_source.dart';

class AiAssistantRepositoryImpl implements AiAssistantRepository {
  final AiAssistantRemoteDataSource _remoteDataSource;

  AiAssistantRepositoryImpl({required AiAssistantRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Stream<CandidateAiSummary?> listenAiSummary(String applicationId) {
    return _remoteDataSource.listenAiSummary(applicationId);
  }

  @override
  Future<CandidateAiSummary?> getAiSummary(String applicationId) async {
    try {
      return await _remoteDataSource.getAiSummary(applicationId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to get AI summary.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<CandidateAiSummary> generateCandidateAiSummary(String applicationId) async {
    try {
      return await _remoteDataSource.generateCandidateAiSummary(applicationId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to generate AI summary.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<CandidateComparisonResult> compareCandidates({
    required List<String> applicationIds,
    required String jobId,
  }) async {
    try {
      return await _remoteDataSource.compareCandidates(
        applicationIds: applicationIds,
        jobId: jobId,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to compare candidates with AI.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
