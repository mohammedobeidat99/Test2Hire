import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/candidate_scorecard.dart';

class CandidateScorecardModel extends CandidateScorecard {
  const CandidateScorecardModel({
    required super.id,
    required super.applicationId,
    required super.jobId,
    required super.companyId,
    required super.candidateId,
    required super.candidateName,
    required super.candidateEmail,
    required super.compositeScore,
    super.ranking,
    super.recommendation,
    super.weights,
    super.breakdown,
    super.calculatedAt,
    super.updatedAt,
  });

  factory CandidateScorecardModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CandidateScorecardModel.fromMap(data, doc.id);
  }

  factory CandidateScorecardModel.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawWeights = data['weights'] is Map
        ? Map<String, dynamic>.from(data['weights'] as Map)
        : null;
    final rawBreakdown = data['breakdown'] is Map
        ? Map<String, dynamic>.from(data['breakdown'] as Map)
        : null;

    return CandidateScorecardModel(
      id: id ?? data['id'] ?? data['applicationId'] ?? '',
      applicationId: data['applicationId'] ?? id ?? '',
      jobId: data['jobId'] ?? '',
      companyId: data['companyId'] ?? '',
      candidateId: data['candidateId'] ?? '',
      candidateName: data['candidateName'] ?? '',
      candidateEmail: data['candidateEmail'] ?? '',
      compositeScore: (data['compositeScore'] as num?)?.toInt() ?? 0,
      ranking: (data['ranking'] as num?)?.toInt(),
      recommendation: ScorecardRecommendationExtension.fromServerString(
        data['recommendation'] as String?,
      ),
      weights: ScorecardWeights.fromMap(rawWeights),
      breakdown: ScoreBreakdown.fromMap(rawBreakdown),
      calculatedAt: parseDate(data['calculatedAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'applicationId': applicationId,
      'jobId': jobId,
      'companyId': companyId,
      'candidateId': candidateId,
      'candidateName': candidateName,
      'candidateEmail': candidateEmail,
      'compositeScore': compositeScore,
      'ranking': ranking,
      'recommendation': recommendation.toServerString(),
      'weights': weights.toMap(),
      'breakdown': breakdown.toMap(),
      'calculatedAt': calculatedAt != null
          ? Timestamp.fromDate(calculatedAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
