import '../entities/job_offer.dart';

abstract class OfferRepository {
  Future<String> extendJobOffer({
    required String applicationId,
    required double offeredSalary,
    String salaryCurrency = 'USD',
    SalaryPeriod salaryPeriod = SalaryPeriod.annual,
    String? startDate,
    int expiresInDays = 7,
    List<String> benefits = const [],
    String termsAndNotes = '',
  });

  Future<List<JobOffer>> getCompanyOffers(String companyId);
  Stream<List<JobOffer>> listenCompanyOffers(String companyId);

  Future<List<JobOffer>> getCandidateOffers(String candidateId);
  Stream<List<JobOffer>> listenCandidateOffers(String candidateId);

  Future<void> respondToOffer({
    required String offerId,
    required String response, // "ACCEPT" | "DECLINE"
    String? declineReason,
  });

  Future<void> withdrawOffer({
    required String offerId,
    String? reason,
  });
}
