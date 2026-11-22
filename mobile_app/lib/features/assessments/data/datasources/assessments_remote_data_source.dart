import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/take_home_challenge_model.dart';
import '../../domain/entities/take_home_challenge.dart';

abstract class AssessmentsRemoteDataSource {
  Stream<List<TakeHomeChallengeModel>> listenCompanyChallenges(String companyId);
  Future<List<TakeHomeChallengeModel>> getCompanyChallenges(String companyId);
  Stream<List<TakeHomeChallengeModel>> listenAvailableChallenges();
  Future<TakeHomeChallengeModel?> getChallengeById(String challengeId);
  Future<void> createChallenge(TakeHomeChallengeModel challenge);

  Stream<List<ChallengeSubmissionModel>> listenChallengeSubmissions(String challengeId);
  Stream<List<ChallengeSubmissionModel>> listenCandidateSubmissions(String candidateId);
  Future<void> submitChallengeSolution(ChallengeSubmissionModel submission);
  Future<void> gradeSubmission({
    required String submissionId,
    required double score,
    required String reviewerFeedback,
    required ChallengeSubmissionStatus status,
  });
}

class AssessmentsRemoteDataSourceImpl implements AssessmentsRemoteDataSource {
  final FirebaseFirestore _firestore;

  AssessmentsRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<TakeHomeChallengeModel>> listenCompanyChallenges(String companyId) {
    return _firestore
        .collection('challenges')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TakeHomeChallengeModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<List<TakeHomeChallengeModel>> getCompanyChallenges(String companyId) async {
    final snapshot = await _firestore
        .collection('challenges')
        .where('companyId', isEqualTo: companyId)
        .get();
    return snapshot.docs
        .map((doc) => TakeHomeChallengeModel.fromFirestore(doc))
        .toList();
  }

  @override
  Stream<List<TakeHomeChallengeModel>> listenAvailableChallenges() {
    return _firestore
        .collection('challenges')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TakeHomeChallengeModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<TakeHomeChallengeModel?> getChallengeById(String challengeId) async {
    final doc = await _firestore.collection('challenges').doc(challengeId).get();
    if (!doc.exists) return null;
    return TakeHomeChallengeModel.fromFirestore(doc);
  }

  @override
  Future<void> createChallenge(TakeHomeChallengeModel challenge) async {
    final docRef = challenge.id.isEmpty
        ? _firestore.collection('challenges').doc()
        : _firestore.collection('challenges').doc(challenge.id);

    await docRef.set(challenge.toMap());
  }

  @override
  Stream<List<ChallengeSubmissionModel>> listenChallengeSubmissions(String challengeId) {
    return _firestore
        .collection('challengeSubmissions')
        .where('challengeId', isEqualTo: challengeId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeSubmissionModel.fromFirestore(doc))
            .toList());
  }

  @override
  Stream<List<ChallengeSubmissionModel>> listenCandidateSubmissions(String candidateId) {
    return _firestore
        .collection('challengeSubmissions')
        .where('candidateId', isEqualTo: candidateId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeSubmissionModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<void> submitChallengeSolution(ChallengeSubmissionModel submission) async {
    final docRef = submission.id.isEmpty
        ? _firestore.collection('challengeSubmissions').doc()
        : _firestore.collection('challengeSubmissions').doc(submission.id);

    await docRef.set(submission.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> gradeSubmission({
    required String submissionId,
    required double score,
    required String reviewerFeedback,
    required ChallengeSubmissionStatus status,
  }) async {
    await _firestore.collection('challengeSubmissions').doc(submissionId).update({
      'score': score,
      'reviewerFeedback': reviewerFeedback,
      'status': status.toShortString(),
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }
}
