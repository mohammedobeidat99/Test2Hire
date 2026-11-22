import '../entities/hiring_campaign.dart';

abstract class SourcingRepository {
  Stream<List<HiringCampaign>> listenCompanyCampaigns(String companyId);
  Future<List<HiringCampaign>> getCompanyCampaigns(String companyId);

  Future<void> createCampaign(HiringCampaign campaign);
  Future<void> updateCampaignStatus(String campaignId, CampaignStatus status);
  Future<void> incrementHiredCount(String campaignId);

  Future<List<TalentCandidateProfile>> searchTalentPool({
    String? query,
    List<String>? skills,
    int? minExperienceYears,
    bool? onlyAvailable,
  });

  Future<void> sendTalentInvite(TalentPoolInvite invite);
  Stream<List<TalentPoolInvite>> listenCandidateInvites(String candidateId);
  Stream<List<TalentPoolInvite>> listenCompanyInvites(String companyId);
  Future<void> updateInviteStatus(String inviteId, TalentInviteStatus status);
}
