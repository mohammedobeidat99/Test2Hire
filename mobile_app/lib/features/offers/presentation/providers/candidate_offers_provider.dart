import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/job_offer.dart';
import '../../domain/repositories/offer_repository.dart';

class CandidateOffersProvider extends ChangeNotifier {
  final OfferRepository _repository;
  StreamSubscription<List<JobOffer>>? _subscription;

  List<JobOffer> _offers = [];
  bool _isLoading = false;
  bool _isResponding = false;
  String? _errorMessage;
  String? _successMessage;

  CandidateOffersProvider({required OfferRepository repository})
      : _repository = repository;

  List<JobOffer> get offers => _offers;
  bool get isLoading => _isLoading;
  bool get isResponding => _isResponding;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  List<JobOffer> get pendingOffers =>
      _offers.where((o) => o.status == OfferStatus.pendingCandidate && !o.isExpired).toList();

  List<JobOffer> get acceptedOffers =>
      _offers.where((o) => o.status == OfferStatus.accepted).toList();

  List<JobOffer> get pastOffers => _offers
      .where((o) =>
          o.status == OfferStatus.accepted ||
          o.status == OfferStatus.declined ||
          o.status == OfferStatus.withdrawn ||
          o.isExpired)
      .toList();

  int get pendingCount => pendingOffers.length;
  int get acceptedCount => acceptedOffers.length;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  String? _listeningCandidateId;

  void reset() {
    _subscription?.cancel();
    _subscription = null;
    _listeningCandidateId = null;
    _offers = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void listenCandidateOffers(String candidateId, {bool force = false}) {
    if (!force && _listeningCandidateId == candidateId && _subscription != null) {
      return;
    }
    if (_listeningCandidateId != null && _listeningCandidateId != candidateId) {
      _offers = [];
    }
    _listeningCandidateId = candidateId;
    _subscription?.cancel();
    _errorMessage = null;
    if (_offers.isEmpty) {
      _isLoading = true;
    }
    notifyListeners();

    _subscription = _repository.listenCandidateOffers(candidateId).listen(
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

  Future<void> loadCandidateOffers(String candidateId) async {
    if (_listeningCandidateId != null && _listeningCandidateId != candidateId) {
      _subscription?.cancel();
      _subscription = null;
      _offers = [];
    }
    _listeningCandidateId = candidateId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.getCandidateOffers(candidateId);
      if (_listeningCandidateId != candidateId) return;
      _offers = fetched;
    } on Failure catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> respondToOffer({
    required String offerId,
    required String response, // "ACCEPT" | "DECLINE"
    String? declineReason,
  }) async {
    _isResponding = true;
    _errorMessage = null;

    // 1. Optimistic Local Update: Instantly reflect on UI in 0ms
    final index = _offers.indexWhere((o) => o.id == offerId);
    JobOffer? originalOffer;
    if (index != -1) {
      originalOffer = _offers[index];
      final newStatus = response == 'ACCEPT'
          ? OfferStatus.accepted
          : OfferStatus.declined;

      _offers[index] = _offers[index].copyWith(
        status: newStatus,
        declineReason: declineReason,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }

    try {
      await _repository.respondToOffer(
        offerId: offerId,
        response: response,
        declineReason: declineReason,
      );

      _successMessage = response == 'ACCEPT'
          ? 'Congratulations! You have accepted the job offer.'
          : 'Job offer declined.';
      return true;
    } on Failure catch (e) {
      // Rollback on failure
      if (index != -1 && originalOffer != null) {
        _offers[index] = originalOffer;
      }
      _errorMessage = e.message;
      return false;
    } catch (e) {
      if (index != -1 && originalOffer != null) {
        _offers[index] = originalOffer;
      }
      _errorMessage = e.toString();
      return false;
    } finally {
      _isResponding = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
