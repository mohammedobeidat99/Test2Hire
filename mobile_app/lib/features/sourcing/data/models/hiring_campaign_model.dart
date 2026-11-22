import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/hiring_campaign.dart';

DateTime? _parseSourcingDate(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is DateTime) return val;
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  if (val is String) return DateTime.tryParse(val);
  return null;
}

class HiringCampaignModel extends HiringCampaign {
  const HiringCampaignModel({
    required super.id,
    required super.companyId,
    required super.companyName,
    required super.title,
    required super.description,
    required super.targetDepartment,
    super.targetHiresCount,
    super.currentHiredCount,
    super.status,
    super.requiredSkills,
    super.deadline,
    super.createdAt,
  });

  factory HiringCampaignModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return HiringCampaignModel.fromMap(data, doc.id);
  }

  factory HiringCampaignModel.fromMap(Map<String, dynamic> data, [String? id]) {
    final dl = _parseSourcingDate(data['deadline']);
    final ct = _parseSourcingDate(data['createdAt']);

    return HiringCampaignModel(
      id: id ?? data['id'] ?? '',
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      targetDepartment: data['targetDepartment'] ?? 'General',
      targetHiresCount: (data['targetHiresCount'] as num?)?.toInt() ?? 10,
      currentHiredCount: (data['currentHiredCount'] as num?)?.toInt() ?? 0,
      status: CampaignStatusExtension.fromString(data['status'] ?? 'ACTIVE'),
      requiredSkills: (data['requiredSkills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      deadline: dl,
      createdAt: ct,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'title': title,
      'description': description,
      'targetDepartment': targetDepartment,
      'targetHiresCount': targetHiresCount,
      'currentHiredCount': currentHiredCount,
      'status': status.toShortString(),
      'requiredSkills': requiredSkills,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

class TalentCandidateProfileModel extends TalentCandidateProfile {
  const TalentCandidateProfileModel({
    required super.candidateId,
    required super.fullName,
    required super.email,
    super.headline,
    super.location,
    super.photoUrl,
    super.skills,
    super.experienceYears,
    super.avgAssessmentScore,
    super.isAvailableForHire,
  });

  factory TalentCandidateProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return TalentCandidateProfileModel.fromMap(data, doc.id);
  }

  factory TalentCandidateProfileModel.fromMap(
      Map<String, dynamic> data, [String? id]) {
    final skillsList = (data['skills'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    String? locString;
    final rawLoc = data['location'];
    if (rawLoc is String) {
      locString = rawLoc;
    } else if (rawLoc is Map) {
      final locMap = Map<String, dynamic>.from(rawLoc);
      final city = (locMap['city'] ?? '').toString().trim();
      final country = (locMap['country'] ?? '').toString().trim();
      final combined = [city, country].where((s) => s.isNotEmpty).join(', ');
      if (combined.isNotEmpty) locString = combined;
    }

    return TalentCandidateProfileModel(
      candidateId: id ?? data['uid'] ?? data['id'] ?? '',
      fullName: data['fullName'] ?? data['name'] ?? 'Candidate',
      email: data['email'] ?? '',
      headline: data['headline'] as String?,
      location: locString,
      photoUrl: data['photoUrl'] as String?,
      skills: skillsList,
      experienceYears: (data['experienceYears'] as num?)?.toInt() ?? 0,
      avgAssessmentScore:
          (data['avgAssessmentScore'] as num?)?.toDouble(),
      isAvailableForHire: data['isAvailableForHire'] ?? true,
    );
  }
}

class TalentPoolInviteModel extends TalentPoolInvite {
  const TalentPoolInviteModel({
    required super.id,
    required super.companyId,
    required super.companyName,
    required super.candidateId,
    required super.candidateName,
    super.campaignId,
    super.campaignTitle,
    required super.inviteMessage,
    super.status,
    required super.sentAt,
  });

  factory TalentPoolInviteModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return TalentPoolInviteModel.fromMap(data, doc.id);
  }

  factory TalentPoolInviteModel.fromMap(
      Map<String, dynamic> data, [String? id]) {
    final sent = _parseSourcingDate(data['sentAt']) ?? DateTime.now();

    return TalentPoolInviteModel(
      id: id ?? data['id'] ?? '',
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      candidateId: data['candidateId'] ?? '',
      candidateName: data['candidateName'] ?? '',
      campaignId: data['campaignId'] as String?,
      campaignTitle: data['campaignTitle'] as String?,
      inviteMessage: data['inviteMessage'] ?? '',
      status: TalentInviteStatusExtension.fromString(
          data['status'] ?? 'PENDING'),
      sentAt: sent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'candidateId': candidateId,
      'candidateName': candidateName,
      'campaignId': campaignId,
      'campaignTitle': campaignTitle,
      'inviteMessage': inviteMessage,
      'status': status.toShortString(),
      'sentAt': Timestamp.fromDate(sentAt),
    };
  }
}
