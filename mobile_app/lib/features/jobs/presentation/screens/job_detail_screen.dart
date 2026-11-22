import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../applications/presentation/providers/candidate_applications_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/job_posting.dart';
import '../providers/candidate_jobs_provider.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;
  final JobPosting? initialJob;

  const JobDetailScreen({
    super.key,
    required this.jobId,
    this.initialJob,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  JobPosting? _job;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _job = widget.initialJob;
    if (_job == null) {
      _loadJob();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        if (context.read<ProfileProvider>().profile == null) {
          context.read<ProfileProvider>().loadProfile(user.uid);
        }
        context.read<CandidateApplicationsProvider>().listenApplications(user.uid);
      }
      context
          .read<CandidateJobsProvider>()
          .recordJobViewed(widget.jobId, userId: user?.uid);
    });
  }

  Future<void> _loadJob() async {
    setState(() => _isLoading = true);
    final j =
        await context.read<CandidateJobsProvider>().getJobDetails(widget.jobId);
    if (mounted) {
      setState(() {
        _job = j;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApply(BuildContext context) async {
    final user = context.read<AuthProvider>().user;
    var profile = context.read<ProfileProvider>().profile;

    if (profile == null && user != null) {
      await context.read<ProfileProvider>().loadProfile(user.uid);
      if (!context.mounted) return;
      profile = context.read<ProfileProvider>().profile;
    }

    if (profile == null) {
      final profileErr = context.read<ProfileProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(profileErr ?? 'Could not load your profile. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final completion = profile.completionPercentage;

    if (completion < 70) {
      showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: Text(AppLocalizations.of(context)?.completeProfileTitle ?? 'Complete Your Profile'),
          content: Text(
            'Your profile completion is currently $completion%. Test2Hire requires at least 70% completion (including CV attachment and skills) before applying to vacancies.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text(AppLocalizations.of(context)?.later ?? 'Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dCtx);
                context.push('/profile');
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(AppLocalizations.of(context)?.goToProfile ?? 'Go to Profile',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final job = _job;
    if (job != null) {
      context.push('/apply/${job.id}', extra: job);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final authProvider = context.watch<AuthProvider>();
    final jobsProvider = context.watch<CandidateJobsProvider>();
    final candidateProfile = context.watch<ProfileProvider>().profile;
    final candidateSkills =
        candidateProfile?.skills.map((s) => s.toLowerCase()).toSet() ?? {};

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final job = _job;
    if (job == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.work_off_outlined, size: 48, color: AppColors.textTertiary),
                const SizedBox(height: 12),
                Text('Job listing not found.', style: AppTypography.headlineSmall),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadJob,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isOwner = authProvider.user?.uid == job.companyId;
    final isApplied =
        context.watch<CandidateApplicationsProvider>().isJobApplied(job.id);
    final isSaved = jobsProvider.isJobSaved(job.id);
    final deadline = (job.createdAt ?? DateTime.now()).add(const Duration(days: 30));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(job.companyName),
        actions: [
          IconButton(
            tooltip: isSaved ? 'Remove Bookmark' : 'Save Job',
            icon: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isSaved ? AppColors.primary : AppColors.textPrimary,
            ),
            onPressed: () {
              jobsProvider.toggleSaveJob(job.id, userId: authProvider.user?.uid);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isSaved ? 'Removed from Saved Jobs' : 'Saved to your Jobs list!',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Share Job',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      '${job.title} at ${job.companyName} (${job.location.formatted}) on Test2Hire',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Job details copied to clipboard!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('/company/jobs/${job.id}/edit', extra: job),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (job.salaryRange != null) ...[
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.salary ?? 'Salary Range',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        job.salaryRange!.formatted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],
              OutlinedButton(
                onPressed: () {
                  jobsProvider.toggleSaveJob(
                    job.id,
                    userId: authProvider.user?.uid,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Icon(
                  isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isSaved ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: isOwner
                    ? OutlinedButton(
                        onPressed: () => context.push(
                            '/company/jobs/${job.id}/edit',
                            extra: job),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Edit Listing'),
                      )
                    : isApplied
                        ? OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/candidate/applications'),
                            icon: const Icon(Icons.check_circle_outline,
                                color: AppColors.success),
                            label: const Text(
                              'Applied • Track Status',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.success),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          )
                        : AppButton(
                            text: l10n?.applyNow ?? 'Apply Now',
                            onPressed: () => _handleApply(context),
                          ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Clickable Company & Job Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (job.companyId.isNotEmpty) {
                          context.push('/company/${job.companyId}/careers');
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: (job.companyLogoUrl != null &&
                                job.companyLogoUrl!.trim().isNotEmpty)
                            ? AppSafeImage(
                                url: job.companyLogoUrl!,
                                width: 56,
                                height: 56,
                                borderRadius: BorderRadius.circular(12),
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Center(
                                  child: Text(
                                    job.companyName.trim().isNotEmpty
                                        ? job.companyName
                                            .trim()[0]
                                            .toUpperCase()
                                        : 'C',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  job.companyName.trim().isNotEmpty
                                      ? job.companyName.trim()[0].toUpperCase()
                                      : 'C',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(job.title, style: AppTypography.headlineMedium),
                          const SizedBox(height: 4),
                          Text(
                            '${job.companyName} • ${job.location.formatted}',
                            style: AppTypography.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Application Deadline: ${DateFormat('MMM d, yyyy').format(deadline)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (job.companyId.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => context.push('/company/${job.companyId}/careers'),
                    borderRadius: BorderRadius.circular(8),
                    child: const Row(
                      children: [
                        Icon(Icons.business_rounded,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'View Company Profile, Culture & All Open Jobs',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 13, color: AppColors.primary),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Specs Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSpecItem(
                    Icons.apartment, l10n?.workArrangement ?? 'Arrangement', job.workplaceType.localizedName(isArabic)),
                _buildSpecItem(
                    Icons.schedule, l10n?.employmentType ?? 'Employment', job.jobType.localizedName(isArabic)),
                _buildSpecItem(Icons.trending_up, l10n?.experienceLevel ?? 'Experience',
                    job.experienceLevel.localizedName(isArabic)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Required Skills with candidate match indication
          if (job.requiredSkills.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n?.skillsSectionTitle ?? 'Required Skills', style: AppTypography.headlineSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: job.requiredSkills.map((skill) {
                      final hasSkill =
                          candidateSkills.contains(skill.trim().toLowerCase());
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: hasSkill
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasSkill
                                ? AppColors.success.withValues(alpha: 0.4)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasSkill
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 14,
                              color: hasSkill
                                  ? AppColors.success
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              skill,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: hasSkill
                                    ? AppColors.success
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Job Description, Responsibilities, Requirements, Benefits
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n?.jobDescription ?? 'Job Description', style: AppTypography.headlineSmall),
                const SizedBox(height: 8),
                Text(job.description, style: AppTypography.bodyMedium),
                if (job.responsibilities.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(l10n?.responsibilities ?? 'Key Responsibilities', style: AppTypography.headlineSmall),
                  const SizedBox(height: 8),
                  ...job.responsibilities.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                            Expanded(
                                child: Text(r, style: AppTypography.bodyMedium)),
                          ],
                        ),
                      )),
                ],
                if (job.requirements.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(l10n?.keyRequirements ?? 'Requirements & Qualifications',
                      style: AppTypography.headlineSmall),
                  const SizedBox(height: 8),
                  ...job.requirements.map((req) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                            Expanded(
                                child:
                                    Text(req, style: AppTypography.bodyMedium)),
                          ],
                        ),
                      )),
                ],
                const SizedBox(height: 20),
                Text('Benefits & Hiring Process',
                    style: AppTypography.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  '• Structured skill-first evaluation via Test2Hire online assessments\n'
                  '• Direct interview scheduling with engineering & hiring managers\n'
                  '• Competitive compensation package & career growth path',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
