class ComparisonCandidateItem {
  final String applicationId;
  final String candidateName;
  final String candidateEmail;
  final int cvMatchScore;
  final int examScore;
  final int compositeScore;
  final int ranking;

  const ComparisonCandidateItem({
    required this.applicationId,
    required this.candidateName,
    required this.candidateEmail,
    required this.cvMatchScore,
    required this.examScore,
    required this.compositeScore,
    required this.ranking,
  });

  factory ComparisonCandidateItem.fromMap(Map<String, dynamic> map) {
    return ComparisonCandidateItem(
      applicationId: map['applicationId'] as String? ?? '',
      candidateName: map['candidateName'] as String? ?? '',
      candidateEmail: map['candidateEmail'] as String? ?? '',
      cvMatchScore: (map['cvMatchScore'] as num?)?.toInt() ?? 0,
      examScore: (map['examScore'] as num?)?.toInt() ?? 0,
      compositeScore: (map['compositeScore'] as num?)?.toInt() ?? 0,
      ranking: (map['ranking'] as num?)?.toInt() ?? 999,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'applicationId': applicationId,
      'candidateName': candidateName,
      'candidateEmail': candidateEmail,
      'cvMatchScore': cvMatchScore,
      'examScore': examScore,
      'compositeScore': compositeScore,
      'ranking': ranking,
    };
  }
}

class CandidateComparisonResult {
  final String id;
  final String jobId;
  final String companyId;
  final List<ComparisonCandidateItem> candidates;
  final String winnerCandidateId;
  final String winnerCandidateName;
  final String comparativeRationale;
  final List<String> keyDifferentiators;
  final DateTime? createdAt;

  const CandidateComparisonResult({
    required this.id,
    required this.jobId,
    required this.companyId,
    required this.candidates,
    required this.winnerCandidateId,
    required this.winnerCandidateName,
    required this.comparativeRationale,
    this.keyDifferentiators = const [],
    this.createdAt,
  });
}
