import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/candidate_comparison_result.dart';

class CandidateComparisonModel extends CandidateComparisonResult {
  const CandidateComparisonModel({
    required super.id,
    required super.jobId,
    required super.companyId,
    required super.candidates,
    required super.winnerCandidateId,
    required super.winnerCandidateName,
    required super.comparativeRationale,
    super.keyDifferentiators = const [],
    super.createdAt,
  });

  factory CandidateComparisonModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CandidateComparisonModel.fromMap(data, doc.id);
  }

  factory CandidateComparisonModel.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawCandidates = (data['candidates'] as List<dynamic>?) ?? [];
    final candidatesList = rawCandidates
        .whereType<Map>()
        .map((c) => ComparisonCandidateItem.fromMap(Map<String, dynamic>.from(c)))
        .toList();

    return CandidateComparisonModel(
      id: id ?? data['id'] ?? '',
      jobId: data['jobId'] ?? '',
      companyId: data['companyId'] ?? '',
      candidates: candidatesList,
      winnerCandidateId: data['winnerCandidateId'] ?? '',
      winnerCandidateName: data['winnerCandidateName'] ?? '',
      comparativeRationale: data['comparativeRationale'] ?? '',
      keyDifferentiators: (data['keyDifferentiators'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'companyId': companyId,
      'candidates': candidates.map((c) => c.toMap()).toList(),
      'winnerCandidateId': winnerCandidateId,
      'winnerCandidateName': winnerCandidateName,
      'comparativeRationale': comparativeRationale,
      'keyDifferentiators': keyDifferentiators,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
