import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/candidate_scorecard.dart';
import '../models/candidate_scorecard_model.dart';

abstract class EvaluationRemoteDataSource {
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

class EvaluationRemoteDataSourceImpl implements EvaluationRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  EvaluationRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  Stream<CandidateScorecard?> listenScorecard(String applicationId) {
    return _firestore
        .collection('scorecards')
        .doc(applicationId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return CandidateScorecardModel.fromFirestore(snapshot);
    });
  }

  @override
  Future<CandidateScorecard?> getScorecard(String applicationId) async {
    final doc = await _firestore.collection('scorecards').doc(applicationId).get();
    if (!doc.exists || doc.data() == null) return null;
    return CandidateScorecardModel.fromFirestore(doc);
  }

  @override
  Stream<List<CandidateScorecard>> listenJobRankings(String jobId) {
    return _firestore
        .collection('scorecards')
        .where('jobId', isEqualTo: jobId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => CandidateScorecardModel.fromFirestore(doc))
          .toList();
      items.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
      return items;
    });
  }

  @override
  Future<List<CandidateScorecard>> getJobRankings(String jobId) async {
    final snapshot = await _firestore
        .collection('scorecards')
        .where('jobId', isEqualTo: jobId)
        .get();

    final items = snapshot.docs
        .map((doc) => CandidateScorecardModel.fromFirestore(doc))
        .toList();
    items.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
    return items;
  }

  @override
  Future<CandidateScorecard> calculateScorecard({
    required String applicationId,
    ScorecardWeights? customWeights,
  }) async {
    final callable = _functions.httpsCallable('calculateCandidateScorecard');
    await callable.call<Map<String, dynamic>>({
      'applicationId': applicationId,
      'customWeights': customWeights?.toMap(),
    });

    final scorecard = await getScorecard(applicationId);
    if (scorecard != null) {
      return scorecard;
    }

    // Fallback: fetch from application doc
    final appDoc = await _firestore.collection('applications').doc(applicationId).get();
    final data = appDoc.data() ?? {};
    return CandidateScorecardModel.fromMap(data, applicationId);
  }

  @override
  Future<void> recalculateJobRankings(String jobId) async {
    final callable = _functions.httpsCallable('recalculateJobRankings');
    await callable.call<Map<String, dynamic>>({
      'jobId': jobId,
    });
  }
}
