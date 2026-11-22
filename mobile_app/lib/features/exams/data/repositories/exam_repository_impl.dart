import '../../../../core/errors/failures.dart';
import '../../domain/entities/exam_template.dart';
import '../../domain/repositories/exam_repository.dart';
import '../datasources/exam_remote_data_source.dart';
import '../models/exam_template_model.dart';

class ExamRepositoryImpl implements ExamRepository {
  final ExamRemoteDataSource _remoteDataSource;

  ExamRepositoryImpl({required ExamRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<ExamTemplate>> getCompanyExams(String companyId) async {
    try {
      return await _remoteDataSource.getCompanyExams(companyId);
    } catch (e) {
      throw ServerFailure('Failed to load company exams: ${e.toString()}');
    }
  }

  @override
  Stream<List<ExamTemplate>> listenCompanyExams(String companyId) {
    return _remoteDataSource.listenCompanyExams(companyId);
  }

  @override
  Future<ExamTemplate> getExamById(String examId) async {
    try {
      return await _remoteDataSource.getExamById(examId);
    } catch (e) {
      throw ServerFailure('Failed to load exam details: ${e.toString()}');
    }
  }

  @override
  Future<String> createExam(ExamTemplate exam) async {
    try {
      final model = ExamTemplateModel.fromEntity(exam);
      return await _remoteDataSource.createExam(model);
    } catch (e) {
      throw ServerFailure('Failed to create exam: ${e.toString()}');
    }
  }

  @override
  Future<void> updateExam(ExamTemplate exam) async {
    try {
      final model = ExamTemplateModel.fromEntity(exam);
      await _remoteDataSource.updateExam(model);
    } catch (e) {
      throw ServerFailure('Failed to update exam: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteExam(String examId) async {
    try {
      await _remoteDataSource.deleteExam(examId);
    } catch (e) {
      throw ServerFailure('Failed to delete exam: ${e.toString()}');
    }
  }

  @override
  Future<AssignExamResult> assignExam({
    required String examId,
    required String applicationId,
    required String candidateId,
    String? jobId,
    int? durationMinutes,
    int? deadlineDays,
  }) async {
    try {
      return await _remoteDataSource.assignExam(
        examId: examId,
        applicationId: applicationId,
        candidateId: candidateId,
        jobId: jobId,
        durationMinutes: durationMinutes,
        deadlineDays: deadlineDays,
      );
    } catch (e) {
      throw ServerFailure('Failed to assign exam: ${e.toString()}');
    }
  }

  @override
  Future<List<ExamAttempt>> getCandidateAttempts(String candidateId) async {
    try {
      return await _remoteDataSource.getCandidateAttempts(candidateId);
    } catch (e) {
      throw ServerFailure('Failed to load assessment invitations: ${e.toString()}');
    }
  }

  @override
  Stream<List<ExamAttempt>> listenCandidateAttempts(String candidateId) {
    return _remoteDataSource.listenCandidateAttempts(candidateId);
  }

  @override
  Future<String> quickGenerateExamForRole({
    required String companyId,
    required String roleTitle,
  }) async {
    try {
      return await _remoteDataSource.quickGenerateExamForRole(
        companyId: companyId,
        roleTitle: roleTitle,
      );
    } catch (e) {
      throw ServerFailure('Failed to generate assessment: ${e.toString()}');
    }
  }
}
