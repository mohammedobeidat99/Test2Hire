import '../../../../core/providers/locale_provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../applications/presentation/providers/candidate_applications_provider.dart';
import '../../../assessments/presentation/providers/assessments_hub_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../community/presentation/providers/community_provider.dart';
import '../../../exams/presentation/providers/candidate_exams_provider.dart';
import '../../../jobs/presentation/providers/candidate_jobs_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/cv_upload_card.dart';
import '../widgets/profile_completion_card.dart';

class ProfileScreen extends StatefulWidget {
  final bool embeddedInShell;

  const ProfileScreen({
    super.key,
    this.embeddedInShell = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<ProfileProvider>().loadProfile(uid);
        context.read<CandidateJobsProvider>().loadCandidateJobPreferences(uid);
      }
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    setState(() => _isUploadingPhoto = true);

    try {
      final sanitized = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos/$uid/${DateTime.now().millisecondsSinceEpoch}_$sanitized');

      final ext = file.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : ext == 'gif'
                  ? 'image/gif'
                  : 'image/jpeg';
      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: {'uploadedBy': uid},
      );

      Uint8List? fileBytes = file.bytes;
      if (!kIsWeb && fileBytes == null && file.path != null) {
        final f = File(file.path!);
        if (await f.exists()) {
          fileBytes = await f.readAsBytes();
        }
      }

      UploadTask task;
      if (fileBytes != null) {
        task = ref.putData(fileBytes, metadata);
      } else if (!kIsWeb && file.path != null) {
        task = ref.putFile(File(file.path!), metadata);
      } else {
        throw Exception('Could not read image file.');
      }

      final snap = await task;
      final downloadUrl = await snap.ref.getDownloadURL();
      if (!mounted) return;
      final profileProv = context.read<ProfileProvider>();
      final ok = await profileProv.updatePhotoUrl(downloadUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Profile picture updated!'
                : (profileProv.errorMessage ??
                    'Failed to update profile picture.'),
          ),
          backgroundColor: ok ? AppColors.success : AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo upload failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final jobsProvider = context.watch<CandidateJobsProvider>();
    final appsProvider = context.watch<CandidateApplicationsProvider>();
    final examsProvider = context.watch<CandidateExamsProvider>();
    final assessmentsProvider = context.watch<AssessmentsHubProvider>();
    final communityProvider = context.watch<CommunityProvider>();

    final profile = profileProvider.profile;
    final uid = authProvider.user?.uid ?? '';
    final myPosts = communityProvider.postsByAuthor(uid);

    if (profileProvider.isLoading && profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (profileProvider.errorMessage != null && profile == null && uid.isNotEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embeddedInShell,
          title: Text(l10n?.profileScreenTitle ?? 'Professional Profile'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  profileProvider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => profileProvider.loadProfile(uid),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embeddedInShell,
        title: Text(l10n?.profileScreenTitle ?? 'Professional Profile'),
        actions: [
          Consumer<LocaleProvider>(
            builder: (context, localeProv, _) {
              return TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: () => localeProv.toggleLocale(),
                icon: const Icon(Icons.language_rounded, size: 18),
                label: Text(
                  localeProv.isArabic ? 'English' : 'عربي',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Edit Personal Info',
            onPressed: () => context.push('/profile/edit-personal'),
          ),
          if (widget.embeddedInShell)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              tooltip: 'Sign Out',
              onPressed: () async {
                await authProvider.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (uid.isNotEmpty) {
            await context.read<ProfileProvider>().loadProfile(uid);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LinkedIn-style Cover + Avatar Header Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtle Cover Header
                    Container(
                      height: 76,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(17)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -28),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 3.5),
                                      ),
                                      child: Builder(
                                        builder: (context) {
                                          final avatarProvider =
                                              getSafeImageProvider(
                                                  profile?.photoUrl);
                                          return CircleAvatar(
                                            radius: 38,
                                            backgroundColor: AppColors.primary
                                                .withValues(alpha: 0.1),
                                            backgroundImage: avatarProvider,
                                            child: avatarProvider == null
                                                ? Text(
                                                    profile?.fullName.isNotEmpty ??
                                                            false
                                                        ? profile!.fullName[0]
                                                            .toUpperCase()
                                                        : 'U',
                                                    style: AppTypography
                                                        .displaySmall
                                                        .copyWith(
                                                            color: AppColors
                                                                .primary),
                                                  )
                                                : null,
                                          );
                                        },
                                      ),
                                    ),
                                    PositionedDirectional(
                                      end: 0,
                                      bottom: 0,
                                      child: InkWell(
                                        onTap: _isUploadingPhoto
                                            ? null
                                            : _pickAndUploadAvatar,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 2),
                                          ),
                                          child: _isUploadingPhoto
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.camera_alt_rounded,
                                                  size: 13,
                                                  color: Colors.white,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      context.push('/profile/edit-personal'),
                                  icon: const Icon(Icons.edit_outlined, size: 15),
                                  label: Text(l10n?.editProfile ?? 'Edit Profile',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            profile?.fullName ?? 'Candidate',
                            style: AppTypography.headlineSmall
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile?.headline ?? (l10n?.headlinePlaceholder ?? 'Add a professional headline...'),
                            style: AppTypography.bodyMedium.copyWith(
                              color: profile?.headline != null
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ),
                          ),
                          if (profile?.location != null &&
                              profile!.location!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(profile.location!,
                                    style: AppTypography.bodySmall),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Quick Access Hub: Saved Jobs, Applications, Assessments, Assignments
              Row(
                children: [
                  Expanded(
                    child: _QuickAccessTile(
                      label: l10n?.metricSavedJobs ?? 'Saved Jobs',
                      count: '${jobsProvider.savedJobIds.length}',
                      icon: Icons.bookmark_outline_rounded,
                      color: AppColors.primary,
                      onTap: () => context.push('/jobs'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAccessTile(
                      label: l10n?.metricApplications ?? 'Applications',
                      count: '${appsProvider.applications.length}',
                      icon: Icons.work_history_outlined,
                      color: AppColors.success,
                      onTap: () => context.push('/candidate/applications'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAccessTile(
                      label: l10n?.metricAssessments ?? 'Assessments',
                      count: '${examsProvider.attempts.length}',
                      icon: Icons.quiz_outlined,
                      color: AppColors.warning,
                      onTap: () => context.push('/candidate/exams'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAccessTile(
                      label: l10n?.metricAssignments ?? 'Assignments',
                      count: '${assessmentsProvider.candidateSubmissions.length}',
                      icon: Icons.assignment_turned_in_outlined,
                      color: AppColors.violet,
                      onTap: () => context.push('/candidate/exams'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Profile Completion Card
              if (profile != null) ...[
                ProfileCompletionCard(profile: profile),
                const SizedBox(height: 16),
              ],

              // CV Upload Card
              const CVUploadCard(),

              const SizedBox(height: 16),

              // About Summary Card
              _SectionContainer(
                title: l10n?.aboutMeTitle ?? 'About Me',
                onEdit: () => context.push('/profile/edit-personal'),
                child: Text(
                  profile?.about?.isNotEmpty ?? false
                      ? profile!.about!
                      : (l10n?.noAboutPrompt ?? 'No about summary added yet. Tap edit to write a summary of your skills and experience.'),
                  style: AppTypography.bodyMedium.copyWith(
                    color: profile?.about?.isNotEmpty ?? false
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Skills Card
              _SectionContainer(
                title: '${l10n?.skillsSectionTitle ?? "Skills"} (${profile?.skills.length ?? 0})',
                onEdit: () => context.push('/profile/manage-skills'),
                child: (profile?.skills.isNotEmpty ?? false)
                    ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile!.skills.map((skill) {
                          return Chip(
                            label: Text(skill,
                                style: AppTypography.bodySmall
                                    .copyWith(color: AppColors.primary)),
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.08),
                            side: const BorderSide(color: AppColors.primaryLight),
                          );
                        }).toList(),
                      )
                    : Text(
                        l10n?.noSkillsPrompt ?? 'No skills added yet. Add at least 3 skills to qualify for jobs.',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textTertiary),
                      ),
              ),

              const SizedBox(height: 16),

              // Experience Card
              _SectionContainer(
                title: '${l10n?.workExperienceTitle ?? "Work Experience"} (${profile?.experience.length ?? 0})',
                onEdit: () => context.push('/profile/edit-experience'),
                child: (profile?.experience.isNotEmpty ?? false)
                    ? Column(
                        children: profile!.experience.map((exp) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.business_center_outlined,
                                    size: 20, color: AppColors.accent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${exp.title} at ${exp.company}',
                                    style: AppTypography.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    : Text(
                        l10n?.noExperienceRecorded ?? 'No work experience recorded.',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textTertiary),
                      ),
              ),

              const SizedBox(height: 16),

              // Education Card
              _SectionContainer(
                title: '${l10n?.educationSectionTitle ?? "Education"} (${profile?.education.length ?? 0})',
                onEdit: () => context.push('/profile/edit-education'),
                child: (profile?.education.isNotEmpty ?? false)
                    ? Column(
                        children: profile!.education.map((edu) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.school_outlined,
                                    size: 20, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${edu.degree} in ${edu.fieldOfStudy} - ${edu.institution}',
                                    style: AppTypography.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    : Text(
                        l10n?.noEducationHistory ?? 'No education history added yet.',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textTertiary),
                      ),
              ),

              const SizedBox(height: 16),

              // Certifications & Languages Card
              _SectionContainer(
                title: l10n?.certificationsAndLanguages ?? 'Certifications & Languages',
                onEdit: () => context.push('/profile/edit-certifications'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.certificationsCount(profile?.certifications.length ?? 0) ?? 'Certifications: ${profile?.certifications.length ?? 0}',
                      style: AppTypography.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n?.languagesList((profile?.languages.isNotEmpty ?? false) ? profile!.languages.map((l) => l.language).join(', ') : (l10n.none)) ?? 'Languages',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Community Activity Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n?.communityActivityTitle ?? "Community Activity"} (${myPosts.length})',
                      style: AppTypography.titleLarge
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (myPosts.isEmpty)
                      Text(
                        l10n?.noCommunityPostsYet ?? 'You have not published any community posts yet.',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textTertiary),
                      )
                    else
                      ...myPosts.take(3).map((post) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${l10n?.likesCount(post.likesCount) ?? "${post.likesCount} likes"} • ${l10n?.commentsCount(post.commentsCount) ?? "${post.commentsCount} comments"}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final String label;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
//     final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              count,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  final String title;
  final VoidCallback onEdit;
  final Widget child;

  const _SectionContainer({
    required this.title,
    required this.onEdit,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
//     final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style:
                      AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.primary),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
