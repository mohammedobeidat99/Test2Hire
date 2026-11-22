import '../../../../core/errors/failures.dart';
import '../../domain/entities/hiring_campaign.dart';
import '../../domain/repositories/sourcing_repository.dart';
import '../datasources/sourcing_remote_data_source.dart';
import '../models/hiring_campaign_model.dart';

class SourcingRepositoryImpl implements SourcingRepository {
  final SourcingRemoteDataSource _remoteDataSource;

  SourcingRepositoryImpl({SourcingRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? SourcingRemoteDataSourceImpl();

  @override
  Stream<List<HiringCampaign>> listenCompanyCampaigns(String companyId) {
    try {
      return _remoteDataSource.listenCompanyCampaigns(companyId);
    } catch (e) {
      return Stream.error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<List<HiringCampaign>> getCompanyCampaigns(String companyId) async {
    try {
      return await _remoteDataSource.getCompanyCampaigns(companyId);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> createCampaign(HiringCampaign campaign) async {
    try {
      final model = HiringCampaignModel(
        id: campaign.id,
        companyId: campaign.companyId,
        companyName: campaign.companyName,
        title: campaign.title,
        description: campaign.description,
        targetDepartment: campaign.targetDepartment,
        targetHiresCount: campaign.targetHiresCount,
        currentHiredCount: campaign.currentHiredCount,
        status: campaign.status,
        requiredSkills: campaign.requiredSkills,
        deadline: campaign.deadline,
        createdAt: campaign.createdAt ?? DateTime.now(),
      );
      await _remoteDataSource.createCampaign(model);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateCampaignStatus(String campaignId, CampaignStatus status) async {
    try {
      await _remoteDataSource.updateCampaignStatus(campaignId, status);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> incrementHiredCount(String campaignId) async {
    try {
      await _remoteDataSource.incrementHiredCount(campaignId);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<TalentCandidateProfile>> searchTalentPool({
    String? query,
    List<String>? skills,
    int? minExperienceYears,
    bool? onlyAvailable,
  }) async {
    try {
      return await _remoteDataSource.searchTalentPool(
        query: query,
        skills: skills,
        minExperienceYears: minExperienceYears,
        onlyAvailable: onlyAvailable,
      );
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> sendTalentInvite(TalentPoolInvite invite) async {
    try {
      final model = TalentPoolInviteModel(
        id: invite.id,
        companyId: invite.companyId,
        companyName: invite.companyName,
        candidateId: invite.candidateId,
        candidateName: invite.candidateName,
        campaignId: invite.campaignId,
        campaignTitle: invite.campaignTitle,
        inviteMessage: invite.inviteMessage,
        status: invite.status,
        sentAt: invite.sentAt,
      );
      await _remoteDataSource.sendTalentInvite(model);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<TalentPoolInvite>> listenCandidateInvites(String candidateId) {
    try {
      return _remoteDataSource.listenCandidateInvites(candidateId);
    } catch (e) {
      return Stream.error(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<List<TalentPoolInvite>> listenCompanyInvites(String companyId) {
    try {
      return _remoteDataSource.listenCompanyInvites(companyId);
    } catch (e) {
      return Stream.error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<void> updateInviteStatus(String inviteId, TalentInviteStatus status) async {
    try {
      await _remoteDataSource.updateInviteStatus(inviteId, status);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
