class QuestionBank {
  final String id;
  final String companyId;
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final int questionsCount;
  final int totalPoints;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const QuestionBank({
    required this.id,
    required this.companyId,
    required this.title,
    required this.description,
    this.category = 'General',
    this.tags = const [],
    this.questionsCount = 0,
    this.totalPoints = 0,
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  });

  QuestionBank copyWith({
    String? id,
    String? companyId,
    String? title,
    String? description,
    String? category,
    List<String>? tags,
    int? questionsCount,
    int? totalPoints,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuestionBank(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      questionsCount: questionsCount ?? this.questionsCount,
      totalPoints: totalPoints ?? this.totalPoints,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
