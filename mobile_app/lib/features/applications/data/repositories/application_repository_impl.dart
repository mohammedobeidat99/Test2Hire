import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/job_application.dart';
import '../../domain/repositories/application_repository.dart';
import '../datasources/application_remote_data_source.dart';
import '../models/job_application_model.dart';

class ApplicationRepositoryImpl implements ApplicationRepository {
  final ApplicationRemoteDataSource _remoteDataSource;

  ApplicationRepositoryImpl(
      {required ApplicationRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<String> submitApplication(JobApplication application) async {
    try {
      final model = JobApplicationModel.fromDomain(application);
      return await _remoteDataSource.submitApplication(model);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to submit application.');
    } catch (e) {
      throw ServerFailure(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Future<List<JobApplication>> getCandidateApplications(
      String candidateId) async {
    try {
      return await _remoteDataSource.getCandidateApplications(candidateId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to retrieve applications.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<JobApplication>> listenCandidateApplications(
      String candidateId) {
    return _remoteDataSource.listenCandidateApplications(candidateId);
  }

  @override
  Future<List<JobApplication>> getJobApplicants(String jobId) async {
    try {
      return await _remoteDataSource.getJobApplicants(jobId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to retrieve applicants.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<JobApplication>> listenJobApplicants(String jobId) {
    return _remoteDataSource.listenJobApplicants(jobId);
  }

  @override
  Future<void> updateApplicationStatus(
    String applicationId,
    ApplicationStatus status, {
    String? reason,
  }) async {
    try {
      await _remoteDataSource.updateApplicationStatus(
        applicationId,
        status,
        reason: reason,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to update application status.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> withdrawApplication(String applicationId) async {
    try {
      await _remoteDataSource.withdrawApplication(applicationId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to withdraw application.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<bool> hasCandidateApplied(String jobId, String candidateId) async {
    try {
      return await _remoteDataSource.hasCandidateApplied(jobId, candidateId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to check application status.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<AiParsedCv> parseResumeWithAI(String applicationId) async {
    try {
      return await _remoteDataSource.parseResumeWithAI(applicationId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to analyze resume with AI.');
    } catch (e) {
      throw ServerFailure(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
