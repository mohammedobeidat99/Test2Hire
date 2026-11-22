import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/job_offer.dart';
import '../models/job_offer_model.dart';

abstract class OfferRemoteDataSource {
  Future<String> extendJobOffer({
    required String applicationId,
    required double offeredSalary,
    String salaryCurrency = 'USD',
    SalaryPeriod salaryPeriod = SalaryPeriod.annual,
    String? startDate,
    int expiresInDays = 7,
    List<String> benefits = const [],
    String termsAndNotes = '',
  });

  Future<List<JobOfferModel>> getCompanyOffers(String companyId);
  Stream<List<JobOfferModel>> listenCompanyOffers(String companyId);

  Future<List<JobOfferModel>> getCandidateOffers(String candidateId);
  Stream<List<JobOfferModel>> listenCandidateOffers(String candidateId);

  Future<void> respondToOffer({
    required String offerId,
    required String response, // "ACCEPT" | "DECLINE"
    String? declineReason,
  });

  Future<void> withdrawOffer({
    required String offerId,
    String? reason,
  });
}

class OfferRemoteDataSourceImpl implements OfferRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  OfferRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference get _offersCol => _firestore.collection('offers');

  @override
  Future<String> extendJobOffer({
    required String applicationId,
    required double offeredSalary,
    String salaryCurrency = 'USD',
    SalaryPeriod salaryPeriod = SalaryPeriod.annual,
    String? startDate,
    int expiresInDays = 7,
    List<String> benefits = const [],
    String termsAndNotes = '',
  }) async {
    try {
      final callable = _functions.httpsCallable('extendJobOffer');
      final result = await callable.call({
        'applicationId': applicationId,
        'offeredSalary': offeredSalary,
        'salaryCurrency': salaryCurrency,
        'salaryPeriod': salaryPeriod.toServerString(),
        'startDate': startDate,
        'expiresInDays': expiresInDays,
        'benefits': benefits,
        'termsAndNotes': termsAndNotes,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return data['offerId'] as String;
    } catch (_) {
      // Direct Firestore fallback
      final appDoc = await _firestore.collection('applications').doc(applicationId).get();
      final appData = appDoc.data() ?? {};

      final offerRef = _offersCol.doc();
      final expiresAt = DateTime.now().add(Duration(days: expiresInDays));

      final model = JobOfferModel(
        id: offerRef.id,
        applicationId: applicationId,
        jobId: appData['jobId'] ?? '',
        jobTitle: appData['jobTitle'] ?? '',
        companyId: appData['companyId'] ?? '',
        companyName: appData['companyName'] ?? '',
        companyLogoUrl: appData['companyLogoUrl'],
        candidateId: appData['candidateId'] ?? '',
        candidateName: appData['candidateName'] ?? '',
        candidateEmail: appData['candidateEmail'] ?? '',
        offeredSalary: offeredSalary,
        salaryCurrency: salaryCurrency,
        salaryPeriod: salaryPeriod,
        startDate: startDate,
        expiresAt: expiresAt,
        benefits: benefits,
        termsAndNotes: termsAndNotes,
        status: OfferStatus.pendingCandidate,
      );

      await offerRef.set(model.toMap());

      await _firestore.collection('applications').doc(applicationId).update({
        'status': 'SELECTED',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return offerRef.id;
    }
  }

  @override
  Future<List<JobOfferModel>> getCompanyOffers(String companyId) async {
    final query = await _offersCol
        .where('companyId', isEqualTo: companyId)
        .get();

    final list = query.docs.map((d) => JobOfferModel.fromFirestore(d)).toList();
    list.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return list;
  }

  @override
  Stream<List<JobOfferModel>> listenCompanyOffers(String companyId) {
    return _offersCol
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => JobOfferModel.fromFirestore(d)).toList();
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  @override
  Future<List<JobOfferModel>> getCandidateOffers(String candidateId) async {
    final query = await _offersCol
        .where('candidateId', isEqualTo: candidateId)
        .get();

    final list = query.docs.map((d) => JobOfferModel.fromFirestore(d)).toList();
    list.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return list;
  }

  @override
  Stream<List<JobOfferModel>> listenCandidateOffers(String candidateId) {
    return _offersCol
        .where('candidateId', isEqualTo: candidateId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => JobOfferModel.fromFirestore(d)).toList();
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  @override
  Future<void> respondToOffer({
    required String offerId,
    required String response,
    String? declineReason,
  }) async {
    try {
      final callable = _functions.httpsCallable('respondToJobOffer');
      await callable.call({
        'offerId': offerId,
        'response': response,
        'declineReason': declineReason,
      });
      return;
    } catch (_) {
      // Offline / emulator fallback: update Firestore directly
    }

    final newStatus = response == 'ACCEPT' ? 'ACCEPTED' : 'DECLINED';
    final Map<String, dynamic> updates = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (response == 'ACCEPT') {
      updates['acceptedAt'] = FieldValue.serverTimestamp();
    } else if (declineReason != null) {
      updates['declineReason'] = declineReason;
      updates['declinedAt'] = FieldValue.serverTimestamp();
    }

    await _offersCol.doc(offerId).update(updates);

    try {
      final docSnap = await _offersCol.doc(offerId).get();
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>? ?? {};
        final appId = data['applicationId'] as String?;
        final companyId = data['companyId'] as String?;
        final candidateName = data['candidateName'] as String? ?? 'المرشح';
        final jobTitle = data['jobTitle'] as String? ?? 'الوظيفة';

        if (appId != null && appId.isNotEmpty) {
          try {
            final appUpdates = <String, dynamic>{
              'offerStatus': newStatus,
              'updatedAt': FieldValue.serverTimestamp(),
            };
            if (response == 'ACCEPT') {
              appUpdates['status'] = 'SELECTED';
              appUpdates['offerAcceptedAt'] = FieldValue.serverTimestamp();
            }
            await _firestore.collection('applications').doc(appId).update(appUpdates);
          } catch (_) {}
        }

        if (companyId != null && companyId.isNotEmpty) {
          try {
            await _firestore.collection('notifications').add({
              'userId': companyId,
              'title': response == 'ACCEPT' ? 'تم قبول عرض العمل! 🎉' : 'اعتذار عن عرض العمل',
              'body': response == 'ACCEPT'
                  ? 'قام المرشح ($candidateName) بقبول العرض الوظيفي لمنصب ($jobTitle) رسمياً!'
                  : 'اعتذر المرشح ($candidateName) عن قبول العرض الوظيفي لمنصب ($jobTitle).',
              'type': response == 'ACCEPT' ? 'JOB_OFFER_ACCEPTED' : 'JOB_OFFER_DECLINED',
              'entityId': offerId,
              'data': {
                'offerId': offerId,
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
  Future<void> withdrawOffer({
    required String offerId,
    String? reason,
  }) async {
    try {
      final callable = _functions.httpsCallable('withdrawJobOffer');
      await callable.call({
        'offerId': offerId,
        'reason': reason,
      });
    } catch (_) {
      await _offersCol.doc(offerId).update({
        'status': 'WITHDRAWN',
        'declineReason': reason ?? 'Offer withdrawn by employer.',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
