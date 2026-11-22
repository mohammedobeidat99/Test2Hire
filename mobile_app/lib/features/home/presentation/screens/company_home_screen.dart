import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/features/company/presentation/providers/company_provider.dart';
import 'package:mobile_app/features/company/presentation/widgets/verification_status_banner.dart';
import 'package:mobile_app/features/exams/presentation/providers/company_exams_provider.dart';
import 'package:mobile_app/features/interviews/presentation/providers/company_interviews_provider.dart';
import 'package:mobile_app/features/jobs/presentation/providers/company_jobs_provider.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';

class CompanyHomeScreen extends StatefulWidget {
  const CompanyHomeScreen({super.key});

  @override
  State<CompanyHomeScreen> createState() => _CompanyHomeScreenState();
}

class _CompanyHomeScreenState extends State<CompanyHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<CompanyProvider>().listenToCompany(uid);
        context.read<CompanyJobsProvider>().listenCompanyJobs(uid);
        context.read<CompanyExamsProvider>().listenCompanyExams(uid);
        context.read<CompanyInterviewsProvider>().listenCompanyInterviews(uid);
        context.read<NotificationsProvider>().listenToNotifications(uid);
      }
    });
  }

  Future<void> _handleRefresh() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    await Future.wait([
      context.read<CompanyProvider>().loadCompany(uid),
      context.read<CompanyJobsProvider>().loadCompanyJobs(uid),
      context.read<CompanyExamsProvider>().loadCompanyExams(uid),
      context.read<CompanyInterviewsProvider>().loadCompanyInterviews(uid),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final companyProvider = context.watch<CompanyProvider>();
    final jobsProvider = context.watch<CompanyJobsProvider>();
    final examsProvider = context.watch<CompanyExamsProvider>();
    final interviewsProvider = context.watch<CompanyInterviewsProvider>();
    final user = authProvider.user;
    final company = companyProvider.company;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employer Portal', style: AppTypography.bodySmall),
            Text(company?.name ?? user?.fullName ?? 'Company Admin', style: AppTypography.titleLarge),
          ],
        ),
        actions: [
          const NotificationBellButton(),
          IconButton(
            icon: const Icon(Icons.business_rounded),
            tooltip: 'Company Profile',
            onPressed: () => context.push('/company/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
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
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Live Status Banner
            if (company != null) ...[
              InkWell(
                onTap: () => context.push('/company/profile'),
                borderRadius: BorderRadius.circular(12),
                child: VerificationStatusBanner(company: company),
              ),
              const SizedBox(height: 24),
            ],

            Text('Recruitment Overview', style: AppTypography.headlineSmall),
            const SizedBox(height: 16),

            Row(
              children: [
                _CompanyStatCard(
                  title: 'Active Jobs',
                  count: '${jobsProvider.publishedJobsCount}',
                  icon: Icons.work_outline_rounded,
                  color: AppColors.primary,
                  onTap: () => context.push('/company/jobs'),
                ),
                const SizedBox(width: 12),
                _CompanyStatCard(
                  title: 'Applicants',
                  count: '${jobsProvider.totalApplicantsCount}',
                  icon: Icons.people_outline_rounded,
                  color: const Color(0xFF0EA5E9),
                  onTap: () => context.push('/company/jobs'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _CompanyStatCard(
                  title: 'Exam Templates',
                  count: '${examsProvider.totalExamsCount}',
                  icon: Icons.checklist_rounded,
                  color: AppColors.warning,
                  onTap: () => context.push('/company/exams'),
                ),
                const SizedBox(width: 12),
                _CompanyStatCard(
                  title: 'Scheduled Interviews',
                  count: '${interviewsProvider.pendingCount + interviewsProvider.confirmedCount}',
                  icon: Icons.event_available_rounded,
                  color: AppColors.success,
                  onTap: () => context.push('/company/interviews'),
                ),
              ],
            ),

            const SizedBox(height: 28),
            Text('Quick Management', style: AppTypography.headlineSmall),
            const SizedBox(height: 12),

            _ActionTile(
              icon: Icons.post_add_rounded,
              title: 'Post New Vacancy',
              subtitle: 'Define role requirements, skills, and compensation',
              onTap: () => context.push('/company/jobs/create'),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.work_outline_rounded,
              title: 'Manage Job Listings',
              subtitle: 'View applicants, edit vacancies, and toggle status',
              onTap: () => context.push('/company/jobs'),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.assignment_turned_in_rounded,
              title: 'Online Assessments & Assignments (الاختبارات والتعيينات)',
              subtitle: 'Create exam templates, AI auto-generate, and assign tests to candidates',
              onTap: () => context.push('/company/exams'),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.quiz_outlined,
              title: 'Question Bank & Assessments',
              subtitle: 'Build question pools, set difficulty, and author MCQs / coding tasks',
              onTap: () => context.push('/company/question-banks'),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.video_call_rounded,
              title: 'Candidate Interviews',
              subtitle: 'Manage upcoming video meetings, candidate RSVP, and submit evaluations',
              onTap: () => context.push('/company/interviews'),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.verified_rounded,
              title: 'Job Offers & Selections',
              subtitle: 'Track extended offers, review candidate acceptance, and manage packages',
              onTap: () => context.push('/company/offers'),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.code_rounded,
              title: 'Take-Home Project Challenges',
              subtitle: 'Design practical coding tasks, set deadlines, and grade GitHub submissions',
              onTap: () => context.push('/company/challenges/create'),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.campaign_rounded,
              title: 'Bulk Hiring Campaigns & Targets',
              subtitle: 'Launch high-volume hiring initiatives with batch pipelines and tracking',
              onTap: () => context.push('/company/campaigns'),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.person_search_rounded,
              title: 'Talent Pool Sourcing Directory',
              subtitle: 'Discover verified candidate profiles, filter by skills, and send invites',
              onTap: () => context.push('/company/talent-pool'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _CompanyStatCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CompanyStatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                count,
                style: AppTypography.displayMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
