enum ApplicationStatus {
  applied,
  underReview,
  shortlisted,
  examPending,
  examAssigned,
  examInProgress,
  examCompleted,
  passed,
  failed,
  interviewInvited,
  interviewScheduled,
  offerExtended,
  selected,
  hired,
  rejected,
  withdrawn,
}

extension ApplicationStatusExtension on ApplicationStatus {
  String toShortString() {
    switch (this) {
      case ApplicationStatus.applied:
        return 'APPLIED';
      case ApplicationStatus.underReview:
        return 'UNDER_REVIEW';
      case ApplicationStatus.shortlisted:
        return 'SHORTLISTED';
      case ApplicationStatus.examPending:
        return 'EXAM_PENDING';
      case ApplicationStatus.examAssigned:
        return 'EXAM_ASSIGNED';
      case ApplicationStatus.examInProgress:
        return 'EXAM_IN_PROGRESS';
      case ApplicationStatus.examCompleted:
        return 'EXAM_COMPLETED';
      case ApplicationStatus.passed:
        return 'PASSED';
      case ApplicationStatus.failed:
        return 'FAILED';
      case ApplicationStatus.interviewInvited:
        return 'INTERVIEW_INVITED';
      case ApplicationStatus.interviewScheduled:
        return 'INTERVIEW_SCHEDULED';
      case ApplicationStatus.offerExtended:
        return 'OFFER_EXTENDED';
      case ApplicationStatus.selected:
        return 'SELECTED';
      case ApplicationStatus.hired:
        return 'HIRED';
      case ApplicationStatus.rejected:
        return 'REJECTED';
      case ApplicationStatus.withdrawn:
        return 'WITHDRAWN';
    }
  }

  String get displayName {
    switch (this) {
      case ApplicationStatus.applied:
        return 'Applied';
      case ApplicationStatus.underReview:
        return 'Under Review';
      case ApplicationStatus.shortlisted:
        return 'Shortlisted';
      case ApplicationStatus.examPending:
        return 'Exam Pending';
      case ApplicationStatus.examAssigned:
        return 'Exam Assigned';
      case ApplicationStatus.examInProgress:
        return 'Exam in Progress';
      case ApplicationStatus.examCompleted:
        return 'Exam Completed';
      case ApplicationStatus.passed:
        return 'Passed Exam';
      case ApplicationStatus.failed:
        return 'Failed Exam';
      case ApplicationStatus.interviewInvited:
        return 'Interview Invited';
      case ApplicationStatus.interviewScheduled:
        return 'Interview Scheduled';
      case ApplicationStatus.offerExtended:
        return 'Offer Extended';
      case ApplicationStatus.selected:
        return 'Selected';
      case ApplicationStatus.hired:
        return 'Hired';
      case ApplicationStatus.rejected:
        return 'Rejected';
      case ApplicationStatus.withdrawn:
        return 'Withdrawn';
    }
  }

  static ApplicationStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'APPLIED':
        return ApplicationStatus.applied;
      case 'UNDER_REVIEW':
        return ApplicationStatus.underReview;
      case 'SHORTLISTED':
        return ApplicationStatus.shortlisted;
      case 'EXAM_PENDING':
        return ApplicationStatus.examPending;
      case 'EXAM_ASSIGNED':
        return ApplicationStatus.examAssigned;
      case 'EXAM_IN_PROGRESS':
        return ApplicationStatus.examInProgress;
      case 'EXAM_COMPLETED':
        return ApplicationStatus.examCompleted;
      case 'PASSED':
        return ApplicationStatus.passed;
      case 'FAILED':
        return ApplicationStatus.failed;
      case 'INTERVIEW_INVITED':
        return ApplicationStatus.interviewInvited;
      case 'INTERVIEW_SCHEDULED':
        return ApplicationStatus.interviewScheduled;
      case 'OFFER_EXTENDED':
        return ApplicationStatus.offerExtended;
      case 'SELECTED':
        return ApplicationStatus.selected;
      case 'HIRED':
        return ApplicationStatus.hired;
      case 'REJECTED':
        return ApplicationStatus.rejected;
      case 'WITHDRAWN':
        return ApplicationStatus.withdrawn;
      default:
        return ApplicationStatus.applied;
    }
  }
}

class JobApplication {
  final String id;
  final String jobId;
  final String jobTitle;
  final String companyId;
  final String companyName;
  final String? companyLogoUrl;
  final String candidateId;
  final String candidateName;
  final String candidateEmail;
  final String? candidatePhone;
  final String? candidateHeadline;
  final String? candidatePhotoUrl;
  final String cvUrl;
  final String cvFileName;
  final String? coverLetter;
  final Map<String, dynamic>? questionnaireAnswers;
  final ApplicationStatus status;
  final double? examScore;
  final String? examAttemptId;
  final String? examToken;
  final String? examTitle;
  final int? examDurationMinutes;
  final DateTime? examExpiresAt;
  final String? rejectionReason;
  final AiParsedCv? aiParsedCv;
  final int? cvMatchScore;
  final int? overallFitScore;
  final String? aiRecommendation;
  final DateTime? appliedAt;
  final DateTime? updatedAt;

