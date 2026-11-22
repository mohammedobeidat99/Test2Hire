import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/community_post.dart';
import '../providers/community_provider.dart';

/// Reusable, modern LinkedIn-style professional community post card.
class CommunityPostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback? onCommentTapped;
  final VoidCallback? onEditTapped;

  const CommunityPostCard({
    super.key,
    required this.post,
    this.onCommentTapped,
    this.onEditTapped,
  });

  String _formatTimeAgo(DateTime dt, [bool isArabic = false]) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return isArabic ? 'الآن' : 'Just now';
    if (diff.inMinutes < 60) return isArabic ? 'منذ ${diff.inMinutes} دقيقة' : '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return isArabic ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
    if (diff.inDays < 7) return isArabic ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy', isArabic ? 'ar' : 'en').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final authUser = context.watch<AuthProvider>().user;
    final profile = context.watch<ProfileProvider>().profile;
    final communityProvider = context.read<CommunityProvider>();
    final uid = authUser?.uid ?? '';
    final isOwner = uid.isNotEmpty && post.authorId == uid;
    final isLiked = uid.isNotEmpty && post.isLikedBy(uid);
    final isCompanyAuthor =
        post.authorRole.toUpperCase() == 'COMPANY' ||
        (post.companyId?.isNotEmpty ?? false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Author Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: isCompanyAuthor
                      ? () {
                          final cId = post.companyId ?? post.authorId;
                          context.push('/company/$cId/careers');
                        }
                      : null,
                  child: Builder(
                    builder: (context) {
                      final avatarImg =
                          getSafeImageProvider(post.authorAvatarUrl);
                      return CircleAvatar(
                        radius: 21,
                        backgroundColor: isCompanyAuthor
                            ? AppColors.primarySubtle
                            : AppColors.background,
                        backgroundImage: avatarImg,
                        child: avatarImg == null
                            ? Text(
                                post.authorName.isNotEmpty
                                    ? post.authorName[0].toUpperCase()
                                    : 'P',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isCompanyAuthor
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: isCompanyAuthor
                        ? () {
                            final cId = post.companyId ?? post.authorId;
                            context.push('/company/$cId/careers');
                          }
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCompanyAuthor) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySubtle,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 11,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      l10n?.hiringBadge ?? 'Hiring',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (isArabic && (post.authorHeadline.isEmpty || post.authorHeadline == 'Career Professional')) ? 'مهني متخصص' : (isArabic && post.authorHeadline == 'Verified Employer' ? 'جهة توظيف معتمدة' : post.authorHeadline),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTimeAgo(post.createdAt, isArabic),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: AppColors.textSecondary, size: 20),
                    onSelected: (val) async {
                      if (val == 'edit') {
                        if (onEditTapped != null) {
                          onEditTapped!();
                        } else {
                          showCreateOrEditPostModal(context, existingPost: post);
                        }
                      } else if (val == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: Text(l10n?.deletePost ?? 'Delete Post'),
                            content: const Text(
                              'Are you sure you want to delete this post?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(dCtx, true),
                                child: Text(l10n?.deletePost ?? 'Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true || !context.mounted) return;
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await communityProvider.deletePost(post.id);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? (l10n?.postDeleted ?? 'Post deleted')
                                  : (communityProvider.errorMessage ??
                                      'Failed to delete post.'),
                            ),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.error,
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(l10n?.editPost ?? 'Edit Post'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline,
                                size: 18, color: AppColors.error),
                            const SizedBox(width: 8),
                            Text(
                              l10n?.deletePost ?? 'Delete Post',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // 2. Post Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post.content,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.48,
              ),
            ),
          ),

          // 3. Tags Chips
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: post.tags.map((tag) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // 4. Attached Image
          if (post.imageUrl != null && post.imageUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppSafeImage(
                url: post.imageUrl!,
                width: double.infinity,
                height: 220,
                borderRadius: BorderRadius.circular(10),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 5. Counters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.thumb_up_rounded,
                      size: 9, color: Colors.white),
                ),
                const SizedBox(width: 5),
                Text(
                  l10n != null
                      ? l10n.likesCount(post.likesCount)
                      : isArabic ? '${post.likesCount} ${post.likesCount == 1 ? "إعجاب" : "إعجابات"}' : '${post.likesCount} ${post.likesCount == 1 ? "like" : "likes"}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    if (onCommentTapped != null) {
                      onCommentTapped!();
                    } else {
                      showCommunityCommentsSheet(context, post);
                    }
                  },
                  child: Text(
                    l10n != null
                        ? l10n.commentsCount(post.commentsCount)
                        : isArabic ? '${post.commentsCount} ${post.commentsCount == 1 ? "تعليق" : "تعليقات"}' : '${post.commentsCount} ${post.commentsCount == 1 ? "comment" : "comments"}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),

          // 6. Action Bar (Like, Comment, Share)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton.icon(
                  onPressed: () {
                    if (authUser == null) return;
                    final userName = profile?.fullName.isNotEmpty == true
                        ? profile!.fullName
                        : authUser.fullName;
                    communityProvider.toggleLike(
                      postId: post.id,
                      userId: authUser.uid,
                      userName: userName,
                    );
                  },
                  icon: Icon(
                    isLiked
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_up_outlined,
                    size: 18,
                    color:
                        isLiked ? AppColors.primary : AppColors.textSecondary,
                  ),
                  label: Text(
                    isLiked
                        ? (l10n?.likedAction ?? 'Liked')
                        : (l10n?.likeAction ?? 'Like'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isLiked ? FontWeight.w700 : FontWeight.w600,
                      color:
                          isLiked ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    if (onCommentTapped != null) {
                      onCommentTapped!();
                    } else {
                      showCommunityCommentsSheet(context, post);
                    }
                  },
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  label: Text(
                    l10n?.commentAction ?? 'Comment',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: '${post.authorName}: "${post.content}" - on Test2Hire',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n?.postCopied ?? 'Post copied to clipboard!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.share_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  label: Text(
                    l10n?.shareAction ?? 'Share',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Open the professional comments bottom sheet
void showCommunityCommentsSheet(BuildContext context, CommunityPost post) {
  final communityProvider = context.read<CommunityProvider>();
  communityProvider.listenComments(post.id);
  final commentController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (modalCtx, scrollController) {
          final l10n = AppLocalizations.of(modalCtx);
          final provider = modalCtx.watch<CommunityProvider>();
          final authUser = modalCtx.watch<AuthProvider>().user;
          final profile = modalCtx.watch<ProfileProvider>().profile;
          final comments = provider.commentsForPost(post.id);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${l10n?.commentsTitle ?? "Comments"} (${comments.isNotEmpty ? comments.length : post.commentsCount})',
                        style: AppTypography.headlineSmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: comments.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.forum_outlined,
                                  size: 44,
                                  color: AppColors.textTertiary
                                      .withValues(alpha: 0.6),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  l10n?.noCommentsYet ??
                                      'No comments yet. Start the conversation!',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: comments.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, index) {
                            final comment = comments[index];
                            final isCommentOwner = authUser != null &&
                                comment.authorId == authUser.uid;
                            final isCommentCompany = comment.authorRole
                                    .toUpperCase() ==
                                'COMPANY';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final commentAvatar =
                                          getSafeImageProvider(comment.authorAvatarUrl);
                                      return CircleAvatar(
                                        radius: 16,
                                        backgroundColor: isCommentCompany
                                            ? AppColors.primarySubtle
                                            : Colors.white,
                                        backgroundImage: commentAvatar,
                                        child: commentAvatar == null
                                            ? Text(
                                                comment.authorName.isNotEmpty
                                                    ? comment.authorName[0]
                                                        .toUpperCase()
                                                    : 'U',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                comment.authorName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isCommentOwner)
                                              InkWell(
                                                onTap: () => provider
                                                    .deleteComment(
                                                  commentId: comment.id,
                                                  postId: post.id,
                                                ),
                                                child: const Icon(
                                                  Icons.delete_outline,
                                                  size: 16,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                          ],
                                        ),
                                        Text(
                                          comment.authorHeadline,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          comment.content,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: InputDecoration(
                              hintText: l10n?.addCommentHint ??
                                  'Add a thoughtful comment...',
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          icon: const Icon(Icons.send_rounded,
                              size: 18, color: Colors.white),
                          onPressed: () async {
                            if (authUser == null) return;
                            final text = commentController.text.trim();
                            if (text.isEmpty) return;
                            commentController.clear();

                            final authorName =
                                profile?.fullName.isNotEmpty == true
                                    ? profile!.fullName
                                    : authUser.fullName;
                            final authorHeadline =
                                profile?.headline?.isNotEmpty == true
                                    ? profile!.headline!
                                    : 'Career Professional';

                            final ok = await provider.addComment(
                              postId: post.id,
                              authorId: authUser.uid,
                              authorName: authorName,
                              authorHeadline: authorHeadline,
                              authorRole: authUser.role.name.toUpperCase(),
                              authorAvatarUrl: profile?.photoUrl,
                              content: text,
                            );
                            if (!ok && modalCtx.mounted) {
                              ScaffoldMessenger.of(modalCtx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.errorMessage ??
                                        'Failed to add comment.',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    commentController.dispose();
    communityProvider.stopListeningComments(post.id);
  });
}

/// Open the professional post creation or edit modal
void showCreateOrEditPostModal(
  BuildContext context, {
  CommunityPost? existingPost,
}) {
  final authUser = context.read<AuthProvider>().user;
  final profile = context.read<ProfileProvider>().profile;
  final communityProvider = context.read<CommunityProvider>();

  if (authUser == null) return;

  final contentController =
      TextEditingController(text: existingPost?.content ?? '');
  final selectedTags =
      Set<String>.from(existingPost?.tags ?? {'Career Advice'});
  Uint8List? pickedImageBytes;
  String? pickedFilePath;
  String? pickedFileName;
  String? existingImageUrl = existingPost?.imageUrl;
  bool isUploading = false;
  String? modalError;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          final l10n = AppLocalizations.of(modalCtx);
          final authorName = profile?.fullName.isNotEmpty == true
              ? profile!.fullName
              : authUser.fullName;
          final authorHeadline = profile?.headline?.isNotEmpty == true
              ? profile!.headline!
              : (authUser.isCompany
                  ? 'Verified Employer'
                  : 'Career Professional');

          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existingPost == null
                            ? (l10n?.createPostTitle ?? 'Create Professional Post')
                            : (l10n?.editPostTitle ?? 'Edit Post'),
                        style: AppTypography.headlineSmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppColors.border),
                  Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final profileAvatar =
                              getSafeImageProvider(profile?.photoUrl);
                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primarySubtle,
                            backgroundImage: profileAvatar,
                            child: profileAvatar == null
                                ? Text(
                                    authorName.isNotEmpty
                                        ? authorName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              authorHeadline,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    minLines: 3,
                    decoration: InputDecoration(
                      hintText: l10n?.postContentHint ??
                          'What career insight, advice, or update do you want to share?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tag selection
                  Text(
                    l10n?.selectTopics ?? 'Select Topics:',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      'Career Advice',
                      'Tech & Engineering',
                      'Hiring Updates',
                      'Interview Tips',
                      'Remote Work',
                    ].map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.background,
                        onSelected: (val) {
                          setModalState(() {
                            if (val) {
                              selectedTags.add(tag);
                            } else {
                              selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Image picker button / preview
                  if (pickedFileName != null || existingImageUrl != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.image,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pickedFileName ?? 'Existing Image attached',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setModalState(() {
                                pickedImageBytes = null;
                                pickedFilePath = null;
                                pickedFileName = null;
                                existingImageUrl = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                        ),
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            size: 18),
                        label: Text(
                          l10n?.addPhoto ?? 'Add Photo',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.first;
                            setModalState(() {
                              pickedImageBytes = file.bytes;
                              pickedFilePath = file.path;
                              pickedFileName = file.name;
                            });
                          }
                        },
                      ),
                      const Spacer(),
                      if (modalError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            modalError!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isUploading
                            ? null
                            : () async {
                                final text = contentController.text.trim();
                                if (text.isEmpty &&
                                    pickedFileName == null &&
                                    existingImageUrl == null) {
                                  setModalState(() {
                                    modalError = isArabic
                                        ? 'يرجى كتابة نص المنشور'
                                        : 'Please enter some text';
                                  });
                                  return;
                                }

                                setModalState(() {
                                  isUploading = true;
                                  modalError = null;
                                });

                                if (existingPost != null) {
                                  final ok = await communityProvider.updatePost(
                                    postId: existingPost.id,
                                    content: text,
                                    tags: selectedTags.toList(),
                                  );
                                  if (!ok) {
                                    if (modalCtx.mounted) {
                                      setModalState(() {
                                        isUploading = false;
                                        modalError =
                                            communityProvider.errorMessage ??
                                                (isArabic
                                                    ? 'تعذر تحديث المنشور.'
                                                    : 'Failed to update post.');
                                      });
                                    }
                                    return;
                                  }
                                  if (modalCtx.mounted) Navigator.pop(modalCtx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isArabic ? 'تم تحديث المنشور بنجاح!' : 'Post updated!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                String? uploadedUrl = existingImageUrl;
                                if (pickedFileName != null) {
                                  try {
                                    uploadedUrl =
                                        await communityProvider.uploadPostImage(
                                      userId: authUser.uid,
                                      bytes: pickedImageBytes,
                                      filePath: pickedFilePath,
                                      fileName: pickedFileName!,
                                    );
                                    if (uploadedUrl == null) {
                                      throw Exception('Failed to upload image file to storage.');
                                    }
                                  } catch (e) {
                                    if (modalCtx.mounted) {
                                      setModalState(() {
                                        isUploading = false;
                                        modalError = 'Image upload failed: $e';
                                      });
                                    }
                                    return;
                                  }
                                }

                                final ok = await communityProvider.createPost(
                                  authorId: authUser.uid,
                                  authorName: authorName,
                                  authorHeadline: authorHeadline,
                                  authorRole: authUser.role.name.toUpperCase(),
                                  authorAvatarUrl: profile?.photoUrl,
                                  companyId:
                                      authUser.isCompany ? authUser.uid : null,
                                  content: text,
                                  imageUrl: uploadedUrl,
                                  tags: selectedTags.toList(),
                                );

                                if (!ok) {
                                  if (modalCtx.mounted) {
                                    setModalState(() {
                                      isUploading = false;
                                      modalError =
                                          communityProvider.errorMessage ??
                                              'Failed to publish post.';
                                    });
                                  }
                                  return;
                                }
                                if (modalCtx.mounted) Navigator.pop(modalCtx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Published to the professional community!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              },
                        child: isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                existingPost == null
                                    ? (l10n?.publish ?? 'Publish')
                                    : (l10n?.saveChanges ?? 'Save Changes'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(contentController.dispose);
}
