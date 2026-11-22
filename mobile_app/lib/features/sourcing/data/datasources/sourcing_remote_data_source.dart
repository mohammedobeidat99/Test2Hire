import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/hiring_campaign.dart';
import '../models/hiring_campaign_model.dart';

abstract class SourcingRemoteDataSource {
  Stream<List<HiringCampaignModel>> listenCompanyCampaigns(String companyId);
  Future<List<HiringCampaignModel>> getCompanyCampaigns(String companyId);
  Future<void> createCampaign(HiringCampaignModel campaign);
  Future<void> updateCampaignStatus(String campaignId, CampaignStatus status);
  Future<void> incrementHiredCount(String campaignId);

  Future<List<TalentCandidateProfileModel>> searchTalentPool({
    String? query,
    List<String>? skills,
    int? minExperienceYears,
    bool? onlyAvailable,
  });

  Future<void> sendTalentInvite(TalentPoolInviteModel invite);
  Stream<List<TalentPoolInviteModel>> listenCandidateInvites(String candidateId);
  Stream<List<TalentPoolInviteModel>> listenCompanyInvites(String companyId);
  Future<void> updateInviteStatus(String inviteId, TalentInviteStatus status);
}

class SourcingRemoteDataSourceImpl implements SourcingRemoteDataSource {
  final FirebaseFirestore _firestore;

  SourcingRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<HiringCampaignModel>> listenCompanyCampaigns(String companyId) {
    return _firestore
        .collection('hiringCampaigns')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HiringCampaignModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<List<HiringCampaignModel>> getCompanyCampaigns(String companyId) async {
    final snapshot = await _firestore
        .collection('hiringCampaigns')
        .where('companyId', isEqualTo: companyId)
        .get();
    return snapshot.docs
        .map((doc) => HiringCampaignModel.fromFirestore(doc))
        .toList();
  }

  @override
  Future<void> createCampaign(HiringCampaignModel campaign) async {
    final docRef = campaign.id.isEmpty
        ? _firestore.collection('hiringCampaigns').doc()
        : _firestore.collection('hiringCampaigns').doc(campaign.id);

    await docRef.set(campaign.toMap());
  }

  @override
  Future<void> updateCampaignStatus(String campaignId, CampaignStatus status) async {
    await _firestore.collection('hiringCampaigns').doc(campaignId).update({
      'status': status.toShortString(),
    });
  }

  @override
  Future<void> incrementHiredCount(String campaignId) async {
    await _firestore.collection('hiringCampaigns').doc(campaignId).update({
      'currentHiredCount': FieldValue.increment(1),
    });
  }

  @override
  Future<List<TalentCandidateProfileModel>> searchTalentPool({
    String? query,
    List<String>? skills,
    int? minExperienceYears,
    bool? onlyAvailable,
  }) async {
    Query q = _firestore
        .collection('users')
        .where('role', isEqualTo: 'USER')
        .limit(150);

    final snapshot = await q.get();
    var candidates = snapshot.docs
        .map((doc) => TalentCandidateProfileModel.fromFirestore(doc))
        .toList();

    if (query != null && query.trim().isNotEmpty) {
      final lq = query.trim().toLowerCase();
      candidates = candidates.where((c) {
        return c.fullName.toLowerCase().contains(lq) ||
            (c.headline?.toLowerCase().contains(lq) ?? false) ||
            c.skills.any((s) => s.toLowerCase().contains(lq));
      }).toList();
    }

    if (skills != null && skills.isNotEmpty) {
      final lowerSkills = skills.map((s) => s.toLowerCase()).toSet();
      candidates = candidates.where((c) {
        final cSkills = c.skills.map((s) => s.toLowerCase()).toSet();
        return cSkills.intersection(lowerSkills).isNotEmpty;
      }).toList();
    }

    if (minExperienceYears != null && minExperienceYears > 0) {
      candidates = candidates
          .where((c) => c.experienceYears >= minExperienceYears)
          .toList();
    }

    if (onlyAvailable == true) {
      candidates = candidates.where((c) => c.isAvailableForHire).toList();
    }

    return candidates;
  }

  @override
  Future<void> sendTalentInvite(TalentPoolInviteModel invite) async {
    final docRef = invite.id.isEmpty
        ? _firestore.collection('talentPoolInvites').doc()
        : _firestore.collection('talentPoolInvites').doc(invite.id);

    await docRef.set(invite.toMap());
  }

  @override
  Stream<List<TalentPoolInviteModel>> listenCandidateInvites(String candidateId) {
    return _firestore
        .collection('talentPoolInvites')
        .where('candidateId', isEqualTo: candidateId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TalentPoolInviteModel.fromFirestore(doc))
            .toList());
  }

  @override
  Stream<List<TalentPoolInviteModel>> listenCompanyInvites(String companyId) {
    return _firestore
        .collection('talentPoolInvites')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TalentPoolInviteModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<void> updateInviteStatus(String inviteId, TalentInviteStatus status) async {
    await _firestore.collection('talentPoolInvites').doc(inviteId).update({
      'status': status.toShortString(),
    });
  }
}
