import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/question.dart';

class QuestionOptionModel extends QuestionOption {
  const QuestionOptionModel({
    required super.id,
    required super.text,
    super.isCorrect,
    super.explanation,
  });

  factory QuestionOptionModel.fromMap(Map<String, dynamic> map) {
    return QuestionOptionModel(
      id: map['id'] as String? ?? '',
      text: map['text'] as String? ?? '',
      isCorrect: map['isCorrect'] as bool? ?? false,
      explanation: map['explanation'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isCorrect': isCorrect,
      'explanation': explanation,
    };
  }

  factory QuestionOptionModel.fromEntity(QuestionOption option) {
    return QuestionOptionModel(
      id: option.id,
      text: option.text,
      isCorrect: option.isCorrect,
      explanation: option.explanation,
    );
  }
}

class QuestionModel extends Question {
  const QuestionModel({
    required super.id,
    required super.bankId,
    required super.companyId,
    required super.title,
    required super.description,
    super.type,
    super.difficulty,
    super.points,
    super.options,
    super.correctAnswers,
    super.sampleCodeSnippet,
    super.programmingLanguage,
    super.explanation,
    super.tags,
    super.createdAt,
    super.updatedAt,
  });

  factory QuestionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawOptions = data['options'] as List<dynamic>? ?? [];
    final optionsList = rawOptions
        .map((opt) => QuestionOptionModel.fromMap(Map<String, dynamic>.from(opt as Map)))
        .toList();

    return QuestionModel(
      id: doc.id,
      bankId: data['bankId'] as String? ?? '',
      companyId: data['companyId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      type: QuestionTypeExtension.fromString(data['type'] as String? ?? 'SINGLE_CHOICE'),
      difficulty: QuestionDifficultyExtension.fromString(data['difficulty'] as String? ?? 'MEDIUM'),
      points: (data['points'] as num?)?.toInt() ?? 1,
      options: optionsList,
      correctAnswers: (data['correctAnswers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      sampleCodeSnippet: data['sampleCodeSnippet'] as String?,
      programmingLanguage: data['programmingLanguage'] as String?,
      explanation: data['explanation'] as String?,
      tags: (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bankId': bankId,
      'companyId': companyId,
      'title': title,
      'description': description,
      'type': type.toShortString(),
      'difficulty': difficulty.toShortString(),
      'points': points,
      'options': options.map((opt) => QuestionOptionModel.fromEntity(opt).toMap()).toList(),
      'correctAnswers': correctAnswers,
      'sampleCodeSnippet': sampleCodeSnippet,
      'programmingLanguage': programmingLanguage,
      'explanation': explanation,
      'tags': tags,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory QuestionModel.fromEntity(Question q) {
    return QuestionModel(
      id: q.id,
      bankId: q.bankId,
      companyId: q.companyId,
      title: q.title,
      description: q.description,
      type: q.type,
      difficulty: q.difficulty,
      points: q.points,
      options: q.options,
      correctAnswers: q.correctAnswers,
      sampleCodeSnippet: q.sampleCodeSnippet,
      programmingLanguage: q.programmingLanguage,
      explanation: q.explanation,
      tags: q.tags,
      createdAt: q.createdAt,
      updatedAt: q.updatedAt,
    );
  }
}
