import '../entities/question.dart';
import '../entities/question_bank.dart';

abstract class QuestionRepository {
  /// Load question banks for a company
  Future<List<QuestionBank>> getQuestionBanks(String companyId);

  /// Real-time stream of question banks for a company
  Stream<List<QuestionBank>> listenQuestionBanks(String companyId);

  /// Create a new question bank
  Future<String> createQuestionBank(QuestionBank bank);

  /// Update details of an existing question bank
  Future<void> updateQuestionBank(QuestionBank bank);

  /// Delete a question bank and its questions
  Future<void> deleteQuestionBank(String bankId);

  /// Load questions in a specific bank
  Future<List<Question>> getQuestions(
    String bankId, {
    QuestionDifficulty? difficulty,
    QuestionType? type,
    String? searchQuery,
  });

  /// Real-time stream of questions in a bank
  Stream<List<Question>> listenQuestions(String bankId);

  /// Create a single question
  Future<String> createQuestion(Question question);

  /// Update an existing question
  Future<void> updateQuestion(Question question);

  /// Delete a single question
  Future<void> deleteQuestion(String questionId, String bankId);

  /// Bulk import multiple questions into a bank
  Future<int> bulkImportQuestions(String bankId, List<Question> questions);

  /// Generate exam questions with Google Gemini AI
  Future<List<Question>> generateQuestionsWithAI({
    required String companyId,
    required String bankId,
    required String jobTitle,
    List<String> requiredSkills,
    String difficulty,
    int questionCount,
    String questionType,
  });
}
