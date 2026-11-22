import '../../../../core/errors/failures.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/question_bank.dart';
import '../../domain/repositories/question_repository.dart';
import '../datasources/question_remote_data_source.dart';
import '../models/question_bank_model.dart';
import '../models/question_model.dart';

class QuestionRepositoryImpl implements QuestionRepository {
  final QuestionRemoteDataSource _remoteDataSource;

  QuestionRepositoryImpl({required QuestionRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<QuestionBank>> getQuestionBanks(String companyId) async {
    try {
      return await _remoteDataSource.getQuestionBanks(companyId);
    } catch (e) {
      throw ServerFailure('Failed to load question banks: ${e.toString()}');
    }
  }

  @override
  Stream<List<QuestionBank>> listenQuestionBanks(String companyId) {
    return _remoteDataSource.listenQuestionBanks(companyId);
  }

  @override
  Future<String> createQuestionBank(QuestionBank bank) async {
    try {
      final model = QuestionBankModel.fromEntity(bank);
      return await _remoteDataSource.createQuestionBank(model);
    } catch (e) {
      throw ServerFailure('Failed to create question bank: ${e.toString()}');
    }
  }

  @override
  Future<void> updateQuestionBank(QuestionBank bank) async {
    try {
      final model = QuestionBankModel.fromEntity(bank);
      await _remoteDataSource.updateQuestionBank(model);
    } catch (e) {
      throw ServerFailure('Failed to update question bank: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteQuestionBank(String bankId) async {
    try {
      await _remoteDataSource.deleteQuestionBank(bankId);
    } catch (e) {
      throw ServerFailure('Failed to delete question bank: ${e.toString()}');
    }
  }

  @override
  Future<List<Question>> getQuestions(
    String bankId, {
    QuestionDifficulty? difficulty,
    QuestionType? type,
    String? searchQuery,
  }) async {
    try {
      return await _remoteDataSource.getQuestions(
        bankId,
        difficulty: difficulty,
        type: type,
        searchQuery: searchQuery,
      );
    } catch (e) {
      throw ServerFailure('Failed to load questions: ${e.toString()}');
    }
  }

  @override
  Stream<List<Question>> listenQuestions(String bankId) {
    return _remoteDataSource.listenQuestions(bankId);
  }

  @override
  Future<String> createQuestion(Question question) async {
    try {
      final model = QuestionModel.fromEntity(question);
      return await _remoteDataSource.createQuestion(model);
    } catch (e) {
      throw ServerFailure('Failed to create question: ${e.toString()}');
    }
  }

  @override
  Future<void> updateQuestion(Question question) async {
    try {
      final model = QuestionModel.fromEntity(question);
      await _remoteDataSource.updateQuestion(model);
    } catch (e) {
      throw ServerFailure('Failed to update question: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteQuestion(String questionId, String bankId) async {
    try {
      await _remoteDataSource.deleteQuestion(questionId, bankId);
    } catch (e) {
      throw ServerFailure('Failed to delete question: ${e.toString()}');
    }
  }

  @override
  Future<int> bulkImportQuestions(String bankId, List<Question> questions) async {
    try {
      final models = questions.map((q) => QuestionModel.fromEntity(q)).toList();
      return await _remoteDataSource.bulkImportQuestions(bankId, models);
    } catch (e) {
      throw ServerFailure('Failed to bulk import questions: ${e.toString()}');
    }
  }

  @override
  Future<List<Question>> generateQuestionsWithAI({
    required String companyId,
    required String bankId,
    required String jobTitle,
    List<String> requiredSkills = const [],
    String difficulty = 'MID',
    int questionCount = 5,
    String questionType = 'SINGLE_CHOICE',
  }) async {
    try {
      final models = await _remoteDataSource.generateQuestionsWithAI(
        companyId: companyId,
        bankId: bankId,
        jobTitle: jobTitle,
        requiredSkills: requiredSkills,
        difficulty: difficulty,
        questionCount: questionCount,
        questionType: questionType,
      );
      return models;
    } catch (e) {
      throw ServerFailure('Failed to generate AI questions: ${e.toString()}');
    }
  }
}
