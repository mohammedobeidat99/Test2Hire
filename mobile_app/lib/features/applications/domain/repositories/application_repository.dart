import '../entities/job_application.dart';

abstract class ApplicationRepository {
  /// Submit a new job application
  Future<String> submitApplication(JobApplication application);

  /// Get all applications submitted by a specific candidate
  Future<List<JobApplication>> getCandidateApplications(String candidateId);

  /// Listen to real-time updates of a candidate's applications
  Stream<List<JobApplication>> listenCandidateApplications(String candidateId);

  /// Get all applications submitted for a specific job (company review)
  Future<List<JobApplication>> getJobApplicants(String jobId);

  /// Listen to real-time applicant updates for a job
  Stream<List<JobApplication>> listenJobApplicants(String jobId);

  /// Update application status (e.g. Under Review, Exam Assigned, Interview, Selected, Rejected)
  Future<void> updateApplicationStatus(
    String applicationId,
    ApplicationStatus status, {
    String? reason,
  });

  /// Withdraw an application by candidate
  Future<void> withdrawApplication(String applicationId);

  /// Check if candidate has already applied to a job
  Future<bool> hasCandidateApplied(String jobId, String candidateId);

  /// Trigger AI Resume Parsing and Candidate Fit Scoring via Cloud Functions
  Future<AiParsedCv> parseResumeWithAI(String applicationId);
}

