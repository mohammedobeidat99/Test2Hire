import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/candidate_ai_summary.dart';
import '../../domain/entities/candidate_comparison_result.dart';
import '../models/candidate_ai_summary_model.dart';
import '../models/candidate_comparison_model.dart';

abstract class AiAssistantRemoteDataSource {
  Stream<CandidateAiSummary?> listenAiSummary(String applicationId);
  Future<CandidateAiSummary?> getAiSummary(String applicationId);
  Future<CandidateAiSummary> generateCandidateAiSummary(String applicationId);
  Future<CandidateComparisonResult> compareCandidates({
    required List<String> applicationIds,
    required String jobId,
  });
}

class AiAssistantRemoteDataSourceImpl implements AiAssistantRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  AiAssistantRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  Stream<CandidateAiSummary?> listenAiSummary(String applicationId) {
    return _firestore
        .collection('aiSummaries')
        .doc(applicationId)
        .snapshots()
        
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return CandidateAiSummaryModel.fromFirestore(snapshot);
    });
  }

  @override
  Future<CandidateAiSummary?> getAiSummary(String applicationId) async {
    final doc = await _firestore.collection('aiSummaries').doc(applicationId).get();
    if (!doc.exists || doc.data() == null) return null;
    return CandidateAiSummaryModel.fromFirestore(doc);
  }

  @override
  Future<CandidateAiSummary> generateCandidateAiSummary(String applicationId) async {
    final callable = _functions.httpsCallable('generateCandidateAiSummary');
    final response = await callable.call<Map<String, dynamic>>({
      'applicationId': applicationId,
    });

    final data = response.data;
    if (data['summary'] != null) {
      return CandidateAiSummaryModel.fromMap(
        Map<String, dynamic>.from(data['summary'] as Map),
        applicationId,
      );
    }

    final summary = await getAiSummary(applicationId);
    if (summary != null) return summary;

    throw Exception('Failed to generate AI candidate summary.');
  }

  @override
  Future<CandidateComparisonResult> compareCandidates({
    required List<String> applicationIds,
    required String jobId,
  }) async {
    final callable = _functions.httpsCallable('compareCandidatesWithAi');
    final response = await callable.call<Map<String, dynamic>>({
      'applicationIds': applicationIds,
      'jobId': jobId,
    });

    final data = response.data;
    if (data['comparison'] != null) {
      return CandidateComparisonModel.fromMap(
        Map<String, dynamic>.from(data['comparison'] as Map),
      );
    }

    throw Exception('Failed to compare candidates with AI.');
  }
}
