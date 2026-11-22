enum CampaignStatus {
  active,
  paused,
  completed,
}

extension CampaignStatusExtension on CampaignStatus {
  String toShortString() {
    switch (this) {
      case CampaignStatus.active:
        return 'ACTIVE';
      case CampaignStatus.paused:
        return 'PAUSED';
      case CampaignStatus.completed:
        return 'COMPLETED';
    }
  }

  String get displayName {
    switch (this) {
      case CampaignStatus.active:
        return 'نشطة ومستمرة';
      case CampaignStatus.paused:
        return 'متوقفة مؤقتاً';
      case CampaignStatus.completed:
        return 'مكتملة الأهداف';
    }
  }

  static CampaignStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'PAUSED':
        return CampaignStatus.paused;
      case 'COMPLETED':
        return CampaignStatus.completed;
      case 'ACTIVE':
      default:
        return CampaignStatus.active;
    }
  }
}

class HiringCampaign {
  final String id;
  final String companyId;
  final String companyName;
  final String title;
  final String description;
  final String targetDepartment;
  final int targetHiresCount;
  final int currentHiredCount;
  final CampaignStatus status;
  final List<String> requiredSkills;
  final DateTime? deadline;
  final DateTime? createdAt;

  const HiringCampaign({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.title,
    required this.description,
    required this.targetDepartment,
    this.targetHiresCount = 10,
    this.currentHiredCount = 0,
    this.status = CampaignStatus.active,
    this.requiredSkills = const [],
    this.deadline,
    this.createdAt,
  });

  double get progressPercentage {
    if (targetHiresCount <= 0) return 0.0;
    final pct = (currentHiredCount / targetHiresCount);
    return pct > 1.0 ? 1.0 : pct;
  }
}

class TalentCandidateProfile {
  final String candidateId;
  final String fullName;
  final String email;
  final String? headline;
  final String? location;
  final String? photoUrl;
  final List<String> skills;
  final int experienceYears;
  final double? avgAssessmentScore;
  final bool isAvailableForHire;

  const TalentCandidateProfile({
    required this.candidateId,
    required this.fullName,
    required this.email,
    this.headline,
    this.location,
    this.photoUrl,
    this.skills = const [],
    this.experienceYears = 0,
    this.avgAssessmentScore,
    this.isAvailableForHire = true,
  });
}

enum TalentInviteStatus {
  pending,
  accepted,
  declined,
}

extension TalentInviteStatusExtension on TalentInviteStatus {
  String toShortString() {
    switch (this) {
      case TalentInviteStatus.pending:
        return 'PENDING';
      case TalentInviteStatus.accepted:
        return 'ACCEPTED';
      case TalentInviteStatus.declined:
        return 'DECLINED';
    }
  }

  String get displayName {
    switch (this) {
      case TalentInviteStatus.pending:
        return 'قيد الانتظار';
      case TalentInviteStatus.accepted:
        return 'تم القبول';
      case TalentInviteStatus.declined:
        return 'تم الاعتذار';
    }
  }

  static TalentInviteStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'ACCEPTED':
        return TalentInviteStatus.accepted;
      case 'DECLINED':
        return TalentInviteStatus.declined;
      case 'PENDING':
      default:
        return TalentInviteStatus.pending;
    }
  }
}

class TalentPoolInvite {
  final String id;
  final String companyId;
  final String companyName;
  final String candidateId;
  final String candidateName;
  final String? campaignId;
  final String? campaignTitle;
  final String inviteMessage;
  final TalentInviteStatus status;
  final DateTime sentAt;

  const TalentPoolInvite({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.candidateId,
    required this.candidateName,
    this.campaignId,
    this.campaignTitle,
    required this.inviteMessage,
    this.status = TalentInviteStatus.pending,
    required this.sentAt,
  });
}
