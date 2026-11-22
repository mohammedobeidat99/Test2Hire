import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/job_offer.dart';
import '../../domain/repositories/offer_repository.dart';
import '../datasources/offer_remote_data_source.dart';

class OfferRepositoryImpl implements OfferRepository {
  final OfferRemoteDataSource _remoteDataSource;

  OfferRepositoryImpl({required OfferRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<String> extendJobOffer({
    required String applicationId,
    required double offeredSalary,
    String salaryCurrency = 'USD',
    SalaryPeriod salaryPeriod = SalaryPeriod.annual,
    String? startDate,
    int expiresInDays = 7,
    List<String> benefits = const [],
    String termsAndNotes = '',
  }) async {
    try {
      return await _remoteDataSource.extendJobOffer(
        applicationId: applicationId,
        offeredSalary: offeredSalary,
        salaryCurrency: salaryCurrency,
        salaryPeriod: salaryPeriod,
        startDate: startDate,
        expiresInDays: expiresInDays,
        benefits: benefits,
        termsAndNotes: termsAndNotes,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to extend job offer.');
    } catch (e) {
      throw ServerFailure(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Future<List<JobOffer>> getCompanyOffers(String companyId) async {
    try {
      return await _remoteDataSource.getCompanyOffers(companyId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to fetch company offers.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<JobOffer>> listenCompanyOffers(String companyId) {
    return _remoteDataSource.listenCompanyOffers(companyId);
  }

  @override
  Future<List<JobOffer>> getCandidateOffers(String candidateId) async {
    try {
      return await _remoteDataSource.getCandidateOffers(candidateId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to fetch candidate offers.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<JobOffer>> listenCandidateOffers(String candidateId) {
    return _remoteDataSource.listenCandidateOffers(candidateId);
  }

  @override
  Future<void> respondToOffer({
    required String offerId,
    required String response,
    String? declineReason,
  }) async {
    try {
      await _remoteDataSource.respondToOffer(
        offerId: offerId,
        response: response,
        declineReason: declineReason,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to submit offer response.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> withdrawOffer({
    required String offerId,
    String? reason,
  }) async {
    try {
      await _remoteDataSource.withdrawOffer(
        offerId: offerId,
        reason: reason,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to withdraw job offer.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