  const JobApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.companyId,
    required this.companyName,
    this.companyLogoUrl,
    required this.candidateId,
    required this.candidateName,
    required this.candidateEmail,
    this.candidatePhone,
    this.candidateHeadline,
    this.candidatePhotoUrl,
    required this.cvUrl,
    required this.cvFileName,
    this.coverLetter,
    this.questionnaireAnswers,
    this.status = ApplicationStatus.applied,
    this.examScore,
    this.examAttemptId,
    this.examToken,
    this.examTitle,
    this.examDurationMinutes,
    this.examExpiresAt,
    this.rejectionReason,
    this.aiParsedCv,
    this.cvMatchScore,
    this.overallFitScore,
    this.aiRecommendation,
    this.appliedAt,
    this.updatedAt,
  });

  bool get canWithdraw =>
      status == ApplicationStatus.applied ||
      status == ApplicationStatus.underReview ||
      status == ApplicationStatus.shortlisted;

  bool get isTerminal =>
      status == ApplicationStatus.selected ||
      status == ApplicationStatus.hired ||
      status == ApplicationStatus.rejected ||
      status == ApplicationStatus.withdrawn;

  bool get hasPassedExam => status == ApplicationStatus.passed;
  bool get hasExamAssigned =>
      status == ApplicationStatus.examAssigned ||
      status == ApplicationStatus.examPending ||
      (examToken?.isNotEmpty ?? false);
  bool get isTopPerformer => hasPassedExam || (examScore != null && examScore! >= 70.0);

  JobApplication copyWith({
    String? id,
    String? jobId,
    String? jobTitle,
    String? companyId,
    String? companyName,
    String? companyLogoUrl,
    String? candidateId,
    String? candidateName,
    String? candidateEmail,
    String? candidatePhone,
    String? candidateHeadline,
    String? candidatePhotoUrl,
    String? cvUrl,
    String? cvFileName,
    String? coverLetter,
    Map<String, dynamic>? questionnaireAnswers,
    ApplicationStatus? status,
    double? examScore,
    String? examAttemptId,
    String? examToken,
    String? examTitle,
    int? examDurationMinutes,
    DateTime? examExpiresAt,
    String? rejectionReason,
    AiParsedCv? aiParsedCv,
    int? cvMatchScore,
    int? overallFitScore,
    String? aiRecommendation,
    DateTime? appliedAt,
    DateTime? updatedAt,
  }) {
    return JobApplication(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      candidateId: candidateId ?? this.candidateId,
      candidateName: candidateName ?? this.candidateName,
      candidateEmail: candidateEmail ?? this.candidateEmail,
      candidatePhone: candidatePhone ?? this.candidatePhone,
      candidateHeadline: candidateHeadline ?? this.candidateHeadline,
      candidatePhotoUrl: candidatePhotoUrl ?? this.candidatePhotoUrl,
      cvUrl: cvUrl ?? this.cvUrl,
      cvFileName: cvFileName ?? this.cvFileName,
      coverLetter: coverLetter ?? this.coverLetter,
      questionnaireAnswers: questionnaireAnswers ?? this.questionnaireAnswers,
      status: status ?? this.status,
      examScore: examScore ?? this.examScore,
      examAttemptId: examAttemptId ?? this.examAttemptId,
      examToken: examToken ?? this.examToken,
      examTitle: examTitle ?? this.examTitle,
      examDurationMinutes: examDurationMinutes ?? this.examDurationMinutes,
      examExpiresAt: examExpiresAt ?? this.examExpiresAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      aiParsedCv: aiParsedCv ?? this.aiParsedCv,
      cvMatchScore: cvMatchScore ?? this.cvMatchScore,
      overallFitScore: overallFitScore ?? this.overallFitScore,
      aiRecommendation: aiRecommendation ?? this.aiRecommendation,
      appliedAt: appliedAt ?? this.appliedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AiParsedCv {
  final List<String> extractedSkills;
  final int yearsOfExperience;
  final String educationLevel;
  final String summary;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final int cvMatchScore;
  final String aiRecommendation;
  final String aiRationale;

  const AiParsedCv({
    this.extractedSkills = const [],
    this.yearsOfExperience = 0,
    this.educationLevel = '',
    this.summary = '',
    this.matchedSkills = const [],
    this.missingSkills = const [],
    this.cvMatchScore = 0,
    this.aiRecommendation = 'POTENTIAL_MATCH',
    this.aiRationale = '',
  });

  factory AiParsedCv.fromMap(Map<String, dynamic> map) {
    return AiParsedCv(
      extractedSkills: List<String>.from(map['extractedSkills'] ?? []),
      yearsOfExperience: (map['yearsOfExperience'] as num?)?.toInt() ?? 0,
      educationLevel: map['educationLevel'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      matchedSkills: List<String>.from(map['matchedSkills'] ?? []),
      missingSkills: List<String>.from(map['missingSkills'] ?? []),
      cvMatchScore: (map['cvMatchScore'] as num?)?.toInt() ?? 0,
      aiRecommendation: map['aiRecommendation'] as String? ?? 'POTENTIAL_MATCH',
      aiRationale: map['aiRationale'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'extractedSkills': extractedSkills,
      'yearsOfExperience': yearsOfExperience,
      'educationLevel': educationLevel,
      'summary': summary,
      'matchedSkills': matchedSkills,
      'missingSkills': missingSkills,
      'cvMatchScore': cvMatchScore,
      'aiRecommendation': aiRecommendation,
      'aiRationale': aiRationale,
    };
  }
}
