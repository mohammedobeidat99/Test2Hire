import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/interview.dart';
import '../models/interview_model.dart';

abstract class InterviewRemoteDataSource {
  Future<String> scheduleInterview({
    required String applicationId,
    required String title,
    required String description,
    required InterviewType interviewType,
    String? meetingUrl,
    String? location,
    required List<InterviewSlot> slots,
    List<String> interviewerNames = const [],
  });

  Future<List<InterviewModel>> getCompanyInterviews(String companyId);
  Stream<List<InterviewModel>> listenCompanyInterviews(String companyId);

  Future<List<InterviewModel>> getCandidateInterviews(String candidateId);
  Stream<List<InterviewModel>> listenCandidateInterviews(String candidateId);

  Future<void> respondToInterview({
    required String interviewId,
    required String response,
    int? selectedSlotIndex,
    String? declineReason,
  });

  Future<void> submitInterviewFeedback({
    required String interviewId,
    required int score,
    required String recommendation,
    required String notes,
  });

  Future<void> cancelInterview(String interviewId, {String? reason});
}

class InterviewRemoteDataSourceImpl implements InterviewRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  InterviewRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _interviewsCol =>
      _firestore.collection('interviews');

  @override
  Future<String> scheduleInterview({
    required String applicationId,
    required String title,
    required String description,
    required InterviewType interviewType,
    String? meetingUrl,
    String? location,
    required List<InterviewSlot> slots,
    List<String> interviewerNames = const [],
  }) async {
    try {
      final callable = _functions.httpsCallable('scheduleInterview');
      final result = await callable.call<Map<String, dynamic>>({
        'applicationId': applicationId,
        'title': title,
        'description': description,
        'interviewType': interviewType.toShortString(),
        'meetingUrl': meetingUrl,
        'location': location,
        'slots': slots.map((s) => s.toMap()).toList(),
        'interviewerNames': interviewerNames,
      });

      return result.data['interviewId'] as String;
    } catch (e) {
      // Fallback direct Firestore write if running offline/demo
      final docRef = _interviewsCol.doc();
      final finalMeetingUrl = interviewType == InterviewType.videoCall
          ? (meetingUrl?.isNotEmpty == true
              ? meetingUrl!
              : 'https://meet.jit.si/test2hire-${docRef.id}')
          : meetingUrl;

      final appDoc = await _firestore.collection('applications').doc(applicationId).get();
      final appData = appDoc.data() ?? {};

      final model = InterviewModel(
        id: docRef.id,
        applicationId: applicationId,
        jobId: appData['jobId'] ?? '',
        jobTitle: appData['jobTitle'] ?? '',
        companyId: appData['companyId'] ?? '',
        companyName: appData['companyName'] ?? '',
        companyLogoUrl: appData['companyLogoUrl'],
        candidateId: appData['candidateId'] ?? '',
        candidateName: appData['candidateName'] ?? '',
        candidateEmail: appData['candidateEmail'] ?? '',
        title: title,
        description: description,
        type: interviewType,
        status: slots.length == 1
            ? InterviewStatus.confirmed
            : InterviewStatus.pendingCandidate,
        meetingUrl: finalMeetingUrl,
        location: location,
        slots: slots,
        selectedSlotIndex: slots.length == 1 ? 0 : null,
        interviewerNames: interviewerNames,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await docRef.set(model.toFirestore());
      await _firestore.collection('applications').doc(applicationId).update({
        'status': 'INTERVIEW_SCHEDULED',
        'interviewId': docRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    }
  }

  @override
  Future<List<InterviewModel>> getCompanyInterviews(String companyId) async {
    try {
      final query = await _interviewsCol
          .where('companyId', isEqualTo: companyId)
          .orderBy('createdAt', descending: true)
          .get();
      return query.docs.map((doc) => InterviewModel.fromFirestore(doc)).toList();
    } catch (_) {
      final query = await _interviewsCol
          .where('companyId', isEqualTo: companyId)
          .get();
      final list = query.docs.map((doc) => InterviewModel.fromFirestore(doc)).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    }
  }

  @override
  Stream<List<InterviewModel>> listenCompanyInterviews(String companyId) {
    return _interviewsCol
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => InterviewModel.fromFirestore(doc)).toList();
          list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
          return list;
        });
  }

  @override
  Future<List<InterviewModel>> getCandidateInterviews(String candidateId) async {
    try {
      final query = await _interviewsCol
          .where('candidateId', isEqualTo: candidateId)
          .orderBy('createdAt', descending: true)
          .get();
      return query.docs.map((doc) => InterviewModel.fromFirestore(doc)).toList();
    } catch (_) {
      final query = await _interviewsCol
          .where('candidateId', isEqualTo: candidateId)
          .get();
      final list = query.docs.map((doc) => InterviewModel.fromFirestore(doc)).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    }
  }

  @override
  Stream<List<InterviewModel>> listenCandidateInterviews(String candidateId) {
    return _interviewsCol
        .where('candidateId', isEqualTo: candidateId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => InterviewModel.fromFirestore(doc)).toList();
          list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
          return list;
        });
  }

  @override
  Future<void> respondToInterview({
    required String interviewId,
    required String response,
    int? selectedSlotIndex,
    String? declineReason,
  }) async {
    try {
      final callable = _functions.httpsCallable('respondToInterview');
      await callable.call({
        'interviewId': interviewId,
        'response': response,
        'selectedSlotIndex': selectedSlotIndex,
        'declineReason': declineReason,
      });
      return;
    } catch (_) {
      // Offline / emulator fallback: update Firestore directly
    }

    final newStatus = response == 'ACCEPT' ? 'CONFIRMED' : 'DECLINED';
    final Map<String, dynamic> updates = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (response == 'ACCEPT') {
      updates['selectedSlotIndex'] = selectedSlotIndex ?? 0;
    } else {
      updates['declineReason'] = declineReason ?? 'Candidate declined.';
    }

    // 1. Update interview doc
    await _interviewsCol.doc(interviewId).update(updates);

    // 2. Sync linked application interviewStatus and notify Company
    try {
      final docSnap = await _interviewsCol.doc(interviewId).get();
      if (docSnap.exists) {
        final data = docSnap.data() ?? {};
        final appId = data['applicationId'] as String?;
        final companyId = data['companyId'] as String?;
        final candidateName = data['candidateName'] as String? ?? 'المرشح';
        final jobTitle = data['jobTitle'] as String? ?? 'الوظيفة';

        if (appId != null && appId.isNotEmpty) {
          try {
            final appUpdates = <String, dynamic>{
              'interviewStatus': newStatus,
              'updatedAt': FieldValue.serverTimestamp(),
            };
            if (response == 'ACCEPT') {
              appUpdates['status'] = 'INTERVIEW_SCHEDULED';
            }
            await _firestore.collection('applications').doc(appId).update(appUpdates);
          } catch (_) {}
        }

        if (companyId != null && companyId.isNotEmpty) {
          try {
            await _firestore.collection('notifications').add({
              'userId': companyId,
              'title': response == 'ACCEPT' ? 'تم تأكيد موعد المقابلة! 📅' : 'اعتذار عن حضور المقابلة',
              'body': response == 'ACCEPT'
                  ? 'أكد المرشح ($candidateName) حضور المقابلة الخاصة بوظيفة ($jobTitle).'
                  : 'اعتذر المرشح ($candidateName) عن حضور المقابلة الخاصة بوظيفة ($jobTitle).',
              'type': response == 'ACCEPT' ? 'INTERVIEW_CONFIRMED' : 'INTERVIEW_DECLINED',
              'entityId': interviewId,
              'data': {
                'interviewId': interviewId,
                'applicationId': ?appId,
              },
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> submitInterviewFeedback({
    required String interviewId,
    required int score,
    required String recommendation,
    required String notes,
  }) async {
    try {
      final callable = _functions.httpsCallable('submitInterviewFeedback');
      await callable.call({
        'interviewId': interviewId,
        'score': score,
        'recommendation': recommendation,
        'notes': notes,
      });
    } catch (_) {
      final feedback = InterviewFeedback(
        interviewerId: 'company_evaluator',
        score: score,
        recommendation: recommendation,
        notes: notes,
        submittedAt: DateTime.now(),
      );

      await _interviewsCol.doc(interviewId).update({
        'status': 'COMPLETED',
        'feedback': feedback.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> cancelInterview(String interviewId, {String? reason}) async {
    await _interviewsCol.doc(interviewId).update({
      'status': 'CANCELLED',
      'declineReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
