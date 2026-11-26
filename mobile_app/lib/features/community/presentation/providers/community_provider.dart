import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/community_post.dart';

class CommunityProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  List<CommunityPost> _posts = [];
  final Map<String, List<CommunityComment>> _commentsByPostId = {};
  final Set<String> _loadingCommentPostIds = {};
  final Set<String> _likeInFlightPostIds = {};

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String _selectedTopic = 'All';
  String _searchQuery = '';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _postsSubscription;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _commentSubscriptions = {};

  CommunityProvider({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  List<CommunityPost> get allPosts => _posts;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String get selectedTopic => _selectedTopic;
  String get searchQuery => _searchQuery;

  List<CommunityPost> get filteredPosts {
    return _posts.where((p) {
      if (_selectedTopic != 'All' &&
          !p.tags.any((t) => t.toLowerCase() == _selectedTopic.toLowerCase()) &&
          (p.authorRole.toLowerCase() != _selectedTopic.toLowerCase())) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        return p.content.toLowerCase().contains(q) ||
            p.authorName.toLowerCase().contains(q) ||
            p.authorHeadline.toLowerCase().contains(q) ||
            p.tags.any((t) => t.toLowerCase().contains(q));
      }
      return true;
    }).toList();
  }

  List<CommunityPost> postsByAuthor(String authorId) {
    return _posts.where((p) => p.authorId == authorId).toList();
  }

  List<CommunityComment> commentsForPost(String postId) {
    return _commentsByPostId[postId] ?? const [];
  }

  bool isLoadingComments(String postId) {
    return _loadingCommentPostIds.contains(postId);
  }

  void setTopic(String topic) {
    if (_selectedTopic == topic) return;
    _selectedTopic = topic;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void listenFeed() {
    _postsSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _postsSubscription = _firestore
        .collection('communityPosts')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .listen(
      (snapshot) {
        final loaded = snapshot.docs
            .map((doc) => CommunityPost.fromMap(doc.data(), doc.id))
            .toList();
        loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _posts = loaded;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        _errorMessage = err.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> refreshFeed() async {
    try {
      final snapshot = await _firestore
          .collection('communityPosts')
          .orderBy('createdAt', descending: true)
          .limit(60)
          .get();
      final loaded = snapshot.docs
          .map((doc) => CommunityPost.fromMap(doc.data(), doc.id))
          .toList();
      loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _posts = loaded;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void listenComments(String postId) {
    _commentSubscriptions[postId]?.cancel();
    if (!_commentsByPostId.containsKey(postId)) {
      _loadingCommentPostIds.add(postId);
      notifyListeners();
    }
    _commentSubscriptions[postId] = _firestore
        .collection('communityComments')
        .where('postId', isEqualTo: postId)
        .limit(100)
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs
            .map((doc) => CommunityComment.fromMap(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _commentsByPostId[postId] = list;
        _loadingCommentPostIds.remove(postId);
        notifyListeners();
      },
      onError: (err) {
        _loadingCommentPostIds.remove(postId);
        _errorMessage = err.toString();
        notifyListeners();
      },
    );
  }

  void stopListeningComments(String postId) {
    _commentSubscriptions.remove(postId)?.cancel();
  }

  Future<String?> uploadPostImage({
    required String userId,
    Uint8List? bytes,
    String? filePath,
    required String fileName,
  }) async {
    final sanitized = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        'community_posts/$userId/${DateTime.now().millisecondsSinceEpoch}_$sanitized';
    final ref = _storage.ref().child(storagePath);

    final ext = fileName.split('.').last.toLowerCase();
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : ext == 'gif'
                ? 'image/gif'
                : 'image/jpeg';

    Uint8List? uploadBytes = bytes;
    if (!kIsWeb && uploadBytes == null && filePath != null) {
      final f = File(filePath);
      if (await f.exists()) {
        uploadBytes = await f.readAsBytes();
      }
    }

    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {'uploadedBy': userId},
    );

    UploadTask uploadTask;
    if (uploadBytes != null) {
      uploadTask = ref.putData(uploadBytes, metadata);
    } else if (!kIsWeb && filePath != null) {
      uploadTask = ref.putFile(File(filePath), metadata);
    } else {
      return null;
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<bool> createPost({
    required String authorId,
    required String authorName,
    required String authorHeadline,
    String authorRole = 'CANDIDATE',
    String? authorAvatarUrl,
    String? companyId,
    required String content,
    String? imageUrl,
    List<String> tags = const [],
  }) async {
    if (content.trim().isEmpty && (imageUrl == null || imageUrl.isEmpty)) {
      _errorMessage = 'Please write something or attach an image to publish.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final docRef = _firestore.collection('communityPosts').doc();
      final newPost = CommunityPost(
        id: docRef.id,
        authorId: authorId,
        authorName: authorName,
        authorHeadline: authorHeadline,
        authorRole: authorRole,
        authorAvatarUrl: authorAvatarUrl,
        companyId: companyId,
        content: content.trim(),
        imageUrl: imageUrl,
        tags: tags,
        likedBy: const [],
        likesCount: 0,
        commentsCount: 0,
        createdAt: now,
      );

      // Optimistic insertion
      _posts = [newPost, ..._posts];
      notifyListeners();

      await docRef.set(newPost.toMap());
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePost({
    required String postId,
    required String content,
    List<String>? tags,
  }) async {
    if (content.trim().isEmpty) return false;
    _isSubmitting = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final idx = _posts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        _posts[idx] = _posts[idx].copyWith(
          content: content.trim(),
          tags: tags ?? _posts[idx].tags,
          updatedAt: now,
        );
        notifyListeners();
      }

      await _firestore.collection('communityPosts').doc(postId).update({
        'content': content.trim(),
        'tags': ?tags,
        'updatedAt': Timestamp.fromDate(now),
      });
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    final backup = List<CommunityPost>.from(_posts);
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();

    try {
      await _firestore.collection('communityPosts').doc(postId).delete();
      return true;
    } catch (e) {
      _posts = backup;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleLike({
    required String postId,
    required String userId,
    required String userName,
  }) async {
    if (_likeInFlightPostIds.contains(postId)) return;
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    _likeInFlightPostIds.add(postId);
    final original = _posts[idx];
    final currentlyLiked = original.isLikedBy(userId);
    final updatedLikedBy = List<String>.from(original.likedBy);

    if (currentlyLiked) {
      updatedLikedBy.remove(userId);
    } else {
      if (!updatedLikedBy.contains(userId)) {
        updatedLikedBy.add(userId);
      }
    }

    final updatedPost = original.copyWith(
      likedBy: updatedLikedBy,
      likesCount: updatedLikedBy.length,
    );

    // 0ms optimistic update
    _posts[idx] = updatedPost;
    notifyListeners();

    try {
      await _firestore.collection('communityPosts').doc(postId).update({
        'likedBy': updatedLikedBy,
        'likesCount': updatedLikedBy.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify post author when someone else likes their post
      if (!currentlyLiked && original.authorId != userId) {
        final snippet = original.content.length > 50
            ? '${original.content.substring(0, 50)}...'
            : original.content;
        await _firestore.collection('notifications').add({
          'userId': original.authorId,
          'title': 'أُعجب $userName بمنشورك',
          'body': snippet.isNotEmpty ? '"$snippet"' : 'أبدى إعجابه بمنشورك في المجتمع.',
          'type': 'COMMUNITY_LIKE',
          'actionUrl': '/community',
          'link': '/company/community',
          'data': {
            'postId': postId,
            'senderId': userId,
            'senderName': userName,
            'action': 'LIKE',
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Revert on failure
      final revertIdx = _posts.indexWhere((p) => p.id == postId);
      if (revertIdx != -1) {
        _posts[revertIdx] = original;
        notifyListeners();
      }
    } finally {
      _likeInFlightPostIds.remove(postId);
    }
  }

  Future<bool> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String authorHeadline,
    String authorRole = 'CANDIDATE',
    String? authorAvatarUrl,
    required String content,
  }) async {
    if (content.trim().isEmpty) return false;

    final now = DateTime.now();
    final commentRef = _firestore.collection('communityComments').doc();
    final comment = CommunityComment(
      id: commentRef.id,
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      authorHeadline: authorHeadline,
      authorRole: authorRole,
      authorAvatarUrl: authorAvatarUrl,
      content: content.trim(),
      createdAt: now,
    );

    // Optimistic local state update
    final previousComments = List<CommunityComment>.from(
      _commentsByPostId[postId] ?? const [],
    );
    final existing = List<CommunityComment>.from(previousComments);
    existing.add(comment);
    _commentsByPostId[postId] = existing;

    final postIdx = _posts.indexWhere((p) => p.id == postId);
    CommunityPost? targetPost;
    if (postIdx != -1) {
      targetPost = _posts[postIdx];
      _posts[postIdx] = targetPost.copyWith(
        commentsCount: targetPost.commentsCount + 1,
      );
    }
    notifyListeners();

    try {
      await commentRef.set(comment.toMap());
      await _firestore.collection('communityPosts').doc(postId).update({
        'commentsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (targetPost != null && targetPost.authorId != authorId) {
        final commentSnippet = content.trim().length > 80
            ? '${content.trim().substring(0, 80)}...'
            : content.trim();
        await _firestore.collection('notifications').add({
          'userId': targetPost.authorId,
          'title': 'علّق $authorName على منشورك',
          'body': commentSnippet,
          'type': 'COMMUNITY_COMMENT',
          'actionUrl': '/community',
          'link': '/company/community',
          'data': {
            'postId': postId,
            'commentId': commentRef.id,
            'senderId': authorId,
            'senderName': authorName,
            'action': 'COMMENT',
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      _commentsByPostId[postId] = previousComments;
      if (targetPost != null) {
        final revertIdx = _posts.indexWhere((p) => p.id == postId);
        if (revertIdx != -1) {
          _posts[revertIdx] = targetPost;
        }
      }
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateComment({
    required String commentId,
    required String postId,
    required String content,
  }) async {
    if (content.trim().isEmpty) return false;
    try {
      final now = DateTime.now();
      final list = _commentsByPostId[postId];
      if (list != null) {
        final idx = list.indexWhere((c) => c.id == commentId);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(content: content.trim(), updatedAt: now);
          notifyListeners();
        }
      }
      await _firestore.collection('communityComments').doc(commentId).update({
        'content': content.trim(),
        'updatedAt': Timestamp.fromDate(now),
      });
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteComment({
    required String commentId,
    required String postId,
  }) async {
    final previousComments = List<CommunityComment>.from(
      _commentsByPostId[postId] ?? const [],
    );
    final postIdx = _posts.indexWhere((p) => p.id == postId);
    final previousPost = postIdx != -1 ? _posts[postIdx] : null;

    final list = _commentsByPostId[postId];
    if (list != null) {
      list.removeWhere((c) => c.id == commentId);
    }
    if (postIdx != -1) {
      final currentCount = _posts[postIdx].commentsCount;
      _posts[postIdx] = _posts[postIdx].copyWith(
        commentsCount: currentCount > 0 ? currentCount - 1 : 0,
      );
    }
    notifyListeners();

    try {
      await _firestore.collection('communityComments').doc(commentId).delete();
      await _firestore.collection('communityPosts').doc(postId).update({
        'commentsCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _commentsByPostId[postId] = previousComments;
      if (previousPost != null) {
        final revertIdx = _posts.indexWhere((p) => p.id == postId);
        if (revertIdx != -1) {
          _posts[revertIdx] = previousPost;
        }
      }
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    for (final sub in _commentSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
