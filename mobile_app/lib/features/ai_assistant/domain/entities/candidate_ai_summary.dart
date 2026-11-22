import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

enum HiringRisk {
  low,
  moderate,
  high,
}

extension HiringRiskExtension on HiringRisk {
  String toServerString() {
    switch (this) {
      case HiringRisk.low:
        return 'LOW';
      case HiringRisk.moderate:
        return 'MODERATE';
      case HiringRisk.high:
        return 'HIGH';
    }
  }

  String get displayName {
    switch (this) {
      case HiringRisk.low:
        return 'مخاطر توظيف منخفضة';
      case HiringRisk.moderate:
        return 'مخاطر توظيف متوسطة';
      case HiringRisk.high:
        return 'مخاطر توظيف مرتفعة';
    }
  }

  Color get color {
    switch (this) {
      case HiringRisk.low:
        return AppColors.success;
      case HiringRisk.moderate:
        return AppColors.warning;
      case HiringRisk.high:
        return AppColors.error;
    }
  }

  static HiringRisk fromServerString(String? val) {
    switch (val?.toUpperCase()) {
      case 'HIGH':
        return HiringRisk.high;
      case 'MODERATE':
        return HiringRisk.moderate;
      case 'LOW':
      default:
        return HiringRisk.low;
    }
  }
}

enum RecommendationDecision {
  strongHire,
  hire,
  leanHire,
  doNotHire,
}

extension RecommendationDecisionExtension on RecommendationDecision {
  String toServerString() {
    switch (this) {
      case RecommendationDecision.strongHire:
        return 'STRONG_HIRE';
      case RecommendationDecision.hire:
        return 'HIRE';
      case RecommendationDecision.leanHire:
        return 'LEAN_HIRE';
      case RecommendationDecision.doNotHire:
        return 'DO_NOT_HIRE';
    }
  }

  String get displayName {
    switch (this) {
      case RecommendationDecision.strongHire:
        return 'توظيف مؤكد (Strong Hire)';
      case RecommendationDecision.hire:
        return 'يوصى بالتوظيف (Hire)';
      case RecommendationDecision.leanHire:
        return 'مرشح احتياطي (Lean Hire)';
      case RecommendationDecision.doNotHire:
        return 'لا يوصى به (Do Not Hire)';
    }
  }

  Color get color {
    switch (this) {
      case RecommendationDecision.strongHire:
        return const Color(0xFF047857);
      case RecommendationDecision.hire:
        return AppColors.primary;
      case RecommendationDecision.leanHire:
        return AppColors.warning;
      case RecommendationDecision.doNotHire:
        return AppColors.error;
    }
  }

  IconData get icon {
    switch (this) {
      case RecommendationDecision.strongHire:
        return Icons.verified_user_rounded;
      case RecommendationDecision.hire:
        return Icons.thumb_up_alt_rounded;
      case RecommendationDecision.leanHire:
        return Icons.help_outline_rounded;
      case RecommendationDecision.doNotHire:
        return Icons.thumb_down_alt_rounded;
    }
  }

  static RecommendationDecision fromServerString(String? val) {
    switch (val?.toUpperCase()) {
      case 'STRONG_HIRE':
        return RecommendationDecision.strongHire;
      case 'HIRE':
        return RecommendationDecision.hire;
      case 'LEAN_HIRE':
        return RecommendationDecision.leanHire;
      case 'DO_NOT_HIRE':
      default:
        return RecommendationDecision.doNotHire;
    }
  }
}

class CandidateAiSummary {
  final String id;
  final String applicationId;
  final String jobId;
  final String companyId;
  final String candidateId;
  final String candidateName;
  final String summaryText;
  final List<String> keyStrengths;
  final List<String> potentialRedFlags;
  final HiringRisk hiringRisk;
  final List<String> suggestedQuestions;
  final RecommendationDecision recommendationDecision;
  final int confidenceScore;
  final DateTime? generatedAt;

  const CandidateAiSummary({
    required this.id,
    required this.applicationId,
    required this.jobId,
    required this.companyId,
    required this.candidateId,
    required this.candidateName,
    required this.summaryText,
    this.keyStrengths = const [],
    this.potentialRedFlags = const [],
    this.hiringRisk = HiringRisk.low,
    this.suggestedQuestions = const [],
    this.recommendationDecision = RecommendationDecision.hire,
    this.confidenceScore = 85,
    this.generatedAt,
  });
}
