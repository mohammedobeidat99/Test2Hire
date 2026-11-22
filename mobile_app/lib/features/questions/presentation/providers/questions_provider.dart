import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/question.dart';
import '../../domain/repositories/question_repository.dart';

class QuestionsProvider extends ChangeNotifier {
  final QuestionRepository _repository;
  StreamSubscription<List<Question>>? _subscription;

  List<Question> _allQuestions = [];
  QuestionDifficulty? _difficultyFilter;
  QuestionType? _typeFilter;
  String? _searchQuery;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  QuestionsProvider({required QuestionRepository repository})
      : _repository = repository;

  List<Question> get questions {
    var list = List<Question>.from(_allQuestions);

    if (_difficultyFilter != null) {
      list = list.where((q) => q.difficulty == _difficultyFilter).toList();
    }

    if (_typeFilter != null) {
      list = list.where((q) => q.type == _typeFilter).toList();
    }

    if (_searchQuery != null && _searchQuery!.trim().isNotEmpty) {
      final q = _searchQuery!.toLowerCase().trim();
      list = list.where((item) =>
          item.title.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q) ||
          item.tags.any((t) => t.toLowerCase().contains(q))).toList();
    }

    return list;
  }

  List<Question> get allQuestions => _allQuestions;
  QuestionDifficulty? get difficultyFilter => _difficultyFilter;
  QuestionType? get typeFilter => _typeFilter;
  String? get searchQuery => _searchQuery;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  int get totalCount => _allQuestions.length;
  int get totalPoints => _allQuestions.fold(0, (sum, q) => sum + q.points);

  int get easyCount =>
      _allQuestions.where((q) => q.difficulty == QuestionDifficulty.easy).length;
  int get mediumCount =>
      _allQuestions.where((q) => q.difficulty == QuestionDifficulty.medium).length;
  int get hardCount =>
      _allQuestions.where((q) => q.difficulty == QuestionDifficulty.hard).length;

  int get mcqCount => _allQuestions.where((q) => q.isMCQ).length;
  int get codingCount => _allQuestions.where((q) => q.isCoding).length;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void setDifficultyFilter(QuestionDifficulty? difficulty) {
    _difficultyFilter = difficulty;
    notifyListeners();
  }

  void setTypeFilter(QuestionType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  void listenQuestions(String bankId) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _repository.listenQuestions(bankId).listen(
      (list) {
        _allQuestions = list;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> loadQuestions(String bankId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allQuestions = await _repository.getQuestions(bankId);
    } on Failure catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createQuestion(Question question) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final id = await _repository.createQuestion(question);
      _successMessage = 'Question added to bank!';
      return id;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateQuestion(Question question) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateQuestion(question);
      final index = _allQuestions.indexWhere((q) => q.id == question.id);
      if (index != -1) {
        _allQuestions[index] = question;
      }
      _successMessage = 'Question updated.';
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteQuestion(String questionId, String bankId) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteQuestion(questionId, bankId);
      _allQuestions.removeWhere((q) => q.id == questionId);
      _successMessage = 'Question deleted.';
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<int> bulkImport(String bankId, List<Question> list) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final count = await _repository.bulkImportQuestions(bankId, list);
      _successMessage = 'Successfully imported $count questions!';
      return count;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return 0;
    } catch (e) {
      _errorMessage = e.toString();
      return 0;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  bool _isAiGenerating = false;
  bool get isAiGenerating => _isAiGenerating;

  Future<List<Question>> generateQuestionsWithAI({
    required String companyId,
    required String bankId,
    required String jobTitle,
    List<String> requiredSkills = const [],
    String difficulty = 'MID',
    int questionCount = 5,
    String questionType = 'SINGLE_CHOICE',
  }) async {
    _isAiGenerating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final generated = await _repository.generateQuestionsWithAI(
        companyId: companyId,
        bankId: bankId,
        jobTitle: jobTitle,
        requiredSkills: requiredSkills,
        difficulty: difficulty,
        questionCount: questionCount,
        questionType: questionType,
      );

      _allQuestions.addAll(generated);
      _successMessage = 'Successfully generated ${generated.length} questions using AI!';
      return generated;
    } on Failure catch (e) {
      _errorMessage = e.message;
      return [];
    } catch (e) {
      _errorMessage = e.toString();
      return [];
    } finally {
      _isAiGenerating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
