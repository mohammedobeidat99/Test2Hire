import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/job_posting.dart';
import '../../domain/repositories/job_repository.dart';
import '../datasources/job_remote_data_source.dart';
import '../models/job_posting_model.dart';

class JobRepositoryImpl implements JobRepository {
  final JobRemoteDataSource _remoteDataSource;

  JobRepositoryImpl({required JobRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<JobPosting>> getPublishedJobs({
    String? searchQuery,
    JobType? jobType,
    WorkplaceType? workplaceType,
    ExperienceLevel? experienceLevel,
    List<String>? skills,
  }) async {
    try {
      return await _remoteDataSource.getPublishedJobs(
        searchQuery: searchQuery,
        jobType: jobType,
        workplaceType: workplaceType,
        experienceLevel: experienceLevel,
        skills: skills,
      );
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to fetch job vacancies.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<JobPosting>> listenPublishedJobs({
    String? searchQuery,
    JobType? jobType,
    WorkplaceType? workplaceType,
    ExperienceLevel? experienceLevel,
    List<String>? skills,
  }) {
    return _remoteDataSource.listenPublishedJobs(
      searchQuery: searchQuery,
      jobType: jobType,
      workplaceType: workplaceType,
      experienceLevel: experienceLevel,
      skills: skills,
    );
  }

  @override
  Future<List<JobPosting>> getCompanyJobs(String companyId, {JobStatus? status}) async {
    try {
      return await _remoteDataSource.getCompanyJobs(companyId, status: status);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to fetch company jobs.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<JobPosting>> listenCompanyJobs(String companyId) {
    return _remoteDataSource.listenCompanyJobs(companyId);
  }

  @override
  Future<JobPosting> getJobById(String jobId) async {
    try {
      return await _remoteDataSource.getJobById(jobId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to retrieve job.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<String> createJob(JobPosting job) async {
    try {
      final model = JobPostingModel.fromDomain(job);
      return await _remoteDataSource.createJob(model);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to create job posting.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateJob(JobPosting job) async {
    try {
      final model = JobPostingModel.fromDomain(job);
      await _remoteDataSource.updateJob(model);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to update job posting.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    try {
      await _remoteDataSource.updateJobStatus(jobId, status);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to update job status.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteJob(String jobId) async {
    try {
      await _remoteDataSource.deleteJob(jobId);
    } on FirebaseException catch (e) {
      throw ServerFailure(e.message ?? 'Failed to delete job posting.');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
