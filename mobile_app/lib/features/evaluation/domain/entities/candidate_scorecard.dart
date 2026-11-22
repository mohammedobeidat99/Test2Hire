import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

enum ScorecardRecommendation {
  stronglyRecommended,
  recommended,
  neutral,
  notRecommended,
}

extension ScorecardRecommendationExtension on ScorecardRecommendation {
  String toServerString() {
    switch (this) {
      case ScorecardRecommendation.stronglyRecommended:
        return 'STRONGLY_RECOMMENDED';
      case ScorecardRecommendation.recommended:
        return 'RECOMMENDED';
      case ScorecardRecommendation.neutral:
        return 'NEUTRAL';
      case ScorecardRecommendation.notRecommended:
        return 'NOT_RECOMMENDED';
    }
  }

  String get displayName {
    switch (this) {
      case ScorecardRecommendation.stronglyRecommended:
        return 'موصى به بشدة';
      case ScorecardRecommendation.recommended:
        return 'موصى به';
      case ScorecardRecommendation.neutral:
        return 'قيد المراجعة / محايد';
      case ScorecardRecommendation.notRecommended:
        return 'غير مناسب للمنصب';
    }
  }

  Color get color {
    switch (this) {
      case ScorecardRecommendation.stronglyRecommended:
        return const Color(0xFF047857); // Dark Green
      case ScorecardRecommendation.recommended:
        return AppColors.success;
      case ScorecardRecommendation.neutral:
        return AppColors.warning;
      case ScorecardRecommendation.notRecommended:
        return AppColors.error;
    }
  }

  IconData get icon {
    switch (this) {
      case ScorecardRecommendation.stronglyRecommended:
        return Icons.star_rounded;
      case ScorecardRecommendation.recommended:
        return Icons.check_circle_outline_rounded;
      case ScorecardRecommendation.neutral:
        return Icons.pause_circle_outline_rounded;
      case ScorecardRecommendation.notRecommended:
        return Icons.cancel_outlined;
    }
  }

  static ScorecardRecommendation fromServerString(String? val) {
    switch (val?.toUpperCase()) {
      case 'STRONGLY_RECOMMENDED':
        return ScorecardRecommendation.stronglyRecommended;
      case 'RECOMMENDED':
        return ScorecardRecommendation.recommended;
      case 'NOT_RECOMMENDED':
        return ScorecardRecommendation.notRecommended;
      case 'NEUTRAL':
      default:
        return ScorecardRecommendation.neutral;
    }
  }
}

class ScorecardWeights {
  final double cvMatchWeight;
  final double examScoreWeight;
  final double interviewWeight;

  const ScorecardWeights({
    this.cvMatchWeight = 0.20,
    this.examScoreWeight = 0.40,
    this.interviewWeight = 0.40,
  });

  factory ScorecardWeights.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ScorecardWeights();
    return ScorecardWeights(
      cvMatchWeight: (map['cvMatchWeight'] as num?)?.toDouble() ?? 0.20,
      examScoreWeight: (map['examScoreWeight'] as num?)?.toDouble() ?? 0.40,
      interviewWeight: (map['interviewWeight'] as num?)?.toDouble() ?? 0.40,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cvMatchWeight': cvMatchWeight,
      'examScoreWeight': examScoreWeight,
      'interviewWeight': interviewWeight,
    };
  }
}

class ScoreBreakdown {
  final int cvMatchScore;
  final int examScore;
  final int interviewScore;

  const ScoreBreakdown({
    this.cvMatchScore = 0,
    this.examScore = 0,
    this.interviewScore = 0,
  });

  factory ScoreBreakdown.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ScoreBreakdown();
    return ScoreBreakdown(
      cvMatchScore: (map['cvMatchScore'] as num?)?.toInt() ?? 0,
      examScore: (map['examScore'] as num?)?.toInt() ?? 0,
      interviewScore: (map['interviewScore'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cvMatchScore': cvMatchScore,
      'examScore': examScore,
      'interviewScore': interviewScore,
    };
  }
}

class CandidateScorecard {
  final String id;
  final String applicationId;
  final String jobId;
  final String companyId;
  final String candidateId;
  final String candidateName;
  final String candidateEmail;
  final int compositeScore;
  final int? ranking;
  final ScorecardRecommendation recommendation;
  final ScorecardWeights weights;
  final ScoreBreakdown breakdown;
  final DateTime? calculatedAt;
  final DateTime? updatedAt;

  const CandidateScorecard({
    required this.id,
    required this.applicationId,
    required this.jobId,
    required this.companyId,
    required this.candidateId,
    required this.candidateName,
    required this.candidateEmail,
    required this.compositeScore,
    this.ranking,
    this.recommendation = ScorecardRecommendation.neutral,
    this.weights = const ScorecardWeights(),
    this.breakdown = const ScoreBreakdown(),
    this.calculatedAt,
    this.updatedAt,
  });

  CandidateScorecard copyWith({
    String? id,
    String? applicationId,
    String? jobId,
    String? companyId,
    String? candidateId,
    String? candidateName,
    String? candidateEmail,
    int? compositeScore,
    int? ranking,
    ScorecardRecommendation? recommendation,
    ScorecardWeights? weights,
    ScoreBreakdown? breakdown,
    DateTime? calculatedAt,
    DateTime? updatedAt,
  }) {
    return CandidateScorecard(
      id: id ?? this.id,
      applicationId: applicationId ?? this.applicationId,
      jobId: jobId ?? this.jobId,
      companyId: companyId ?? this.companyId,
      candidateId: candidateId ?? this.candidateId,
      candidateName: candidateName ?? this.candidateName,
      candidateEmail: candidateEmail ?? this.candidateEmail,
      compositeScore: compositeScore ?? this.compositeScore,
      ranking: ranking ?? this.ranking,
      recommendation: recommendation ?? this.recommendation,
      weights: weights ?? this.weights,
      breakdown: breakdown ?? this.breakdown,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CandidateScorecard &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          compositeScore == other.compositeScore &&
          ranking == other.ranking &&
          recommendation == other.recommendation;

  @override
  int get hashCode =>
      id.hashCode ^ compositeScore.hashCode ^ ranking.hashCode ^ recommendation.hashCode;
}
