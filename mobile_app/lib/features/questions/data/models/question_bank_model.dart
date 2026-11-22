import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/question_bank.dart';

class QuestionBankModel extends QuestionBank {
  const QuestionBankModel({
    required super.id,
    required super.companyId,
    required super.title,
    required super.description,
    super.category,
    super.tags,
    super.questionsCount,
    super.totalPoints,
    super.isArchived,
    super.createdAt,
    super.updatedAt,
  });

  factory QuestionBankModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return QuestionBankModel(
      id: doc.id,
      companyId: data['companyId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? 'General',
      tags: (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      questionsCount: (data['questionsCount'] as num?)?.toInt() ?? 0,
      totalPoints: (data['totalPoints'] as num?)?.toInt() ?? 0,
      isArchived: data['isArchived'] as bool? ?? false,
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'title': title,
      'description': description,
      'category': category,
      'tags': tags,
      'questionsCount': questionsCount,
      'totalPoints': totalPoints,
      'isArchived': isArchived,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory QuestionBankModel.fromEntity(QuestionBank bank) {
    return QuestionBankModel(
      id: bank.id,
      companyId: bank.companyId,
      title: bank.title,
      description: bank.description,
      category: bank.category,
      tags: bank.tags,
      questionsCount: bank.questionsCount,
      totalPoints: bank.totalPoints,
      isArchived: bank.isArchived,
      createdAt: bank.createdAt,
      updatedAt: bank.updatedAt,
    );
  }
}
