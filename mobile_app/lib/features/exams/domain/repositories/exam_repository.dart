import '../entities/exam_template.dart';

abstract class ExamRepository {
  /// Load exams authored by a company
  Future<List<ExamTemplate>> getCompanyExams(String companyId);

  /// Real-time stream of exams for a company
  Stream<List<ExamTemplate>> listenCompanyExams(String companyId);

  /// Fetch single exam by ID
  Future<ExamTemplate> getExamById(String examId);

  /// Create a new exam template
  Future<String> createExam(ExamTemplate exam);

  /// Update an existing exam template
  Future<void> updateExam(ExamTemplate exam);

  /// Delete or archive an exam template
  Future<void> deleteExam(String examId);

  /// Assign exam to candidate application with secure access token
  Future<AssignExamResult> assignExam({
    required String examId,
    required String applicationId,
    required String candidateId,
    String? jobId,
    int? durationMinutes,
    int? deadlineDays,
  });

  /// Load assessment attempts/invitations for a candidate
  Future<List<ExamAttempt>> getCandidateAttempts(String candidateId);

  /// Real-time stream of attempts for a candidate
  Stream<List<ExamAttempt>> listenCandidateAttempts(String candidateId);

  /// Quick-generate an AI technical assessment template for a specific job role
  Future<String> quickGenerateExamForRole({
    required String companyId,
    required String roleTitle,
  });
}
