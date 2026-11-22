import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/job_offer.dart';

class JobOfferModel extends JobOffer {
  const JobOfferModel({
    required super.id,
    required super.applicationId,
    required super.jobId,
    required super.jobTitle,
    required super.companyId,
    required super.companyName,
    super.companyLogoUrl,
    required super.candidateId,
    required super.candidateName,
    required super.candidateEmail,
    required super.offeredSalary,
    super.salaryCurrency = 'USD',
    super.salaryPeriod = SalaryPeriod.annual,
    super.startDate,
    super.expiresAt,
    super.benefits = const [],
    super.termsAndNotes = '',
    super.status = OfferStatus.pendingCandidate,
    super.declineReason,
    super.createdAt,
    super.updatedAt,
  });

  factory JobOfferModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return JobOfferModel.fromMap(data, doc.id);
  }

  factory JobOfferModel.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return JobOfferModel(
      id: id ?? data['id'] ?? '',
      applicationId: data['applicationId'] ?? '',
      jobId: data['jobId'] ?? '',
      jobTitle: data['jobTitle'] ?? '',
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      companyLogoUrl: data['companyLogoUrl'] as String?,
      candidateId: data['candidateId'] ?? '',
      candidateName: data['candidateName'] ?? '',
      candidateEmail: data['candidateEmail'] ?? '',
      offeredSalary: (data['offeredSalary'] as num?)?.toDouble() ?? 0.0,
      salaryCurrency: (data['salaryCurrency'] as String?) ?? 'USD',
      salaryPeriod: SalaryPeriodX.fromServerString(data['salaryPeriod'] as String?),
      startDate: data['startDate'] as String?,
      expiresAt: parseDate(data['expiresAt']),
      benefits: (data['benefits'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      termsAndNotes: (data['termsAndNotes'] as String?) ?? '',
      status: OfferStatusX.fromServerString(data['status'] as String?),
      declineReason: data['declineReason'] as String?,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'applicationId': applicationId,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'companyId': companyId,
      'companyName': companyName,
      'companyLogoUrl': companyLogoUrl,
      'candidateId': candidateId,
      'candidateName': candidateName,
      'candidateEmail': candidateEmail,
      'offeredSalary': offeredSalary,
      'salaryCurrency': salaryCurrency,
      'salaryPeriod': salaryPeriod.toServerString(),
      'startDate': startDate,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'benefits': benefits,
      'termsAndNotes': termsAndNotes,
      'status': status.toServerString(),
      'declineReason': declineReason,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
