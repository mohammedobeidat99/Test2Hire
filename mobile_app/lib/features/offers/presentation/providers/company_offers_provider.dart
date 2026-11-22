import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/job_offer.dart';
import '../../domain/repositories/offer_repository.dart';

class CompanyOffersProvider extends ChangeNotifier {
  final OfferRepository _repository;
  StreamSubscription<List<JobOffer>>? _subscription;

  List<JobOffer> _offers = [];
  OfferStatus? _statusFilter;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  CompanyOffersProvider({required OfferRepository repository})
      : _repository = repository;

  List<JobOffer> get offers {
    if (_statusFilter == null) return _offers;
    return _offers.where((o) => o.status == _statusFilter).toList();
  }

  List<JobOffer> get allOffers => _offers;
  OfferStatus? get statusFilter => _statusFilter;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  int get totalCount => _offers.length;
  int get pendingCount =>
      _offers.where((o) => o.status == OfferStatus.pendingCandidate).length;
  int get acceptedCount =>
      _offers.where((o) => o.status == OfferStatus.accepted).length;
  int get declinedCount =>
      _offers.where((o) => o.status == OfferStatus.declined).length;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void setStatusFilter(OfferStatus? filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  void listenCompanyOffers(String companyId) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _repository.listenCompanyOffers(companyId).listen(
      (list) {
        _offers = list;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> loadCompanyOffers(String companyId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _offers = await _repository.getCompanyOffers(companyId);
    } on Failure catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> extendJobOffer({
    required String applicationId,
    required double offeredSalary,
    String salaryCurrency = 'USD',
    SalaryPeriod salaryPeriod = SalaryPeriod.annual,
    String? startDate,
    int expiresInDays = 7,
    List<String> benefits = const [],
    String termsAndNotes = '',
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final offerId = await _repository.extendJobOffer(
        applicationId: applicationId,
        offeredSalary: offeredSalary,
        salaryCurrency: salaryCurrency,
        salaryPeriod: salaryPeriod,
        startDate: startDate,
        expiresInDays: expiresInDays,
        benefits: benefits,
        termsAndNotes: termsAndNotes,
      );

      _successMessage = 'Job offer extended successfully!';
      return offerId;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> withdrawOffer(String offerId, {String? reason}) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.withdrawOffer(offerId: offerId, reason: reason);

      final index = _offers.indexWhere((o) => o.id == offerId);
      if (index != -1) {
        _offers[index] = _offers[index].copyWith(
          status: OfferStatus.withdrawn,
          declineReason: reason ?? 'Withdrawn by employer.',
          updatedAt: DateTime.now(),
        );
      }

      _successMessage = 'Offer withdrawn successfully.';
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
