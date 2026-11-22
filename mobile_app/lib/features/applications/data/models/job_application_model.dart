import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/job_application.dart';

class JobApplicationModel extends JobApplication {
  const JobApplicationModel({
    required super.id,
    required super.jobId,
    required super.jobTitle,
    required super.companyId,
    required super.companyName,
    super.companyLogoUrl,
    required super.candidateId,
    required super.candidateName,
    required super.candidateEmail,
    super.candidatePhone,
    super.candidateHeadline,
    super.candidatePhotoUrl,
    required super.cvUrl,
    required super.cvFileName,
    super.coverLetter,
    super.questionnaireAnswers,
    super.status = ApplicationStatus.applied,
    super.examScore,
    super.examAttemptId,
    super.examToken,
    super.examTitle,
    super.examDurationMinutes,
    super.examExpiresAt,
    super.rejectionReason,
    super.aiParsedCv,
    super.cvMatchScore,
    super.overallFitScore,
    super.aiRecommendation,
    super.appliedAt,
    super.updatedAt,
  });

  factory JobApplicationModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return JobApplicationModel.fromMap(doc.data() ?? {}, doc.id);
  }

  factory JobApplicationModel.fromMap(
      Map<String, dynamic> data, String id) {
    return JobApplicationModel(
      id: id,
      jobId: data['jobId'] as String? ?? '',
      jobTitle: data['jobTitle'] as String? ?? '',
      companyId: data['companyId'] as String? ?? '',
      companyName: data['companyName'] as String? ?? '',
      companyLogoUrl: data['companyLogoUrl'] as String?,
      candidateId: data['candidateId'] as String? ?? '',
      candidateName: data['candidateName'] as String? ?? '',
      candidateEmail: data['candidateEmail'] as String? ?? '',
      candidatePhone: data['candidatePhone'] as String?,
      candidateHeadline: data['candidateHeadline'] as String?,
      candidatePhotoUrl: data['candidatePhotoUrl'] as String?,
      cvUrl: data['cvUrl'] as String? ?? '',
      cvFileName: data['cvFileName'] as String? ?? 'CV.pdf',
      coverLetter: data['coverLetter'] as String?,
      questionnaireAnswers: data['questionnaireAnswers'] is Map
          ? Map<String, dynamic>.from(data['questionnaireAnswers'] as Map)
          : null,
      status: ApplicationStatusExtension.fromString(
          data['status'] as String? ?? 'APPLIED'),
      examScore: (data['examScore'] as num?)?.toDouble(),
      examAttemptId: data['examAttemptId'] as String?,
      examToken: data['examToken'] as String?,
      examTitle: data['examTitle'] as String?,
      examDurationMinutes: (data['examDurationMinutes'] as num?)?.toInt(),
      examExpiresAt: _parseDateTime(data['examExpiresAt']),
      rejectionReason: data['rejectionReason'] as String?,
      aiParsedCv: data['aiParsedCv'] is Map
          ? AiParsedCv.fromMap(Map<String, dynamic>.from(data['aiParsedCv'] as Map))
          : null,
      cvMatchScore: (data['cvMatchScore'] as num?)?.toInt(),
      overallFitScore: (data['overallFitScore'] as num?)?.toInt(),
      aiRecommendation: data['aiRecommendation'] as String?,
      appliedAt: _parseDateTime(data['appliedAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return null;
  }

  factory JobApplicationModel.fromDomain(JobApplication app) {
    return JobApplicationModel(
      id: app.id,
      jobId: app.jobId,
      jobTitle: app.jobTitle,
      companyId: app.companyId,
      companyName: app.companyName,
      companyLogoUrl: app.companyLogoUrl,
      candidateId: app.candidateId,
      candidateName: app.candidateName,
      candidateEmail: app.candidateEmail,
      candidatePhone: app.candidatePhone,
      candidateHeadline: app.candidateHeadline,
      candidatePhotoUrl: app.candidatePhotoUrl,
      cvUrl: app.cvUrl,
      cvFileName: app.cvFileName,
      coverLetter: app.coverLetter,
      questionnaireAnswers: app.questionnaireAnswers,
      status: app.status,
      examScore: app.examScore,
      examAttemptId: app.examAttemptId,
      examToken: app.examToken,
      examTitle: app.examTitle,
      examDurationMinutes: app.examDurationMinutes,
      examExpiresAt: app.examExpiresAt,
      rejectionReason: app.rejectionReason,
      aiParsedCv: app.aiParsedCv,
      cvMatchScore: app.cvMatchScore,
      overallFitScore: app.overallFitScore,
      aiRecommendation: app.aiRecommendation,
      appliedAt: app.appliedAt,
      updatedAt: app.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'jobId': jobId,
      'jobTitle': jobTitle,
      'companyId': companyId,
      'companyName': companyName,
      'companyLogoUrl': companyLogoUrl,
      'candidateId': candidateId,
      'candidateName': candidateName,
      'candidateEmail': candidateEmail,
      'candidatePhone': candidatePhone,
      'candidateHeadline': candidateHeadline,
      'candidatePhotoUrl': candidatePhotoUrl,
      'cvUrl': cvUrl,
      'cvFileName': cvFileName,
      'coverLetter': coverLetter,
      'questionnaireAnswers': questionnaireAnswers,
      'status': status.toShortString(),
      'examScore': examScore,
      'examAttemptId': examAttemptId,
      'examToken': examToken,
      'examTitle': examTitle,
      'examDurationMinutes': examDurationMinutes,
      'examExpiresAt': examExpiresAt != null ? Timestamp.fromDate(examExpiresAt!) : null,
      'rejectionReason': rejectionReason,
      'aiParsedCv': aiParsedCv?.toMap(),
      'cvMatchScore': cvMatchScore,
      'overallFitScore': overallFitScore,
      'aiRecommendation': aiRecommendation,
      'appliedAt': appliedAt != null
          ? Timestamp.fromDate(appliedAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
