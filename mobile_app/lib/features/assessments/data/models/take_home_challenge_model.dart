import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/take_home_challenge.dart';

DateTime? _parseChallengeDate(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is DateTime) return val;
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  if (val is String) return DateTime.tryParse(val);
  return null;
}

class TakeHomeChallengeModel extends TakeHomeChallenge {
  const TakeHomeChallengeModel({
    required super.id,
    required super.companyId,
    required super.companyName,
    super.jobId,
    super.jobTitle,
    super.candidateId,
    super.applicationId,
    required super.title,
    required super.brief,
    required super.detailedInstructions,
    super.difficulty,
    super.deadlineDays,
    super.techStack,
    super.deliverables,
    super.rubrics,
    super.starterTemplateUrl,
    super.createdAt,
  });

  factory TakeHomeChallengeModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return TakeHomeChallengeModel.fromMap(data, doc.id);
  }

  factory TakeHomeChallengeModel.fromMap(Map<String, dynamic> data, [String? id]) {
    final created = _parseChallengeDate(data['createdAt']);

    final rubricsList = (data['rubrics'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((e) => ChallengeRubric.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        const [];

    return TakeHomeChallengeModel(
      id: id ?? data['id'] ?? '',
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      jobId: data['jobId'] as String?,
      jobTitle: data['jobTitle'] as String?,
      candidateId: data['candidateId'] as String?,
      applicationId: data['applicationId'] as String?,
      title: data['title'] ?? '',
      brief: data['brief'] ?? '',
      detailedInstructions: data['detailedInstructions'] ?? '',
      difficulty: ChallengeDifficultyExtension.fromString(data['difficulty'] ?? 'INTERMEDIATE'),
      deadlineDays: (data['deadlineDays'] as num?)?.toInt() ?? 3,
      techStack: (data['techStack'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      deliverables: (data['deliverables'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      rubrics: rubricsList,
      starterTemplateUrl: data['starterTemplateUrl'] as String?,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'jobId': jobId,
      'jobTitle': jobTitle,
      if (candidateId != null) 'candidateId': candidateId,
      if (applicationId != null) 'applicationId': applicationId,
      'title': title,
      'brief': brief,
      'detailedInstructions': detailedInstructions,
      'difficulty': difficulty.toShortString(),
      'deadlineDays': deadlineDays,
      'techStack': techStack,
      'deliverables': deliverables,
      'rubrics': rubrics.map((r) => r.toMap()).toList(),
      'starterTemplateUrl': starterTemplateUrl,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}

class ChallengeSubmissionModel extends ChallengeSubmission {
  const ChallengeSubmissionModel({
    required super.id,
    required super.challengeId,
    required super.companyId,
    required super.candidateId,
    required super.candidateName,
    required super.candidateEmail,
    required super.githubRepoUrl,
    super.liveDemoUrl,
    super.candidateNotes,
    super.status,
    super.score,
    super.reviewerFeedback,
    required super.submittedAt,
    super.reviewedAt,
  });

  factory ChallengeSubmissionModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ChallengeSubmissionModel.fromMap(data, doc.id);
  }

  factory ChallengeSubmissionModel.fromMap(Map<String, dynamic> data, [String? id]) {
    final subAt = _parseChallengeDate(data['submittedAt']) ?? DateTime.now();
    final revAt = _parseChallengeDate(data['reviewedAt']);

    return ChallengeSubmissionModel(
      id: id ?? data['id'] ?? '',
      challengeId: data['challengeId'] ?? '',
      companyId: data['companyId'] ?? '',
      candidateId: data['candidateId'] ?? '',
      candidateName: data['candidateName'] ?? '',
      candidateEmail: data['candidateEmail'] ?? '',
      githubRepoUrl: data['githubRepoUrl'] ?? '',
      liveDemoUrl: data['liveDemoUrl'] as String?,
      candidateNotes: data['candidateNotes'] as String?,
      status: ChallengeSubmissionStatusExtension.fromString(data['status'] ?? 'SUBMITTED'),
      score: (data['score'] as num?)?.toDouble(),
      reviewerFeedback: data['reviewerFeedback'] as String?,
      submittedAt: subAt,
      reviewedAt: revAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'challengeId': challengeId,
      'companyId': companyId,
      'candidateId': candidateId,
      'candidateName': candidateName,
      'candidateEmail': candidateEmail,
      'githubRepoUrl': githubRepoUrl,
      'liveDemoUrl': liveDemoUrl,
      'candidateNotes': candidateNotes,
      'status': status.toShortString(),
      'score': score,
      'reviewerFeedback': reviewerFeedback,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    };
  }
}
