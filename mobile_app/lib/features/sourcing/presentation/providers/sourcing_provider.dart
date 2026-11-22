import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/hiring_campaign.dart';
import '../../domain/repositories/sourcing_repository.dart';

class SourcingProvider extends ChangeNotifier {
  final SourcingRepository _repository;

  List<HiringCampaign> _campaigns = [];
  List<TalentCandidateProfile> _talentPool = [];
  List<TalentPoolInvite> _invites = [];

  bool _isLoading = false;
  bool _isSearching = false;
  bool _isActionInProgress = false;
  String? _errorMessage;
  String? _successMessage;

  StreamSubscription<List<HiringCampaign>>? _campaignsSubscription;
  StreamSubscription<List<TalentPoolInvite>>? _invitesSubscription;

  SourcingProvider({required SourcingRepository repository})
      : _repository = repository;

  List<HiringCampaign> get campaigns => _campaigns;
  List<TalentCandidateProfile> get talentPool => _talentPool;
  List<TalentPoolInvite> get invites => _invites;

  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  bool get isActionInProgress => _isActionInProgress;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void listenCompanyCampaigns(String companyId) {
    _campaignsSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _campaignsSubscription = _repository.listenCompanyCampaigns(companyId).listen(
      (list) {
        _campaigns = list;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = err.toString();
        notifyListeners();
      },
    );
  }

  Future<void> searchTalentPool({
    String? query,
    List<String>? skills,
    int? minExperienceYears,
    bool? onlyAvailable,
  }) async {
    _isSearching = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _talentPool = await _repository.searchTalentPool(
        query: query,
        skills: skills,
        minExperienceYears: minExperienceYears,
        onlyAvailable: onlyAvailable,
      );
      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _isSearching = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> createCampaign(HiringCampaign campaign) async {
    _isActionInProgress = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _repository.createCampaign(campaign);
      _isActionInProgress = false;
      _successMessage = 'تم إنشاء حملة التوظيف بنجاح';
      notifyListeners();
      return true;
    } catch (e) {
      _isActionInProgress = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendTalentInvite(TalentPoolInvite invite) async {
    _isActionInProgress = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _repository.sendTalentInvite(invite);
      _isActionInProgress = false;
      _successMessage = 'تم إرسال دعوة التوظيف المباشرة بنجاح';
      notifyListeners();
      return true;
    } catch (e) {
      _isActionInProgress = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void listenCandidateInvites(String candidateId) {
    _invitesSubscription?.cancel();
    _invitesSubscription = _repository.listenCandidateInvites(candidateId).listen(
      (list) {
        _invites = list;
        notifyListeners();
      },
      onError: (err) {
        _errorMessage = err.toString();
        notifyListeners();
      },
    );
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _campaignsSubscription?.cancel();
    _invitesSubscription?.cancel();
    super.dispose();
  }
}
