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
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/community_post.dart';
import '../providers/community_provider.dart';

class CommunityFeedScreen extends StatefulWidget {
  final bool embeddedInShell;

  const CommunityFeedScreen({
    super.key,
    this.embeddedInShell = false,
  });

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _topics = [
    'All',
    'Career Advice',
    'Tech & Engineering',
    'Hiring Updates',
    'Interview Tips',
  ];

  static String localizeTopic(String topic, bool isArabic) {
    if (!isArabic) return topic;
    switch (topic) {
      case 'All': return 'الكل';
      case 'Career Advice': return 'نصائح مهنية';
      case 'Tech & Engineering': return 'تكنولوجيا وبرمجة';
      case 'Hiring Updates': return 'مستجدات التوظيف';
      case 'Interview Tips': return 'نصائح المقابلات';
      default: return topic;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<CommunityProvider>();
      if (provider.allPosts.isEmpty) {
        provider.listenFeed();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateOrEditPostModal(BuildContext context, {CommunityPost? existingPost}) {
    final authUser = context.read<AuthProvider>().user;
    final profile = context.read<ProfileProvider>().profile;
    final communityProvider = context.read<CommunityProvider>();

    if (authUser == null) return;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final contentController = TextEditingController(text: existingPost?.content ?? '');
    final selectedTags = Set<String>.from(existingPost?.tags ?? {'Career Advice'});
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
            final authorName = profile?.fullName.isNotEmpty == true
                ? profile!.fullName
                : authUser.fullName;
            final authorHeadline = profile?.headline?.isNotEmpty == true
                ? profile!.headline!
                : (authUser.isCompany ? (isArabic ? 'جهة توظيف معتمدة' : 'Verified Employer') : (isArabic ? 'مهني متخصص' : 'Career Professional'));

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
                          existingPost == null ? 'Create Professional Post' : 'Edit Post',
                          style: AppTypography.headlineSmall,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Builder(
                          builder: (context) {
                            final avatarImg =
                                getSafeImageProvider(profile?.photoUrl);
                            return CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primarySubtle,
                              backgroundImage: avatarImg,
                              child: avatarImg == null
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: contentController,
                      maxLines: 5,
                      minLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            isArabic ? 'شارك إنجازاً مهنياً، نصيحة تقنية، تجربة مقابلة، أو استفساراً مع المجتمع...' : 'Share a professional achievement, technical insight, interview experience, or question with the community...',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isArabic ? 'اختر تصنيفات الموضوع' : 'Select Topic Tags',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _topics.where((t) => t != 'All').map((topic) {
                        final isSelected = selectedTags.contains(topic);
                        return FilterChip(
                          label: Text(localizeTopic(topic, isArabic), style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          selectedColor: AppColors.primarySubtle,
                          checkmarkColor: AppColors.primary,
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                selectedTags.add(topic);
                              } else if (selectedTags.length > 1) {
                                selectedTags.remove(topic);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    if (existingPost == null) ...[
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: isUploading
                                ? null
                                : () async {
                                    final res = await FilePicker.platform.pickFiles(
                                      type: FileType.image,
                                      withData: true,
                                    );
                                    if (res != null && res.files.isNotEmpty) {
                                      final f = res.files.first;
                                      setModalState(() {
                                        pickedImageBytes = f.bytes;
                                        pickedFilePath = f.path;
                                        pickedFileName = f.name;
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.image_outlined, size: 18),
                            label: Text(
                              pickedFileName != null ? (isArabic ? 'تغيير الصورة' : 'Change Photo') : (isArabic ? 'إضافة صورة' : 'Add Photo'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (pickedFileName != null) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                pickedFileName!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setModalState(() {
                                  pickedImageBytes = null;
                                  pickedFilePath = null;
                                  pickedFileName = null;
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isUploading
                            ? null
                            : () async {
                                final text = contentController.text.trim();
                                if (text.isEmpty && pickedFileName == null && existingImageUrl == null) {
                                  setModalState(() {
                                    modalError = isArabic
                                        ? 'يرجى كتابة محتوى المنشور أولاً.'
                                        : 'Please enter post content first.';
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
                                        modalError = communityProvider.errorMessage ??
                                            (isArabic ? 'تعذر تحديث المنشور.' : 'Failed to update post.');
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
                                        modalError = isArabic
                                            ? 'فشل رفع الصورة: $e'
                                            : 'Image upload failed: $e';
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
                                  companyId: authUser.isCompany ? authUser.uid : null,
                                  content: text,
                                  imageUrl: uploadedUrl,
                                  tags: selectedTags.toList(),
                                );

                                if (!ok) {
                                  if (modalCtx.mounted) {
                                    setModalState(() {
                                      isUploading = false;
                                      modalError = communityProvider.errorMessage ??
                                          (isArabic ? 'تعذر نشر المنشور.' : 'Failed to publish post.');
                                    });
                                  }
                                  return;
                                }
                                if (modalCtx.mounted) Navigator.pop(modalCtx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isArabic ? 'تم نشر المنشور في المجتمع المهني!' : 'Published to the professional community!'),
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
                                existingPost == null ? (isArabic ? 'نشر المنشور' : 'Publish Post') : (isArabic ? 'حفظ التعديلات' : 'Save Changes'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
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

  void _openCommentsSheet(BuildContext context, CommunityPost post) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
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
                          'Comments (${comments.isNotEmpty ? comments.length : post.commentsCount})',
                          style: AppTypography.headlineSmall,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
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
                                    color: AppColors.textTertiary.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'No comments yet. Start the conversation!',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: comments.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (ctx, index) {
                              final c = comments[index];
                              final isCommentOwner = authUser?.uid == c.authorId;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Builder(
                                          builder: (context) {
                                            final commentAvatar = getSafeImageProvider(c.authorAvatarUrl);
                                            return CircleAvatar(
                                              radius: 15,
                                              backgroundColor: AppColors.primarySubtle,
                                              backgroundImage: commentAvatar,
                                              child: commentAvatar == null
                                                  ? Text(
                                                      c.authorName.isNotEmpty
                                                          ? c.authorName[0].toUpperCase()
                                                          : 'M',
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
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c.authorName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                c.authorHeadline,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _formatTimeAgo(c.createdAt, isArabic),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                        if (isCommentOwner)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: AppColors.error,
                                            ),
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () {
                                              provider.deleteComment(
                                                commentId: c.id,
                                                postId: post.id,
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      c.content,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                        height: 1.4,
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
                                hintText: isArabic ? 'اكتب تعليقاً هادفاً...' : 'Add a thoughtful comment...',
                                isDense: true,
                                filled: true,
                                fillColor: AppColors.background,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                            onPressed: () async {
                              if (authUser == null) return;
                              final text = commentController.text.trim();
                              if (text.isEmpty) return;
                              commentController.clear();

                              final authorName = profile?.fullName.isNotEmpty == true
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
                                          (isArabic
                                              ? 'تعذر إرسال التعليق.'
                                              : 'Failed to add comment.'),
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

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context);
    final communityProvider = context.watch<CommunityProvider>();
    final authUser = context.watch<AuthProvider>().user;
    final profile = context.watch<ProfileProvider>().profile;
    final posts = communityProvider.filteredPosts;

    final authorName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : (authUser?.fullName ?? 'Member');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embeddedInShell,
        title: Text(l10n?.communityFeedTitle ?? 'Professional Community'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: AppColors.primary),
            tooltip: l10n?.createPostTooltip ?? 'Create Post',
            onPressed: () => _openCreateOrEditPostModal(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => communityProvider.refreshFeed(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Composer + Search + Topic Filters
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Start a post composer box
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Builder(
                              builder: (context) {
                                final composerAvatar = getSafeImageProvider(profile?.photoUrl);
                                return CircleAvatar(
                                  radius: 19,
                                  backgroundColor: AppColors.primarySubtle,
                                  backgroundImage: composerAvatar,
                                  child: composerAvatar == null
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
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () => _openCreateOrEditPostModal(context),
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    isArabic ? 'شارك تحديثاً، نصيحة، أو إنجازاً مهنياً...' : 'Share a career update, insight, or question...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ComposerActionButton(
                              icon: Icons.photo_library_outlined,
                              label: isArabic ? 'صورة' : 'Photo',
                              color: AppColors.success,
                              onTap: () => _openCreateOrEditPostModal(context),
                            ),
                            _ComposerActionButton(
                              icon: Icons.lightbulb_outline_rounded,
                              label: isArabic ? 'فكرة' : 'Insight',
                              color: AppColors.warning,
                              onTap: () => _openCreateOrEditPostModal(context),
                            ),
                            _ComposerActionButton(
                              icon: Icons.help_outline_rounded,
                              label: isArabic ? 'سؤال' : 'Ask Question',
                              color: AppColors.primary,
                              onTap: () => _openCreateOrEditPostModal(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: communityProvider.setSearchQuery,
                      decoration: InputDecoration(
                        hintText: isArabic ? 'ابحث عن منشورات، أشخاص، أو مواضيع...' : 'Search posts, people, or topics...',
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  communityProvider.setSearchQuery('');
                                },
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  ),
                  const SizedBox(height: 10),

                  // Topic Filter Chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _topics.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final topic = _topics[index];
                        final isSelected = communityProvider.selectedTopic == topic;
                        return ChoiceChip(
                          label: Text(
                            localizeTopic(topic, isArabic),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
                          onSelected: (_) => communityProvider.setTopic(topic),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // 2. Feed List
            if (communityProvider.isLoading && posts.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (posts.isEmpty && communityProvider.errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          communityProvider.errorMessage!,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => communityProvider.listenFeed(),
                          icon: const Icon(Icons.refresh),
                          label: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateWidget(
                  icon: Icons.groups_rounded,
                  title: isArabic ? 'ابدأ أول نقاش مهني' : 'Start the First Discussion',
                  description:
                      isArabic ? 'شارك نصائحك وتجاربك مع مجتمع المرشحين وفرق التوظيف.' : 'Share career insights, technical tips, or questions with candidates and hiring teams.',
                  actionLabel: isArabic ? 'إنشاء منشور' : 'Create Post',
                  actionIcon: Icons.edit_outlined,
                  onAction: () => _openCreateOrEditPostModal(context),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList.separated(
                  itemCount: posts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _buildPostCard(context, post);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, CommunityPost post) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final authUser = context.watch<AuthProvider>().user;
    final profile = context.watch<ProfileProvider>().profile;
    final communityProvider = context.read<CommunityProvider>();
    final uid = authUser?.uid ?? '';
    final isOwner = uid.isNotEmpty && post.authorId == uid;
    final isLiked = uid.isNotEmpty && post.isLikedBy(uid);
    final isCompanyAuthor =
        post.authorRole.toUpperCase() == 'COMPANY' || (post.companyId?.isNotEmpty ?? false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
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
                      final postAvatar = getSafeImageProvider(post.authorAvatarUrl);
                      return CircleAvatar(
                        radius: 21,
                        backgroundColor: isCompanyAuthor
                            ? AppColors.accent.withValues(alpha: 0.12)
                            : AppColors.primarySubtle,
                        backgroundImage: postAvatar,
                        child: postAvatar == null
                            ? Text(
                                post.authorName.isNotEmpty
                                    ? post.authorName[0].toUpperCase()
                                    : 'P',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCompanyAuthor ? AppColors.accent : AppColors.primary,
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
                                  fontSize: 14,
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
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded,
                                        size: 11, color: AppColors.primary),
                                    SizedBox(width: 3),
                                    Text(
                                      'Company',
                                      style: TextStyle(
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
                    icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                    onSelected: (val) async {
                      if (val == 'edit') {
                        _openCreateOrEditPostModal(context, existingPost: post);
                      } else if (val == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: Text(isArabic ? 'حذف المنشور' : 'Delete Post'),
                            content: Text(
                              isArabic
                                  ? 'هل أنت متأكد من حذف هذا المنشور؟'
                                  : 'Are you sure you want to delete this post?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, false),
                                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(dCtx, true),
                                child: Text(isArabic ? 'حذف' : 'Delete'),
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
                                  ? (isArabic ? 'تم حذف المنشور' : 'Post deleted')
                                  : (communityProvider.errorMessage ??
                                      (isArabic
                                          ? 'تعذر حذف المنشور.'
                                          : 'Failed to delete post.')),
                            ),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.error,
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Post'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Delete Post', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Post Body Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post.content,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),

          // Tags
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: post.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

          // Attached Image
          if (post.imageUrl != null && post.imageUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            AppSafeImage(
              url: post.imageUrl!,
              width: double.infinity,
              height: 210,
              borderRadius: BorderRadius.circular(10),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ],

          const SizedBox(height: 12),

          // Counters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.thumb_up_alt_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  isArabic ? '${post.likesCount} ${post.likesCount == 1 ? "إعجاب" : "إعجابات"}' : '${post.likesCount} ${post.likesCount == 1 ? "like" : "likes"}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _openCommentsSheet(context, post),
                  child: Text(
                    isArabic ? '${post.commentsCount} ${post.commentsCount == 1 ? "تعليق" : "تعليقات"}' : '${post.commentsCount} ${post.commentsCount == 1 ? "comment" : "comments"}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // Action Bar (Like, Comment, Share)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    isLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_off_alt,
                    size: 18,
                    color: isLiked ? AppColors.primary : AppColors.textSecondary,
                  ),
                  label: Text(
                    isLiked ? (isArabic ? 'أعجبني' : 'Liked') : (isArabic ? 'إعجاب' : 'Like'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isLiked ? FontWeight.w700 : FontWeight.w600,
                      color: isLiked ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openCommentsSheet(context, post),
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  label: Text(
                    isArabic ? 'تعليق' : 'Comment',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: '${post.authorName} on Test2Hire Community:\n"${post.content}"',
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isArabic ? 'تم نسخ المنشور للحافظة للمشاركة!' : 'Post copied to clipboard for sharing!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.share_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  label: Text(
                    isArabic ? 'مشاركة' : 'Share',
                    style: TextStyle(
                      fontSize: 13,
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

  String _formatTimeAgo(DateTime dt, [bool isArabic = false]) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return isArabic ? 'الآن' : 'Just now';
    if (diff.inMinutes < 60) return isArabic ? 'منذ ${diff.inMinutes} دقيقة' : '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return isArabic ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
    if (diff.inDays < 7) return isArabic ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy', isArabic ? 'ar' : 'en').format(dt);
  }
}

class _ComposerActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ComposerActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
