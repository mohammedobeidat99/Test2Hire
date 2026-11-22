enum ChallengeDifficulty {
  beginner,
  intermediate,
  advanced,
  expert,
}

extension ChallengeDifficultyExtension on ChallengeDifficulty {
  String toShortString() {
    switch (this) {
      case ChallengeDifficulty.beginner:
        return 'BEGINNER';
      case ChallengeDifficulty.intermediate:
        return 'INTERMEDIATE';
      case ChallengeDifficulty.advanced:
        return 'ADVANCED';
      case ChallengeDifficulty.expert:
        return 'EXPERT';
    }
  }

  String get displayName {
    switch (this) {
      case ChallengeDifficulty.beginner:
        return 'مبتدئ';
      case ChallengeDifficulty.intermediate:
        return 'متوسط';
      case ChallengeDifficulty.advanced:
        return 'متقدم';
      case ChallengeDifficulty.expert:
        return 'خبير';
    }
  }

  static ChallengeDifficulty fromString(String val) {
    switch (val.toUpperCase()) {
      case 'BEGINNER':
        return ChallengeDifficulty.beginner;
      case 'ADVANCED':
        return ChallengeDifficulty.advanced;
      case 'EXPERT':
        return ChallengeDifficulty.expert;
      case 'INTERMEDIATE':
      default:
        return ChallengeDifficulty.intermediate;
    }
  }
}

enum ChallengeSubmissionStatus {
  pending,
  submitted,
  underReview,
  approved,
  rejected,
}

extension ChallengeSubmissionStatusExtension on ChallengeSubmissionStatus {
  String toShortString() {
    switch (this) {
      case ChallengeSubmissionStatus.pending:
        return 'PENDING';
      case ChallengeSubmissionStatus.submitted:
        return 'SUBMITTED';
      case ChallengeSubmissionStatus.underReview:
        return 'UNDER_REVIEW';
      case ChallengeSubmissionStatus.approved:
        return 'APPROVED';
      case ChallengeSubmissionStatus.rejected:
        return 'REJECTED';
    }
  }

  String get displayName {
    switch (this) {
      case ChallengeSubmissionStatus.pending:
        return 'قيد العمل';
      case ChallengeSubmissionStatus.submitted:
        return 'تم التسليم';
      case ChallengeSubmissionStatus.underReview:
        return 'قيد المراجعة والتقييم';
      case ChallengeSubmissionStatus.approved:
        return 'مقبول بنجاح';
      case ChallengeSubmissionStatus.rejected:
        return 'غير متوافق';
    }
  }

  static ChallengeSubmissionStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'SUBMITTED':
        return ChallengeSubmissionStatus.submitted;
      case 'UNDER_REVIEW':
        return ChallengeSubmissionStatus.underReview;
      case 'APPROVED':
        return ChallengeSubmissionStatus.approved;
      case 'REJECTED':
        return ChallengeSubmissionStatus.rejected;
      case 'PENDING':
      default:
        return ChallengeSubmissionStatus.pending;
    }
  }
}

class ChallengeRubric {
  final String title;
  final String description;
  final int maxPoints;

  const ChallengeRubric({
    required this.title,
    required this.description,
    this.maxPoints = 25,
  });

  factory ChallengeRubric.fromMap(Map<String, dynamic> map) {
    return ChallengeRubric(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      maxPoints: (map['maxPoints'] as num?)?.toInt() ?? 25,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'maxPoints': maxPoints,
    };
  }
}

class TakeHomeChallenge {
  final String id;
  final String companyId;
  final String companyName;
  final String? jobId;
  final String? jobTitle;
  final String? candidateId;
  final String? applicationId;
  final String title;
  final String brief;
  final String detailedInstructions;
  final ChallengeDifficulty difficulty;
  final int deadlineDays;
  final List<String> techStack;
  final List<String> deliverables;
  final List<ChallengeRubric> rubrics;
  final String? starterTemplateUrl; // GitHub repo or boilerplate zip
  final DateTime? createdAt;

  const TakeHomeChallenge({
    required this.id,
    required this.companyId,
    required this.companyName,
    this.jobId,
    this.jobTitle,
    this.candidateId,
    this.applicationId,
    required this.title,
    required this.brief,
    required this.detailedInstructions,
    this.difficulty = ChallengeDifficulty.intermediate,
    this.deadlineDays = 3,
    this.techStack = const [],
    this.deliverables = const [],
    this.rubrics = const [],
    this.starterTemplateUrl,
    this.createdAt,
  });
}

class ChallengeSubmission {
  final String id;
  final String challengeId;
  final String companyId;
  final String candidateId;
  final String candidateName;
  final String candidateEmail;
  final String githubRepoUrl;
  final String? liveDemoUrl;
  final String? candidateNotes;
  final ChallengeSubmissionStatus status;
  final double? score;
  final String? reviewerFeedback;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  const ChallengeSubmission({
    required this.id,
    required this.challengeId,
    required this.companyId,
    required this.candidateId,
    required this.candidateName,
    required this.candidateEmail,
    required this.githubRepoUrl,
    this.liveDemoUrl,
    this.candidateNotes,
    this.status = ChallengeSubmissionStatus.submitted,
    this.score,
    this.reviewerFeedback,
    required this.submittedAt,
    this.reviewedAt,
  });
}
