import '../entities/job_posting.dart';

abstract class JobRepository {
  /// Fetch all published jobs matching search keywords and filters
  Future<List<JobPosting>> getPublishedJobs({
    String? searchQuery,
    JobType? jobType,
    WorkplaceType? workplaceType,
    ExperienceLevel? experienceLevel,
    List<String>? skills,
  });

  /// Listen to real-time updates of published jobs
  Stream<List<JobPosting>> listenPublishedJobs({
    String? searchQuery,
    JobType? jobType,
    WorkplaceType? workplaceType,
    ExperienceLevel? experienceLevel,
    List<String>? skills,
  });

  /// Fetch all jobs belonging to a specific company (for employer management)
  Future<List<JobPosting>> getCompanyJobs(String companyId, {JobStatus? status});

  /// Listen to real-time updates of a company's jobs
  Stream<List<JobPosting>> listenCompanyJobs(String companyId);

  /// Fetch single job by ID
  Future<JobPosting> getJobById(String jobId);

  /// Create a new job vacancy (Draft or Published)
  Future<String> createJob(JobPosting job);

  /// Update existing job vacancy details
  Future<void> updateJob(JobPosting job);

  /// Quick status transition (e.g. DRAFT -> PUBLISHED or PUBLISHED -> CLOSED)
  Future<void> updateJobStatus(String jobId, JobStatus status);

  /// Delete or archive a job
  Future<void> deleteJob(String jobId);
}
