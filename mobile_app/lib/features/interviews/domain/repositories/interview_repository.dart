import '../entities/interview.dart';

abstract class InterviewRepository {
  /// Schedule a new interview for a candidate
  Future<String> scheduleInterview({
    required String applicationId,
    required String title,
    required String description,
    required InterviewType interviewType,
    String? meetingUrl,
    String? location,
    required List<InterviewSlot> slots,
    List<String> interviewerNames = const [],
  });

  /// Get interviews belonging to a company
  Future<List<Interview>> getCompanyInterviews(String companyId);

  /// Real-time stream of company interviews
  Stream<List<Interview>> listenCompanyInterviews(String companyId);

  /// Get interviews scheduled for a candidate
  Future<List<Interview>> getCandidateInterviews(String candidateId);

  /// Real-time stream of candidate interviews
  Stream<List<Interview>> listenCandidateInterviews(String candidateId);

  /// Candidate responds to interview invitation (Accept/Decline/Pick Slot)
  Future<void> respondToInterview({
    required String interviewId,
    required String response, // "ACCEPT" | "DECLINE"
    int? selectedSlotIndex,
    String? declineReason,
  });

  /// Submit post-interview evaluation feedback and rating
  Future<void> submitInterviewFeedback({
    required String interviewId,
    required int score,
    required String recommendation,
    required String notes,
  });

  /// Cancel an existing interview
  Future<void> cancelInterview(String interviewId, {String? reason});
}
