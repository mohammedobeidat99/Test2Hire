import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  final String id;
  final String authorId;
  final String authorName;
  final String authorHeadline;
  final String authorRole; // 'CANDIDATE', 'COMPANY', 'ADMIN'
  final String? authorAvatarUrl;
  final String? companyId;
  final String content;
  final String? imageUrl;
  final List<String> tags;
  final List<String> likedBy;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorHeadline,
    this.authorRole = 'CANDIDATE',
    this.authorAvatarUrl,
    this.companyId,
    required this.content,
    this.imageUrl,
    this.tags = const [],
    this.likedBy = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  bool isLikedBy(String userId) => likedBy.contains(userId);

  CommunityPost copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorHeadline,
    String? authorRole,
    String? authorAvatarUrl,
    String? companyId,
    String? content,
    String? imageUrl,
    List<String>? tags,
    List<String>? likedBy,
    int? likesCount,
    int? commentsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorHeadline: authorHeadline ?? this.authorHeadline,
      authorRole: authorRole ?? this.authorRole,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      companyId: companyId ?? this.companyId,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      likedBy: likedBy ?? this.likedBy,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CommunityPost.fromMap(Map<String, dynamic> map, String id) {
    final likedByList = (map['likedBy'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final tagsList = (map['tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    DateTime parsedCreatedAt = DateTime.now();
    final rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) {
      parsedCreatedAt = rawCreated.toDate();
    } else if (rawCreated is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else if (rawCreated is int) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    }

    DateTime? parsedUpdatedAt;
    final rawUpdated = map['updatedAt'];
    if (rawUpdated is Timestamp) {
      parsedUpdatedAt = rawUpdated.toDate();
    } else if (rawUpdated is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdated);
    }

    final rawLikesCount = map['likesCount'];
    final computedLikesCount = rawLikesCount is int
        ? rawLikesCount
        : likedByList.length;

    final rawCommentsCount = map['commentsCount'];
    final computedCommentsCount = rawCommentsCount is int ? rawCommentsCount : 0;

    return CommunityPost(
      id: id,
      authorId: (map['authorId'] ?? '').toString(),
      authorName: (map['authorName'] ?? 'Professional Member').toString(),
      authorHeadline:
          (map['authorHeadline'] ?? 'Career Professional').toString(),
      authorRole: (map['authorRole'] ?? 'CANDIDATE').toString(),
      authorAvatarUrl: map['authorAvatarUrl']?.toString(),
      companyId: map['companyId']?.toString(),
      content: (map['content'] ?? '').toString(),
      imageUrl: map['imageUrl']?.toString(),
      tags: tagsList,
      likedBy: likedByList,
      likesCount: computedLikesCount < 0 ? 0 : computedLikesCount,
      commentsCount: computedCommentsCount < 0 ? 0 : computedCommentsCount,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorHeadline': authorHeadline,
      'authorRole': authorRole,
      'authorAvatarUrl': authorAvatarUrl,
      'companyId': companyId,
      'content': content,
      'imageUrl': imageUrl,
      'tags': tags,
      'likedBy': likedBy,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}

class CommunityComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorHeadline;
  final String authorRole;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorHeadline,
    this.authorRole = 'CANDIDATE',
    this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
    this.updatedAt,
  });

  CommunityComment copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorHeadline,
    String? authorRole,
    String? authorAvatarUrl,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorHeadline: authorHeadline ?? this.authorHeadline,
      authorRole: authorRole ?? this.authorRole,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CommunityComment.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedCreatedAt = DateTime.now();
    final rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) {
      parsedCreatedAt = rawCreated.toDate();
    } else if (rawCreated is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreated) ?? DateTime.now();
    }

    DateTime? parsedUpdatedAt;
    final rawUpdated = map['updatedAt'];
    if (rawUpdated is Timestamp) {
      parsedUpdatedAt = rawUpdated.toDate();
    } else if (rawUpdated is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdated);
    }

    return CommunityComment(
      id: id,
      postId: (map['postId'] ?? '').toString(),
      authorId: (map['authorId'] ?? '').toString(),
      authorName: (map['authorName'] ?? 'Member').toString(),
      authorHeadline: (map['authorHeadline'] ?? 'Professional').toString(),
      authorRole: (map['authorRole'] ?? 'CANDIDATE').toString(),
      authorAvatarUrl: map['authorAvatarUrl']?.toString(),
      content: (map['content'] ?? '').toString(),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorHeadline': authorHeadline,
      'authorRole': authorRole,
      'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
