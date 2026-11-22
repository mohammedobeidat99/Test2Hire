import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/question.dart';
import '../models/question_bank_model.dart';
import '../models/question_model.dart';

abstract class QuestionRemoteDataSource {
  Future<List<QuestionBankModel>> getQuestionBanks(String companyId);
  Stream<List<QuestionBankModel>> listenQuestionBanks(String companyId);
  Future<String> createQuestionBank(QuestionBankModel bank);
  Future<void> updateQuestionBank(QuestionBankModel bank);
  Future<void> deleteQuestionBank(String bankId);

  Future<List<QuestionModel>> getQuestions(
    String bankId, {
    QuestionDifficulty? difficulty,
    QuestionType? type,
    String? searchQuery,
  });
  Stream<List<QuestionModel>> listenQuestions(String bankId);
  Future<String> createQuestion(QuestionModel question);
  Future<void> updateQuestion(QuestionModel question);
  Future<void> deleteQuestion(String questionId, String bankId);
  Future<int> bulkImportQuestions(String bankId, List<QuestionModel> questions);
  Future<List<QuestionModel>> generateQuestionsWithAI({
    required String companyId,
    required String bankId,
    required String jobTitle,
    List<String> requiredSkills,
    String difficulty,
    int questionCount,
    String questionType,
  });
}

class QuestionRemoteDataSourceImpl implements QuestionRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  QuestionRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  CollectionReference get _banksRef => _firestore.collection('questionBanks');
  CollectionReference get _questionsRef => _firestore.collection('questions');

  @override
  Future<List<QuestionBankModel>> getQuestionBanks(String companyId) async {
    final snap = await _banksRef
        .where('companyId', isEqualTo: companyId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    return snap.docs.map((doc) => QuestionBankModel.fromFirestore(doc)).toList();
  }

  @override
  Stream<List<QuestionBankModel>> listenQuestionBanks(String companyId) {
    return _banksRef
        .where('companyId', isEqualTo: companyId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => QuestionBankModel.fromFirestore(doc)).toList());
  }

  @override
  Future<String> createQuestionBank(QuestionBankModel bank) async {
    final docRef = await _banksRef.add(bank.toFirestore());
    return docRef.id;
  }

  @override
  Future<void> updateQuestionBank(QuestionBankModel bank) async {
    await _banksRef.doc(bank.id).update(bank.toFirestore());
  }

  static const int _maxBatchSize = 450;

  @override
  Future<void> deleteQuestionBank(String bankId) async {
    // Delete bank document and batch delete associated questions in safe chunks
    final questionsSnap = await _questionsRef.where('bankId', isEqualTo: bankId).get();
    final bankRef = _banksRef.doc(bankId);

    if (questionsSnap.docs.isEmpty) {
      await bankRef.delete();
      return;
    }

    var deletedBank = false;
    for (var i = 0; i < questionsSnap.docs.length; i += _maxBatchSize) {
      final chunk = questionsSnap.docs.skip(i).take(_maxBatchSize);
      final batch = _firestore.batch();
      if (!deletedBank) {
        batch.delete(bankRef);
        deletedBank = true;
      }
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<List<QuestionModel>> getQuestions(
    String bankId, {
    QuestionDifficulty? difficulty,
    QuestionType? type,
    String? searchQuery,
  }) async {
    Query query = _questionsRef.where('bankId', isEqualTo: bankId);

    if (difficulty != null) {
      query = query.where('difficulty', isEqualTo: difficulty.toShortString());
    }
    if (type != null) {
      query = query.where('type', isEqualTo: type.toShortString());
    }

    final snap = await query.orderBy('createdAt', descending: true).limit(200).get();
    var list = snap.docs.map((doc) => QuestionModel.fromFirestore(doc)).toList();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((item) =>
          item.title.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q) ||
          item.tags.any((t) => t.toLowerCase().contains(q))).toList();
    }

    return list;
  }

  @override
  Stream<List<QuestionModel>> listenQuestions(String bankId) {
    return _questionsRef
        .where('bankId', isEqualTo: bankId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => QuestionModel.fromFirestore(doc)).toList());
  }

  @override
  Future<String> createQuestion(QuestionModel question) async {
    final docRef = await _questionsRef.add(question.toFirestore());
    return docRef.id;
  }

  @override
  Future<void> updateQuestion(QuestionModel question) async {
    await _questionsRef.doc(question.id).update(question.toFirestore());
  }

  @override
  Future<void> deleteQuestion(String questionId, String bankId) async {
    await _questionsRef.doc(questionId).delete();
  }

  @override
  Future<int> bulkImportQuestions(String bankId, List<QuestionModel> questions) async {
    for (var i = 0; i < questions.length; i += _maxBatchSize) {
      final chunk = questions.skip(i).take(_maxBatchSize);
      final batch = _firestore.batch();
      for (final q in chunk) {
        final docRef = _questionsRef.doc();
        final model =
            QuestionModel.fromEntity(q.copyWith(id: docRef.id, bankId: bankId));
        batch.set(docRef, model.toFirestore());
      }
      await batch.commit();
    }
    return questions.length;
  }

  @override
  Future<List<QuestionModel>> generateQuestionsWithAI({
    required String companyId,
    required String bankId,
    required String jobTitle,
    List<String> requiredSkills = const [],
    String difficulty = 'MID',
    int questionCount = 5,
    String questionType = 'SINGLE_CHOICE',
  }) async {
    final callable = _functions.httpsCallable('generateExamQuestionsWithAI');

    final response = await callable.call<Map<String, dynamic>>({
      'jobTitle': jobTitle,
      'requiredSkills': requiredSkills,
      'difficulty': difficulty,
      'questionCount': questionCount,
      'questionType': questionType,
    });

    final data = response.data;
    final questionsList = data['questions'] as List<dynamic>? ?? [];

    final List<QuestionModel> generated = [];
    for (var i = 0; i < questionsList.length; i++) {
      final rawQ = questionsList[i] as Map<dynamic, dynamic>;
      final rawOptions = (rawQ['options'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      final correctIdx = rawQ['correctAnswerIndex'] is int
          ? rawQ['correctAnswerIndex'] as int
          : 0;
      final correctOptId = 'opt_${correctIdx + 1}';

      final options = rawOptions.asMap().entries.map((entry) {
        return QuestionOption(
          id: 'opt_${entry.key + 1}',
          text: entry.value,
          isCorrect: entry.key == correctIdx,
        );
      }).toList();

      final docRef = _questionsRef.doc();
      final qModel = QuestionModel(
        id: docRef.id,
        bankId: bankId,
        companyId: companyId,
        title: rawQ['question']?.toString() ?? 'Technical Assessment Question',
        description: rawQ['explanation']?.toString() ?? '',
        type: QuestionTypeExtension.fromString(rawQ['type']?.toString() ?? questionType),
        difficulty: QuestionDifficultyExtension.fromString(difficulty),
        points: (rawQ['points'] as num?)?.toInt() ?? 10,
        options: options,
        correctAnswers: [correctOptId],
        explanation: rawQ['explanation']?.toString() ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      generated.add(qModel);
    }

    if (generated.isNotEmpty) {
      for (var i = 0; i < generated.length; i += _maxBatchSize) {
        final chunk = generated.skip(i).take(_maxBatchSize);
        final batch = _firestore.batch();
        for (final qModel in chunk) {
          batch.set(_questionsRef.doc(qModel.id), qModel.toFirestore());
        }
        await batch.commit();
      }
      await _banksRef.doc(bankId).update({
        'questionsCount': FieldValue.increment(generated.length),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return generated;
  }
}
