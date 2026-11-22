import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/job_application.dart';
import '../models/job_application_model.dart';

abstract class ApplicationRemoteDataSource {
  Future<String> submitApplication(JobApplicationModel application);
  Future<List<JobApplicationModel>> getCandidateApplications(String candidateId);
  Stream<List<JobApplicationModel>> listenCandidateApplications(String candidateId);
  Future<List<JobApplicationModel>> getJobApplicants(String jobId);
  Stream<List<JobApplicationModel>> listenJobApplicants(String jobId);
  Future<void> updateApplicationStatus(
    String applicationId,
    ApplicationStatus status, {
    String? reason,
  });
  Future<void> withdrawApplication(String applicationId);
  Future<bool> hasCandidateApplied(String jobId, String candidateId);
  Future<AiParsedCv> parseResumeWithAI(String applicationId);
}

class ApplicationRemoteDataSourceImpl implements ApplicationRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  ApplicationRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _applicationsRef =>
      _firestore.collection('applications');

  @override
  Future<String> submitApplication(JobApplicationModel application) async {
    // 1. Duplicate check
    final alreadyApplied = await hasCandidateApplied(
      application.jobId,
      application.candidateId,
    );
    if (alreadyApplied) {
      throw Exception('You have already submitted an application for this vacancy.');
    }

    // 2. Add to collection (onApplicationCreated Cloud Function handles company notification + applicantsCount)
    final docRef = await _applicationsRef.add(application.toFirestore());

    return docRef.id;
  }

  @override
  Future<List<JobApplicationModel>> getCandidateApplications(
      String candidateId) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _applicationsRef
          .where('candidateId', isEqualTo: candidateId)
          .orderBy('appliedAt', descending: true)
          .get();
    } catch (_) {
      snapshot = await _applicationsRef
          .where('candidateId', isEqualTo: candidateId)
          .get();
    }

    var apps = snapshot.docs
        .map((doc) => JobApplicationModel.fromFirestore(doc))
        .toList();
    apps.sort((a, b) {
      final dateA = a.appliedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.appliedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });
    return apps;
  }

  @override
  Stream<List<JobApplicationModel>> listenCandidateApplications(
      String candidateId) {
    return _applicationsRef
        .where('candidateId', isEqualTo: candidateId)
        .snapshots()
        .map((snapshot) {
      final apps = snapshot.docs
          .map((doc) => JobApplicationModel.fromFirestore(doc))
          .toList();
      apps.sort((a, b) {
        final dateA = a.appliedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.appliedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      return apps;
    });
  }

  @override
  Future<List<JobApplicationModel>> getJobApplicants(String jobId) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _applicationsRef
          .where('jobId', isEqualTo: jobId)
          .orderBy('appliedAt', descending: true)
          .get();
    } catch (_) {
      snapshot = await _applicationsRef
          .where('jobId', isEqualTo: jobId)
          .get();
    }

    var apps = snapshot.docs
        .map((doc) => JobApplicationModel.fromFirestore(doc))
        .toList();
    apps.sort((a, b) {
      final dateA = a.appliedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.appliedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });
    return apps;
  }

  @override
  Stream<List<JobApplicationModel>> listenJobApplicants(String jobId) {
    return _applicationsRef
        .where('jobId', isEqualTo: jobId)
        .snapshots()
        .map((snapshot) {
      final apps = snapshot.docs
          .map((doc) => JobApplicationModel.fromFirestore(doc))
          .toList();
      apps.sort((a, b) {
        final dateA = a.appliedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.appliedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      return apps;
    });
  }

  @override
  Future<void> updateApplicationStatus(
    String applicationId,
    ApplicationStatus status, {
    String? reason,
  }) async {
    final updateData = <String, dynamic>{
      'status': status.toShortString(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (reason != null && reason.trim().isNotEmpty) {
      updateData['rejectionReason'] = reason.trim();
    }

    await _applicationsRef.doc(applicationId).update(updateData);
  }

  @override
  Future<void> withdrawApplication(String applicationId) async {
    await _applicationsRef.doc(applicationId).update({
      'status': ApplicationStatus.withdrawn.toShortString(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      final docSnap = await _applicationsRef.doc(applicationId).get();
      if (docSnap.exists) {
        final data = docSnap.data() ?? {};
        final companyId = data['companyId'] as String?;
        final candidateName = data['candidateName'] as String? ?? 'المرشح';
        final jobTitle = data['jobTitle'] as String? ?? 'الوظيفة';
        if (companyId != null && companyId.isNotEmpty) {
          await _firestore.collection('notifications').add({
            'userId': companyId,
            'title': 'انسحاب مرشح من طلب التوظيف',
            'body': 'قام المرشح ($candidateName) بسحب طلب التقديم على وظيفة ($jobTitle).',
            'type': 'APPLICATION_WITHDRAWN',
            'entityId': applicationId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {}
  }

  @override
  Future<bool> hasCandidateApplied(String jobId, String candidateId) async {
    try {
      final snapshot = await _applicationsRef
          .where('jobId', isEqualTo: jobId)
          .where('candidateId', isEqualTo: candidateId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AiParsedCv> parseResumeWithAI(String applicationId) async {
    final callable = _functions.httpsCallable('parseResumeWithAI');
    final result = await callable.call<Map<String, dynamic>>({
      'applicationId': applicationId,
    });

    final data = result.data;
    final parsedMap = data['parsedResult'] as Map<String, dynamic>?;
    if (parsedMap == null) {
      throw Exception('Failed to receive parsed AI resume result from Cloud Functions.');
    }

    return AiParsedCv.fromMap(parsedMap);
  }
}

