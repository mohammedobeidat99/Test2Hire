import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/interview.dart';
import '../../domain/repositories/interview_repository.dart';
import '../datasources/interview_remote_data_source.dart';

class InterviewRepositoryImpl implements InterviewRepository {
  final InterviewRemoteDataSource _remoteDataSource;

  InterviewRepositoryImpl({required InterviewRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<String> scheduleInterview({
    required String applicationId,
    required String title,
    required String description,
    required InterviewType interviewType,
    String? meetingUrl,
    String? location,
    required List<InterviewSlot> slots,
    List<String> interviewerNames = const [],
  }) async {
    try {
      return await _remoteDataSource.scheduleInterview(
        applicationId: applicationId,
        title: title,
        description: description,
        interviewType: interviewType,
        meetingUrl: meetingUrl,
        location: location,
        slots: slots,
        interviewerNames: interviewerNames,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to schedule interview.');
    } catch (e) {
      throw ServerFailure(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Future<List<Interview>> getCompanyInterviews(String companyId) async {
    try {
      return await _remoteDataSource.getCompanyInterviews(companyId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to retrieve company interviews.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<Interview>> listenCompanyInterviews(String companyId) {
    return _remoteDataSource.listenCompanyInterviews(companyId);
  }

  @override
  Future<List<Interview>> getCandidateInterviews(String candidateId) async {
    try {
      return await _remoteDataSource.getCandidateInterviews(candidateId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to retrieve candidate interviews.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<Interview>> listenCandidateInterviews(String candidateId) {
    return _remoteDataSource.listenCandidateInterviews(candidateId);
  }

  @override
  Future<void> respondToInterview({
    required String interviewId,
    required String response,
    int? selectedSlotIndex,
    String? declineReason,
  }) async {
    try {
      await _remoteDataSource.respondToInterview(
        interviewId: interviewId,
        response: response,
        selectedSlotIndex: selectedSlotIndex,
        declineReason: declineReason,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to respond to interview invitation.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> submitInterviewFeedback({
    required String interviewId,
    required int score,
    required String recommendation,
    required String notes,
  }) async {
    try {
      await _remoteDataSource.submitInterviewFeedback(
        interviewId: interviewId,
        score: score,
        recommendation: recommendation,
        notes: notes,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to submit interview feedback.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> cancelInterview(String interviewId, {String? reason}) async {
    try {
      await _remoteDataSource.cancelInterview(interviewId, reason: reason);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to cancel interview.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
