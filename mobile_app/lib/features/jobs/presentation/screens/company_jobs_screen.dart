import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../company/presentation/providers/company_provider.dart';
import '../../domain/entities/job_posting.dart';
import '../providers/company_jobs_provider.dart';

class CompanyJobsScreen extends StatefulWidget {
  const CompanyJobsScreen({super.key});

  @override
  State<CompanyJobsScreen> createState() => _CompanyJobsScreenState();
}

class _CompanyJobsScreenState extends State<CompanyJobsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<CompanyJobsProvider>().listenCompanyJobs(user.uid);
      }
    });
  }

  void _showStatusBottomSheet(BuildContext context, JobPosting job) {
    final provider = context.read<CompanyJobsProvider>();
    final companyProvider = context.read<CompanyProvider>();
    final isCompanyApproved = companyProvider.isApproved;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage: ${job.title}',
                  style: AppTypography.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                if (!job.isPublished)
                  ListTile(
                    leading: const Icon(Icons.public, color: AppColors.success),
                    title: const Text('Publish Vacancy'),
                    subtitle: isCompanyApproved
                        ? const Text('Make this vacancy visible to candidates')
                        : const Text('Requires company account approval',
                            style: TextStyle(color: AppColors.error)),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      if (!isCompanyApproved) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Cannot publish jobs: Company account must be approved by admin.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      final ok = await provider.changeStatus(job.id, JobStatus.published);
                      if (!ok) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(provider.errorMessage ?? 'Failed to publish vacancy.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                  ),
                if (job.isPublished)
                  ListTile(
                    leading: const Icon(Icons.pause_circle_outline, color: AppColors.warning),
                    title: const Text('Close Vacancy'),
                    subtitle: const Text('Stop receiving new applications'),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final ok = await provider.changeStatus(job.id, JobStatus.closed);
                      if (!ok) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(provider.errorMessage ?? 'Failed to close vacancy.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                  ),
                if (!job.isDraft)
                  ListTile(
                    leading: const Icon(Icons.edit_note, color: AppColors.textSecondary),
                    title: const Text('Revert to Draft'),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final ok = await provider.changeStatus(job.id, JobStatus.draft);
                      if (!ok) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(provider.errorMessage ?? 'Failed to update job status.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.people_alt_outlined, color: AppColors.primary),
                  title: const Text('View Applicants', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${job.applicantsCount} candidate(s) applied'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/company/jobs/${job.id}/applicants', extra: job.title);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  title: const Text('Edit Job Details'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/company/jobs/${job.id}/edit', extra: job);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.error),
                  title: const Text('Delete Job', style: TextStyle(color: AppColors.error)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Delete Vacancy?'),
                        content: Text('Are you sure you want to delete "${job.title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, true),
                            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final ok = await provider.deleteJob(job.id);
                      if (!ok && mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(provider.errorMessage ?? 'Failed to delete job vacancy.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobsProvider = context.watch<CompanyJobsProvider>();
    final companyProvider = context.watch<CompanyProvider>();
    final isApproved = companyProvider.isApproved;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Vacancies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final user = context.read<AuthProvider>().user;
              if (user != null) {
                jobsProvider.listenCompanyJobs(user.uid);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Post Vacancy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          context.push('/company/jobs/create');
        },
      ),
      body: jobsProvider.isLoading && jobsProvider.allJobs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Metrics overview banner
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildMetricChip('Total', '${jobsProvider.totalJobsCount}', AppColors.primary),
                      const SizedBox(width: 8),
                      _buildMetricChip('Published', '${jobsProvider.publishedJobsCount}', AppColors.success),
                      const SizedBox(width: 8),
                      _buildMetricChip('Drafts', '${jobsProvider.draftJobsCount}', AppColors.warning),
                      const SizedBox(width: 8),
                      _buildMetricChip('Applicants', '${jobsProvider.totalApplicantsCount}', AppColors.accent),
                    ],
                  ),
                ),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Jobs'),
                        selected: jobsProvider.statusFilter == null,
                        onSelected: (_) => jobsProvider.setStatusFilter(null),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Published'),
                        selected: jobsProvider.statusFilter == JobStatus.published,
                        onSelected: (_) => jobsProvider.setStatusFilter(JobStatus.published),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Drafts'),
                        selected: jobsProvider.statusFilter == JobStatus.draft,
                        onSelected: (_) => jobsProvider.setStatusFilter(JobStatus.draft),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Closed'),
                        selected: jobsProvider.statusFilter == JobStatus.closed,
                        onSelected: (_) => jobsProvider.setStatusFilter(JobStatus.closed),
                      ),
                    ],
                  ),
                ),

                if (!isApproved)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20, color: AppColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Account pending verification. You can create draft jobs, but publishing requires administrator approval.',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Job list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      final user = context.read<AuthProvider>().user;
                      if (user != null) {
                        await jobsProvider.loadCompanyJobs(user.uid);
                      }
                    },
                    child: jobsProvider.errorMessage != null && jobsProvider.allJobs.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.error_outline_rounded,
                            title: 'Failed to load vacancies',
                            description: jobsProvider.errorMessage!,
                            actionLabel: 'Retry',
                            actionIcon: Icons.refresh_rounded,
                            onAction: () {
                              final user = context.read<AuthProvider>().user;
                              if (user != null) {
                                jobsProvider.loadCompanyJobs(user.uid);
                              }
                            },
                          )
                        : jobsProvider.jobs.isEmpty
                            ? EmptyStateWidget(
                                icon: Icons.work_outline_rounded,
                                title: 'No Job Postings Found',
                                description: jobsProvider.statusFilter == null
                                    ? 'Get started by creating and publishing your first vacancy to attract top talent.'
                                    : 'No listings match the selected status filter.',
                                actionLabel: jobsProvider.statusFilter == null ? 'Post New Vacancy' : 'Show All Jobs',
                                actionIcon: jobsProvider.statusFilter == null ? Icons.add_rounded : Icons.clear_all_rounded,
                                onAction: () {
                                  if (jobsProvider.statusFilter == null) {
                                    context.push('/company/jobs/create');
                                  } else {
                                    jobsProvider.setStatusFilter(null);
                                  }
                                },
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                                itemCount: jobsProvider.jobs.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final job = jobsProvider.jobs[index];
                                  return _buildJobCard(context, job);
                                },
                              ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, JobPosting job) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.title, style: AppTypography.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        '${job.location.formatted} • ${job.workplaceType.displayName} • ${job.jobType.displayName}',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: job.status.toShortString()),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () => _showStatusBottomSheet(context, job),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                InkWell(
                  onTap: () => context.push('/company/jobs/${job.id}/applicants', extra: job.title),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${job.applicantsCount} Applicants',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (job.salaryRange != null)
                  Text(
                    job.salaryRange!.formatted,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
