import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/question_bank.dart';
import '../../domain/repositories/question_repository.dart';

class QuestionBanksProvider extends ChangeNotifier {
  final QuestionRepository _repository;
  StreamSubscription<List<QuestionBank>>? _subscription;

  List<QuestionBank> _allBanks = [];
  String? _searchQuery;
  String? _categoryFilter;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  QuestionBanksProvider({required QuestionRepository repository})
      : _repository = repository;

  List<QuestionBank> get banks {
    var list = List<QuestionBank>.from(_allBanks);

    if (_categoryFilter != null && _categoryFilter!.isNotEmpty && _categoryFilter != 'All') {
      list = list.where((b) => b.category.toLowerCase() == _categoryFilter!.toLowerCase()).toList();
    }

    if (_searchQuery != null && _searchQuery!.trim().isNotEmpty) {
      final q = _searchQuery!.toLowerCase().trim();
      list = list.where((b) =>
          b.title.toLowerCase().contains(q) ||
          b.description.toLowerCase().contains(q) ||
          b.tags.any((t) => t.toLowerCase().contains(q))).toList();
    }

    return list;
  }

  List<QuestionBank> get allBanks => _allBanks;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get searchQuery => _searchQuery;
  String? get categoryFilter => _categoryFilter;

  int get totalBanksCount => _allBanks.length;
  int get totalQuestionsCount =>
      _allBanks.fold(0, (sum, b) => sum + b.questionsCount);

  Set<String> get availableCategories {
    final set = {'All'};
    for (final b in _allBanks) {
      if (b.category.isNotEmpty) set.add(b.category);
    }
    return set;
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    notifyListeners();
  }

  void listenBanks(String companyId) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _repository.listenQuestionBanks(companyId).listen(
      (list) {
        _allBanks = list;
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

  Future<void> loadBanks(String companyId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allBanks = await _repository.getQuestionBanks(companyId);
    } on Failure catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createBank({
    required String companyId,
    required String title,
    required String description,
    String category = 'General',
    List<String> tags = const [],
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newBank = QuestionBank(
        id: '',
        companyId: companyId,
        title: title.trim(),
        description: description.trim(),
        category: category.trim(),
        tags: tags,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final bankId = await _repository.createQuestionBank(newBank);
      _successMessage = 'Question bank created successfully!';
      return bankId;
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

  Future<bool> updateBank(QuestionBank bank) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateQuestionBank(bank);
      _successMessage = 'Question bank updated.';
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

  Future<bool> deleteBank(String bankId) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteQuestionBank(bankId);
      _allBanks.removeWhere((b) => b.id == bankId);
      _successMessage = 'Question bank deleted.';
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
