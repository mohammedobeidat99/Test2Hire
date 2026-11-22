import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/candidate_ai_summary.dart';

class CandidateAiSummaryModel extends CandidateAiSummary {
  const CandidateAiSummaryModel({
    required super.id,
    required super.applicationId,
    required super.jobId,
    required super.companyId,
    required super.candidateId,
    required super.candidateName,
    required super.summaryText,
    super.keyStrengths = const [],
    super.potentialRedFlags = const [],
    super.hiringRisk = HiringRisk.low,
    super.suggestedQuestions = const [],
    super.recommendationDecision = RecommendationDecision.hire,
    super.confidenceScore = 85,
    super.generatedAt,
  });

  factory CandidateAiSummaryModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CandidateAiSummaryModel.fromMap(data, doc.id);
  }

  factory CandidateAiSummaryModel.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return CandidateAiSummaryModel(
      id: id ?? data['id'] ?? data['applicationId'] ?? '',
      applicationId: data['applicationId'] ?? id ?? '',
      jobId: data['jobId'] ?? '',
      companyId: data['companyId'] ?? '',
      candidateId: data['candidateId'] ?? '',
      candidateName: data['candidateName'] ?? '',
      summaryText: data['summaryText'] ?? '',
      keyStrengths: (data['keyStrengths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      potentialRedFlags: (data['potentialRedFlags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      hiringRisk: HiringRiskExtension.fromServerString(data['hiringRisk'] as String?),
      suggestedQuestions: (data['suggestedQuestions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      recommendationDecision: RecommendationDecisionExtension.fromServerString(data['recommendationDecision'] as String?),
      confidenceScore: (data['confidenceScore'] as num?)?.toInt() ?? 85,
      generatedAt: parseDate(data['generatedAt']),
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
      'summaryText': summaryText,
      'keyStrengths': keyStrengths,
      'potentialRedFlags': potentialRedFlags,
      'hiringRisk': hiringRisk.toServerString(),
      'suggestedQuestions': suggestedQuestions,
      'recommendationDecision': recommendationDecision.toServerString(),
      'confidenceScore': confidenceScore,
      'generatedAt': generatedAt != null ? Timestamp.fromDate(generatedAt!) : FieldValue.serverTimestamp(),
    };
  }
}
