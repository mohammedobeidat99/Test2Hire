import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/job_application.dart';
import '../../../exams/domain/entities/exam_template.dart';
import '../providers/candidate_applications_provider.dart';

class CandidateApplicationsScreen extends StatefulWidget {
  const CandidateApplicationsScreen({super.key});

  @override
  State<CandidateApplicationsScreen> createState() =>
      _CandidateApplicationsScreenState();
}

class _CandidateApplicationsScreenState
    extends State<CandidateApplicationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<CandidateApplicationsProvider>().listenApplications(user.uid);
      }
    });
  }

  void _handleWithdraw(BuildContext context, JobApplication app) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<CandidateApplicationsProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isArabic ? 'سحب طلب التوظيف؟' : 'Withdraw Application?'),
        content: Text(
          'Are you sure you want to withdraw your application for "${app.jobTitle}" at ${app.companyName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(isArabic ? 'إلغاء' : 'Keep Application'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirm Withdraw', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await provider.withdraw(app.id);
      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'تم سحب الطلب بنجاح.' : 'Application successfully withdrawn.'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to withdraw application.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appsProvider = context.watch<CandidateApplicationsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.myApplicationsTitle ?? 'My Applications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final user = context.read<AuthProvider>().user;
              if (user != null) {
                appsProvider.listenApplications(user.uid, force: true);
              }
            },
          ),
        ],
      ),
      body: appsProvider.isLoading && appsProvider.applications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : appsProvider.errorMessage != null && appsProvider.applications.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load applications',
                  description: appsProvider.errorMessage!,
                  actionLabel: 'Retry',
                  actionIcon: Icons.refresh_rounded,
                  onAction: () {
                    final user = context.read<AuthProvider>().user;
                    if (user != null) {
                      appsProvider.listenApplications(user.uid, force: true);
                    }
                  },
                )
              : appsProvider.applications.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.inbox_rounded,
                      title: l10n?.noApplicationsTitle ?? 'No Applications Yet',
                      description: 'You haven\'t applied to any job vacancies yet. Explore available jobs and submit your first application!',
                      actionLabel: l10n?.browseJobs ?? 'Explore Vacancies',
                      actionIcon: Icons.search_rounded,
                      onAction: () => context.push('/jobs'),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        final user = context.read<AuthProvider>().user;
                        if (user != null) {
                          await appsProvider.loadApplications(user.uid);
                        }
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: appsProvider.applications.length,
                        itemBuilder: (context, index) {
                          final app = appsProvider.applications[index];
                          return Padding(
                            key: ValueKey(app.id),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildApplicationCard(context, app),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildApplicationCard(BuildContext context, JobApplication app) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final companyLogo = app.companyLogoUrl;
    final rejectionReason = app.rejectionReason;
    final hasExam = app.hasExamAssigned;
    final examToken = app.examToken;
    final durationMinutes = app.examDurationMinutes;
    final appliedAt = app.appliedAt;
    final companyInitial = (app.companyName.trim().isNotEmpty)
        ? app.companyName.trim()[0].toUpperCase()
        : 'C';

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: (companyLogo != null && companyLogo.isNotEmpty)
                      ? AppSafeImage(
                          url: companyLogo,
                          width: 44,
                          height: 44,
                          borderRadius: BorderRadius.circular(10),
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Center(
                            child: Text(
                              companyInitial,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            companyInitial,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.jobTitle, style: AppTypography.headlineSmall),
                      const SizedBox(height: 2),
                      Text(app.companyName, style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                StatusBadge(status: app.status.toShortString()),
              ],
            ),
            const SizedBox(height: 12),

            // Rejection reason notice if present
            if (app.status == ApplicationStatus.rejected &&
                rejectionReason != null &&
                rejectionReason.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Feedback: $rejectionReason',
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),

            // Assessment Invitation Box if assigned
            if (hasExam) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.quiz_outlined, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            app.examTitle ?? 'Online Assessment Required',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (durationMinutes != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${durationMinutes}m',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (examToken != null && examToken.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        isArabic ? 'رمز الدخول لبوابة الاختبار الرسمية:' : 'Official Exam Access Key:',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                examToken,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.copy, size: 14),
                            label: Text(isArabic ? 'نسخ الرمز' : 'Copy Key', style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: examToken));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isArabic ? 'تم نسخ رمز الاختبار! الصقه في موقع الامتحان.' : 'Exam key copied! Paste it in the exam website.'),
                                    backgroundColor: AppColors.success,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.open_in_browser, size: 16),
                            label: Text(
                              isArabic ? 'الانتقال لبوابة الاختبار الرسمية' : 'Open Exam Portal',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              final urlStr = (examToken != null && examToken.isNotEmpty)
                                  ? '${ExamAttempt.webExamPortalUrl}/exam/$examToken'
                                  : ExamAttempt.webExamPortalUrl;
                              final uri = Uri.parse(urlStr);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Could not open $urlStr')),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Footer info and withdraw button
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    appliedAt != null
                        ? 'Applied on ${appliedAt.day}/${appliedAt.month}/${appliedAt.year}'
                        : (isArabic ? 'تم التقديم مؤخراً' : 'Applied recently'),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (app.canWithdraw)
                  TextButton(
                    onPressed: () => _handleWithdraw(context, app),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(isArabic ? 'سحب الطلب' : 'Withdraw', style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
