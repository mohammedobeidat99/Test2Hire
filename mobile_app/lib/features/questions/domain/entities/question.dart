enum QuestionType {
  singleChoice,
  multipleChoice,
  trueFalse,
  coding,
  shortAnswer,
}

extension QuestionTypeExtension on QuestionType {
  String toShortString() {
    switch (this) {
      case QuestionType.singleChoice:
        return 'SINGLE_CHOICE';
      case QuestionType.multipleChoice:
        return 'MULTIPLE_CHOICE';
      case QuestionType.trueFalse:
        return 'TRUE_FALSE';
      case QuestionType.coding:
        return 'CODING';
      case QuestionType.shortAnswer:
        return 'SHORT_ANSWER';
    }
  }

  String get displayName {
    switch (this) {
      case QuestionType.singleChoice:
        return 'Single Choice';
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.trueFalse:
        return 'True / False';
      case QuestionType.coding:
        return 'Coding Challenge';
      case QuestionType.shortAnswer:
        return 'Short Answer';
    }
  }

  static QuestionType fromString(String val) {
    switch (val.toUpperCase()) {
      case 'SINGLE_CHOICE':
        return QuestionType.singleChoice;
      case 'MULTIPLE_CHOICE':
        return QuestionType.multipleChoice;
      case 'TRUE_FALSE':
        return QuestionType.trueFalse;
      case 'CODING':
        return QuestionType.coding;
      case 'SHORT_ANSWER':
        return QuestionType.shortAnswer;
      default:
        return QuestionType.singleChoice;
    }
  }
}

enum QuestionDifficulty {
  easy,
  medium,
  hard,
}

extension QuestionDifficultyExtension on QuestionDifficulty {
  String toShortString() {
    switch (this) {
      case QuestionDifficulty.easy:
        return 'EASY';
      case QuestionDifficulty.medium:
        return 'MEDIUM';
      case QuestionDifficulty.hard:
        return 'HARD';
    }
  }

  String get displayName {
    switch (this) {
      case QuestionDifficulty.easy:
        return 'Easy';
      case QuestionDifficulty.medium:
        return 'Medium';
      case QuestionDifficulty.hard:
        return 'Hard';
    }
  }

  static QuestionDifficulty fromString(String val) {
    switch (val.toUpperCase()) {
      case 'EASY':
        return QuestionDifficulty.easy;
      case 'MEDIUM':
        return QuestionDifficulty.medium;
      case 'HARD':
        return QuestionDifficulty.hard;
      default:
        return QuestionDifficulty.medium;
    }
  }
}

class QuestionOption {
  final String id;
  final String text;
  final bool isCorrect;
  final String? explanation;

  const QuestionOption({
    required this.id,
    required this.text,
    this.isCorrect = false,
    this.explanation,
  });

  QuestionOption copyWith({
    String? id,
    String? text,
    bool? isCorrect,
    String? explanation,
  }) {
    return QuestionOption(
      id: id ?? this.id,
      text: text ?? this.text,
      isCorrect: isCorrect ?? this.isCorrect,
      explanation: explanation ?? this.explanation,
    );
  }
}

class Question {
  final String id;
  final String bankId;
  final String companyId;
  final String title;
  final String description;
  final QuestionType type;
  final QuestionDifficulty difficulty;
  final int points;
  final List<QuestionOption> options;
  final List<String> correctAnswers;
  final String? sampleCodeSnippet;
  final String? programmingLanguage;
  final String? explanation;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Question({
    required this.id,
    required this.bankId,
    required this.companyId,
    required this.title,
    required this.description,
    this.type = QuestionType.singleChoice,
    this.difficulty = QuestionDifficulty.medium,
    this.points = 1,
    this.options = const [],
    this.correctAnswers = const [],
    this.sampleCodeSnippet,
    this.programmingLanguage,
    this.explanation,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isMCQ =>
      type == QuestionType.singleChoice ||
      type == QuestionType.multipleChoice ||
      type == QuestionType.trueFalse;

  bool get isCoding => type == QuestionType.coding;

  Question copyWith({
    String? id,
    String? bankId,
    String? companyId,
    String? title,
    String? description,
    QuestionType? type,
    QuestionDifficulty? difficulty,
    int? points,
    List<QuestionOption>? options,
    List<String>? correctAnswers,
    String? sampleCodeSnippet,
    String? programmingLanguage,
    String? explanation,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Question(
      id: id ?? this.id,
      bankId: bankId ?? this.bankId,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      points: points ?? this.points,
      options: options ?? this.options,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      sampleCodeSnippet: sampleCodeSnippet ?? this.sampleCodeSnippet,
      programmingLanguage: programmingLanguage ?? this.programmingLanguage,
      explanation: explanation ?? this.explanation,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
