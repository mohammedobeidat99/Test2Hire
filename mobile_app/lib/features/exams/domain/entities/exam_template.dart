class ExamTemplate {
  final String id;
  final String companyId;
  final String title;
  final String description;
  final int durationMinutes;
  final int passingPercentage;
  final List<String> questionIds;
  final List<String> bankIds;
  final bool randomizeQuestions;
  final bool randomizeOptions;
  final bool proctoringEnabled;
  final int totalQuestions;
  final int totalPoints;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ExamTemplate({
    required this.id,
    required this.companyId,
    required this.title,
    required this.description,
    this.durationMinutes = 45,
    this.passingPercentage = 70,
    this.questionIds = const [],
    this.bankIds = const [],
    this.randomizeQuestions = true,
    this.randomizeOptions = true,
    this.proctoringEnabled = true,
    this.totalQuestions = 0,
    this.totalPoints = 0,
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  });

  ExamTemplate copyWith({
    String? id,
    String? companyId,
    String? title,
    String? description,
    int? durationMinutes,
    int? passingPercentage,
    List<String>? questionIds,
    List<String>? bankIds,
    bool? randomizeQuestions,
    bool? randomizeOptions,
    bool? proctoringEnabled,
    int? totalQuestions,
    int? totalPoints,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExamTemplate(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      description: description ?? this.description,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      passingPercentage: passingPercentage ?? this.passingPercentage,
      questionIds: questionIds ?? this.questionIds,
      bankIds: bankIds ?? this.bankIds,
      randomizeQuestions: randomizeQuestions ?? this.randomizeQuestions,
      randomizeOptions: randomizeOptions ?? this.randomizeOptions,
      proctoringEnabled: proctoringEnabled ?? this.proctoringEnabled,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      totalPoints: totalPoints ?? this.totalPoints,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum ExamAttemptStatus {
  invited,
  inProgress,
  submitted,
  completed,
  graded,
  expired,
  terminated,
}

extension ExamAttemptStatusExtension on ExamAttemptStatus {
  String toShortString() {
    switch (this) {
      case ExamAttemptStatus.invited:
        return 'INVITED';
      case ExamAttemptStatus.inProgress:
        return 'IN_PROGRESS';
      case ExamAttemptStatus.submitted:
        return 'SUBMITTED';
      case ExamAttemptStatus.completed:
        return 'COMPLETED';
      case ExamAttemptStatus.graded:
        return 'GRADED';
      case ExamAttemptStatus.expired:
        return 'EXPIRED';
      case ExamAttemptStatus.terminated:
        return 'TERMINATED';
    }
  }

  String get displayName {
    switch (this) {
      case ExamAttemptStatus.invited:
        return 'Invitation Pending';
      case ExamAttemptStatus.inProgress:
        return 'In Progress';
      case ExamAttemptStatus.submitted:
        return 'Submitted';
      case ExamAttemptStatus.completed:
        return 'Completed';
      case ExamAttemptStatus.graded:
        return 'Graded';
      case ExamAttemptStatus.expired:
        return 'Expired';
      case ExamAttemptStatus.terminated:
        return 'Terminated';
    }
  }

  static ExamAttemptStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'INVITED':
      case 'ASSIGNED':
        return ExamAttemptStatus.invited;
      case 'IN_PROGRESS':
        return ExamAttemptStatus.inProgress;
      case 'SUBMITTED':
        return ExamAttemptStatus.submitted;
      case 'COMPLETED':
        return ExamAttemptStatus.completed;
      case 'GRADED':
        return ExamAttemptStatus.graded;
      case 'EXPIRED':
        return ExamAttemptStatus.expired;
      case 'TERMINATED':
      case 'TERMINATED_VIOLATION':
        return ExamAttemptStatus.terminated;
      default:
        return ExamAttemptStatus.invited;
    }
  }
}

class ExamAttempt {
  final String id;
  final String examId;
  final String examTitle;
  final String companyId;
  final String candidateId;
  final String candidateName;
  final String candidateEmail;
  final String jobId;
  final String jobTitle;
  final String applicationId;
  final String token;
  final ExamAttemptStatus status;
  final int durationMinutes;
  final int passingPercentage;
  final int totalQuestions;
  final int totalPoints;
  final double score;
  final bool passed;
  final DateTime? invitationSentAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ExamAttempt({
    required this.id,
    required this.examId,
    required this.examTitle,
    required this.companyId,
    required this.candidateId,
    required this.candidateName,
    required this.candidateEmail,
    required this.jobId,
    required this.jobTitle,
    required this.applicationId,
    required this.token,
    this.status = ExamAttemptStatus.invited,
    this.durationMinutes = 45,
    this.passingPercentage = 70,
    this.totalQuestions = 0,
    this.totalPoints = 0,
    this.score = 0,
    this.passed = false,
    this.invitationSentAt,
    this.startedAt,
    this.completedAt,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  static const String webExamPortalUrl = 'https://test2here-72346.web.app';

  bool get isPending => status == ExamAttemptStatus.invited;
  bool get isInProgress => status == ExamAttemptStatus.inProgress;
  bool get isCompleted =>
      status == ExamAttemptStatus.submitted ||
      status == ExamAttemptStatus.completed ||
      status == ExamAttemptStatus.graded;
  bool get isTerminated => status == ExamAttemptStatus.terminated;

  String get assessmentUrl => '$webExamPortalUrl/exam/$token';
}

class AssignExamResult {
  final String attemptId;
  final String token;
  final int durationMinutes;
  final DateTime? expiresAt;

  const AssignExamResult({
    required this.attemptId,
    required this.token,
    required this.durationMinutes,
    this.expiresAt,
  });

  String get assessmentUrl => '${ExamAttempt.webExamPortalUrl}/exam/$token';
}
