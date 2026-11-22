import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/exam_template.dart';

class ExamTemplateModel extends ExamTemplate {
  const ExamTemplateModel({
    required super.id,
    required super.companyId,
    required super.title,
    required super.description,
    super.durationMinutes,
    super.passingPercentage,
    super.questionIds,
    super.bankIds,
    super.randomizeQuestions,
    super.randomizeOptions,
    super.proctoringEnabled,
    super.totalQuestions,
    super.totalPoints,
    super.isArchived,
    super.createdAt,
    super.updatedAt,
  });

  factory ExamTemplateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ExamTemplateModel(
      id: doc.id,
      companyId: data['companyId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 45,
      passingPercentage: (data['passingPercentage'] as num?)?.toInt() ?? 70,
      questionIds: (data['questionIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      bankIds: (data['bankIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      randomizeQuestions: data['randomizeQuestions'] as bool? ?? true,
      randomizeOptions: data['randomizeOptions'] as bool? ?? true,
      proctoringEnabled: data['proctoringEnabled'] as bool? ?? true,
      totalQuestions: (data['totalQuestions'] as num?)?.toInt() ?? 0,
      totalPoints: (data['totalPoints'] as num?)?.toInt() ?? 0,
      isArchived: data['isArchived'] as bool? ?? false,
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'title': title,
      'description': description,
      'durationMinutes': durationMinutes,
      'passingPercentage': passingPercentage,
      'questionIds': questionIds,
      'bankIds': bankIds,
      'randomizeQuestions': randomizeQuestions,
      'randomizeOptions': randomizeOptions,
      'proctoringEnabled': proctoringEnabled,
      'totalQuestions': totalQuestions,
      'totalPoints': totalPoints,
      'isArchived': isArchived,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ExamTemplateModel.fromEntity(ExamTemplate exam) {
    return ExamTemplateModel(
      id: exam.id,
      companyId: exam.companyId,
      title: exam.title,
      description: exam.description,
      durationMinutes: exam.durationMinutes,
      passingPercentage: exam.passingPercentage,
      questionIds: exam.questionIds,
      bankIds: exam.bankIds,
      randomizeQuestions: exam.randomizeQuestions,
      randomizeOptions: exam.randomizeOptions,
      proctoringEnabled: exam.proctoringEnabled,
      totalQuestions: exam.totalQuestions,
      totalPoints: exam.totalPoints,
      isArchived: exam.isArchived,
      createdAt: exam.createdAt,
      updatedAt: exam.updatedAt,
    );
  }
}

class ExamAttemptModel extends ExamAttempt {
  const ExamAttemptModel({
    required super.id,
    required super.examId,
    required super.examTitle,
    required super.companyId,
    required super.candidateId,
    required super.candidateName,
    required super.candidateEmail,
    required super.jobId,
    required super.jobTitle,
    required super.applicationId,
    required super.token,
    super.status,
    super.durationMinutes,
    super.passingPercentage,
    super.totalQuestions,
    super.totalPoints,
    super.score,
    super.passed,
    super.invitationSentAt,
    super.startedAt,
    super.completedAt,
    super.expiresAt,
    super.createdAt,
    super.updatedAt,
  });

  factory ExamAttemptModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ExamAttemptModel(
      id: doc.id,
      examId: data['examId'] as String? ?? '',
      examTitle: data['examTitle'] as String? ?? '',
      companyId: data['companyId'] as String? ?? '',
      candidateId: data['candidateId'] as String? ?? '',
      candidateName: data['candidateName'] as String? ?? '',
      candidateEmail: data['candidateEmail'] as String? ?? '',
      jobId: data['jobId'] as String? ?? '',
      jobTitle: data['jobTitle'] as String? ?? '',
      applicationId: data['applicationId'] as String? ?? '',
      token: data['token'] as String? ?? '',
      status: ExamAttemptStatusExtension.fromString(data['status'] as String? ?? 'INVITED'),
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 45,
      passingPercentage: (data['passingPercentage'] as num?)?.toInt() ?? 70,
      totalQuestions: (data['totalQuestions'] as num?)?.toInt() ?? 0,
      totalPoints: (data['totalPoints'] as num?)?.toInt() ?? 0,
      score: (data['score'] as num?)?.toDouble() ?? 0.0,
      passed: data['passed'] as bool? ?? false,
      invitationSentAt: parseTimestamp(data['invitationSentAt']),
      startedAt: parseTimestamp(data['startedAt']),
      completedAt: parseTimestamp(data['completedAt']),
      expiresAt: parseTimestamp(data['expiresAt']),
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }
}
