import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/url_launcher_helper.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../applications/domain/entities/job_application.dart';
import '../../../applications/presentation/providers/candidate_applications_provider.dart';
import '../../../assessments/presentation/providers/assessments_hub_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../community/domain/entities/community_post.dart';
import '../../../community/presentation/providers/community_provider.dart';
import '../../../community/presentation/screens/community_feed_screen.dart';
import '../../../community/presentation/widgets/community_post_card.dart';
import '../../../exams/domain/entities/exam_template.dart';
import '../../../exams/presentation/providers/candidate_exams_provider.dart';
import '../../../exams/presentation/screens/candidate_exams_screen.dart';
import '../../../interviews/domain/entities/interview.dart';
import '../../../interviews/presentation/providers/candidate_interviews_provider.dart';
import '../../../jobs/domain/entities/job_posting.dart';
import '../../../jobs/presentation/providers/candidate_jobs_provider.dart';
import '../../../jobs/presentation/screens/candidate_job_feed_screen.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../../../offers/domain/entities/job_offer.dart';
import '../../../offers/presentation/providers/candidate_offers_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

/// Modern, professional Candidate Home Screen inspired by leading recruitment platforms (LinkedIn, Indeed).
/// Fully localized with dynamic translations between English and Arabic.
class CandidateHomeScreen extends StatefulWidget {
  const CandidateHomeScreen({super.key});

  @override
  State<CandidateHomeScreen> createState() => _CandidateHomeScreenState();
}

class _CandidateHomeScreenState extends State<CandidateHomeScreen>
    with WidgetsBindingObserver {
  int _selectedNavIndex = 0;
  int _selectedFeedFilter = 0; // 0: All Feed, 1: Discussions, 2: Jobs for You
  String? _initializedUid;
  bool _didInitialLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initCandidateData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<AuthProvider>().user?.uid;
    if (_didInitialLoad && uid != _initializedUid) {
      _initializedUid = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initCandidateData();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context
            .read<CandidateExamsProvider>()
            .loadCandidateAttempts(uid, isBackground: true);
        context
            .read<CandidateApplicationsProvider>()
            .loadApplications(uid, isBackground: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initCandidateData() {
    _didInitialLoad = true;
    final uid = context.read<AuthProvider>().user?.uid;
    _initializedUid = uid;
    context.read<CandidateJobsProvider>().listenJobs();
    context.read<CommunityProvider>().listenFeed();
    context.read<AssessmentsHubProvider>().listenAvailableChallenges();
    if (uid != null) {
      context.read<CandidateJobsProvider>().loadCandidateJobPreferences(uid);
      context.read<CandidateApplicationsProvider>().listenApplications(uid);
      context.read<CandidateExamsProvider>().listenCandidateAttempts(uid);
      context.read<AssessmentsHubProvider>().listenCandidateSubmissions(uid);
      context.read<CandidateInterviewsProvider>().listenCandidateInterviews(uid);
      context.read<CandidateOffersProvider>().listenCandidateOffers(uid);
      context.read<NotificationsProvider>().listenToNotifications(uid);
      context.read<ProfileProvider>().loadProfile(uid);
    } else {
      context.read<CandidateApplicationsProvider>().reset();
      context.read<CandidateExamsProvider>().reset();
      context.read<AssessmentsHubProvider>().reset();
      context.read<CandidateInterviewsProvider>().reset();
      context.read<CandidateOffersProvider>().reset();
      context.read<NotificationsProvider>().reset();
      context.read<ProfileProvider>().reset();
    }
  }

  Future<void> _handleRefresh() async {
    final uid = context.read<AuthProvider>().user?.uid;
    final jobsProvider = context.read<CandidateJobsProvider>();
    final communityProvider = context.read<CommunityProvider>();
    final assessmentsProvider = context.read<AssessmentsHubProvider>();
    final appsProvider = context.read<CandidateApplicationsProvider>();
    final examsProvider = context.read<CandidateExamsProvider>();
    final interviewsProvider = context.read<CandidateInterviewsProvider>();
    final offersProvider = context.read<CandidateOffersProvider>();
    final notifProvider = context.read<NotificationsProvider>();
    final profileProvider = context.read<ProfileProvider>();

    jobsProvider.listenJobs(force: true);
    assessmentsProvider.listenAvailableChallenges();
    if (uid != null) {
      appsProvider.listenApplications(uid, force: true);
      examsProvider.listenCandidateAttempts(uid);
      assessmentsProvider.listenCandidateSubmissions(uid);
      interviewsProvider.listenCandidateInterviews(uid);
      offersProvider.listenCandidateOffers(uid);
      notifProvider.listenToNotifications(uid, force: true);
      await profileProvider.loadProfile(uid);
    }
    await communityProvider.refreshFeed();
  }

  void _setTab(int index) {
    if (_selectedNavIndex == index) return;
    setState(() => _selectedNavIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final examsProvider = context.watch<CandidateExamsProvider>();
    final appsProvider = context.watch<CandidateApplicationsProvider>();

    JobApplication? examApp;
    for (final app in appsProvider.applications) {
      if (app.status == ApplicationStatus.examAssigned &&
          (app.examToken?.isNotEmpty ?? false)) {
        examApp = app;
        break;
      }
    }

    final pendingAssessmentsCount = examsProvider.pendingCount > 0
        ? examsProvider.pendingCount
        : (examApp != null ? 1 : 0);

    return PopScope(
      canPop: _selectedNavIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedNavIndex != 0) {
          setState(() => _selectedNavIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _selectedNavIndex,
          children: [
            _buildHomeDashboardTab(context),
            const CandidateJobFeedScreen(embeddedInShell: true),
            const CommunityFeedScreen(embeddedInShell: true),
            const CandidateExamsScreen(embeddedInShell: true),
            const ProfileScreen(embeddedInShell: true),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _selectedNavIndex,
              onDestinationSelected: _setTab,
              backgroundColor: Colors.white,
              elevation: 0,
              height: 66,
              indicatorColor: AppColors.primarySubtle,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon:
                      const Icon(Icons.home_rounded, color: AppColors.primary),
                  label: l10n?.navHome ?? 'Home',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.work_outline_rounded),
                  selectedIcon:
                      const Icon(Icons.work_rounded, color: AppColors.primary),
                  label: l10n?.navJobs ?? 'Jobs',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.groups_outlined),
                  selectedIcon:
                      const Icon(Icons.groups_rounded, color: AppColors.primary),
                  label: l10n?.navCommunity ?? 'Community',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: pendingAssessmentsCount > 0,
                    label: Text('$pendingAssessmentsCount'),
                    child: const Icon(Icons.quiz_outlined),
                  ),
                  selectedIcon:
                      const Icon(Icons.quiz_rounded, color: AppColors.primary),
                  label: l10n?.navAssessments ?? 'Assessments',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon:
                      const Icon(Icons.person_rounded, color: AppColors.primary),
                  label: l10n?.navProfile ?? 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeDashboardTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final jobsProvider = context.watch<CandidateJobsProvider>();
    final appsProvider = context.watch<CandidateApplicationsProvider>();
    final examsProvider = context.watch<CandidateExamsProvider>();
    final communityProvider = context.watch<CommunityProvider>();
    final interviewsProvider = context.watch<CandidateInterviewsProvider>();
    final offersProvider = context.watch<CandidateOffersProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;

    final displayName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : (user?.fullName ?? 'Candidate');
    final candidateSkills = profile?.skills ?? [];

    // Active priority alerts
    Interview? pendingInterview;
    for (final item in interviewsProvider.interviews) {
      if (item.isPendingCandidate) {
        pendingInterview = item;
        break;
      }
    }

    JobOffer? pendingOffer;
    for (final item in offersProvider.offers) {
      if (item.isPending) {
        pendingOffer = item;
        break;
      }
    }

    ExamAttempt? pendingExamAttempt;
    for (final att in examsProvider.attempts) {
      if (att.isPending) {
        pendingExamAttempt = att;
        break;
      }
    }

    final recommendedJobs =
        jobsProvider.recommendedJobs(candidateSkills).take(6).toList();
    final allPosts = communityProvider.allPosts;

    // Extract unique featured companies from open jobs
    final Map<String, JobPosting> companiesMap = {};
    for (final job in jobsProvider.jobs) {
      final key = job.companyId.isNotEmpty ? job.companyId : job.companyName;
      if (!companiesMap.containsKey(key)) {
        companiesMap[key] = job;
      }
    }
    final featuredCompanies = companiesMap.values.take(8).toList();

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 1. Sleek Top Header (LinkedIn style)
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // User Avatar (Tap to Profile)
                      GestureDetector(
                        onTap: () => _setTab(4),
                        child: Builder(
                          builder: (context) {
                            final avatarImg = getSafeImageProvider(profile?.photoUrl);
                            return CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primarySubtle,
                              backgroundImage: avatarImg,
                              child: avatarImg == null
                                  ? Text(
                                      displayName.isNotEmpty
                                          ? displayName.trim()[0].toUpperCase()
                                          : 'C',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Clean Search Pill
                      Expanded(
                        child: InkWell(
                          onTap: () => _setTab(1),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded,
                                    color: AppColors.textSecondary, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n?.searchJobsHint ??
                                        'Search jobs, companies, posts...',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.tune_rounded,
                                    color: AppColors.primary, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Language Switcher Button (with text label for clarity)
                      Consumer<LocaleProvider>(
                        builder: (context, localeProv, _) {
                          return TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              backgroundColor: AppColors.background,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: AppColors.border)),
                            ),
                            icon: const Icon(Icons.language_rounded,
                                color: AppColors.primary, size: 16),
                            label: Text(
                              localeProv.isArabic ? 'English' : 'عربي',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppColors.primary),
                            ),
                            onPressed: () => localeProv.toggleLocale(),
                          );
                        },
                      ),

                      // Notification Bell
                      const NotificationBellButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Dashboard Feed Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Career Pipeline Snapshot (Unified Modern 4-Column Card)
                _buildCareerPulseCard(
                  context,
                  appliedCount: appsProvider.applications.length,
                  assessmentsCount: examsProvider.pendingCount,
                  interviewsCount: interviewsProvider.interviews.length,
                  offersCount: offersProvider.offers.length,
                  l10n: l10n,
                ),
                const SizedBox(height: 14),

                // Priority Action Banners (High-contrast, actionable, non-cluttering)
                if (pendingOffer != null) ...[
                  _buildPriorityOfferCard(context, pendingOffer, l10n: l10n),
                  const SizedBox(height: 12),
                ],
                if (pendingExamAttempt != null) ...[
                  _buildPriorityExamCard(context, pendingExamAttempt, l10n: l10n),
                  const SizedBox(height: 12),
                ],
                if (pendingInterview != null) ...[
                  _buildPriorityInterviewCard(context, pendingInterview, l10n: l10n),
                  const SizedBox(height: 12),
                ],

                // "Start a Post" Composer Strip (LinkedIn style)
                _buildPostComposerStrip(
                  context,
                  profilePhotoUrl: profile?.photoUrl,
                  displayName: displayName,
                  l10n: l10n,
                ),
                const SizedBox(height: 16),

                // Featured Companies Carousel (Clean & Spacious)
                if (featuredCompanies.isNotEmpty) ...[
                  _buildFeaturedCompaniesCarousel(context, featuredCompanies, l10n: l10n),
                  const SizedBox(height: 16),
                ],

                // Feed Section Header & Filter Pills
                _buildFeedFilterBar(l10n),
                const SizedBox(height: 14),

                // Interactive Dynamic Feed Items
                ..._buildFeedContent(
                  context,
                  allPosts: allPosts,
                  recommendedJobs: recommendedJobs,
                  candidateSkills: candidateSkills,
                  userId: user?.uid,
                  jobsProvider: jobsProvider,
                  l10n: l10n,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Unified, clean 4-metric Career Snapshot card
  Widget _buildCareerPulseCard(
    BuildContext context, {
    required int appliedCount,
    required int assessmentsCount,
    required int interviewsCount,
    required int offersCount,
    AppLocalizations? l10n,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPulseItem(
            context,
            icon: Icons.assignment_turned_in_outlined,
            count: appliedCount,
            label: l10n?.applied ?? 'Applied',
            color: AppColors.primary,
            onTap: () => context.push(AppRoutes.candidateApplications),
          ),
          _buildVerticalDivider(),
          _buildPulseItem(
            context,
            icon: Icons.quiz_outlined,
            count: assessmentsCount,
            label: l10n?.assessments ?? 'Assessments',
            color: assessmentsCount > 0 ? AppColors.warning : AppColors.textSecondary,
            highlight: assessmentsCount > 0,
            onTap: () => _setTab(3),
          ),
          _buildVerticalDivider(),
          _buildPulseItem(
            context,
            icon: Icons.videocam_outlined,
            count: interviewsCount,
            label: l10n?.interviews ?? 'Interviews',
            color: interviewsCount > 0 ? AppColors.success : AppColors.textSecondary,
            onTap: () => context.push(AppRoutes.candidateInterviews),
          ),
          _buildVerticalDivider(),
          _buildPulseItem(
            context,
            icon: Icons.workspace_premium_outlined,
            count: offersCount,
            label: l10n?.offers ?? 'Offers',
            color: offersCount > 0 ? AppColors.violet : AppColors.textSecondary,
            highlight: offersCount > 0,
            onTap: () => context.push(AppRoutes.candidateOffers),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.border,
    );
  }

  Widget _buildPulseItem(
    BuildContext context, {
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: highlight ? color : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Priority Action Card: Assigned Official Examination
  Widget _buildPriorityExamCard(
    BuildContext context,
    ExamAttempt attempt, {
    AppLocalizations? l10n,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment_late_rounded,
                color: Color(0xFFD97706), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.examAssigned ?? 'EXAMINATION ASSIGNED',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB45309),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  attempt.examTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${attempt.durationMinutes} mins • ${l10n?.officialExamPortal ?? "Official Exam Portal"}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              await UrlLauncherHelper.openUrl(
                context,
                attempt.assessmentUrl,
                successMessage: 'Opening Official Examination Portal...',
              );
            },
            child: Text(
              l10n?.startExam ?? 'Start',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Priority Action Card: Pending Job Offer
  Widget _buildPriorityOfferCard(
    BuildContext context,
    JobOffer offer, {
    AppLocalizations? l10n,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Color(0xFF059669), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.offerReceived ?? 'OFFICIAL OFFER RECEIVED',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF047857),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${offer.jobTitle} • ${offer.companyName}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  offer.formattedSalary,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => context.push(AppRoutes.candidateOffers),
            child: Text(
              l10n?.reviewOffer ?? 'Review',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Priority Action Card: Scheduled Interview
  Widget _buildPriorityInterviewCard(
    BuildContext context,
    Interview interview, {
    AppLocalizations? l10n,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_available_rounded,
                color: Color(0xFF7C3AED), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.interviewInvitation ?? 'INTERVIEW INVITATION',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6D28D9),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${interview.jobTitle} • ${interview.companyName}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5B21B6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n?.actionRequiredSlot ?? 'Action required: Select time slot',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF6D28D9)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => context.push(AppRoutes.candidateInterviews),
            child: Text(
              l10n?.selectSlot ?? 'Select Slot',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// LinkedIn-style "Start a Post" Composer Strip
  Widget _buildPostComposerStrip(
    BuildContext context, {
    String? profilePhotoUrl,
    required String displayName,
    AppLocalizations? l10n,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Builder(
                builder: (context) {
                  final avatarImg = getSafeImageProvider(profilePhotoUrl);
                  return CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.primarySubtle,
                    backgroundImage: avatarImg,
                    child: avatarImg == null
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName.trim()[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          )
                        : null,
                  );
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => showCreateOrEditPostModal(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      l10n?.shareUpdateHint ??
                          'Share an update, insight, or advice...',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPostActionButton(
                icon: Icons.add_photo_alternate_outlined,
                label: l10n?.photoAction ?? 'Photo',
                color: AppColors.success,
                onTap: () => showCreateOrEditPostModal(context),
              ),
              _buildPostActionButton(
                icon: Icons.lightbulb_outline_rounded,
                label: l10n?.insightAction ?? 'Insight',
                color: AppColors.warning,
                onTap: () => showCreateOrEditPostModal(context),
              ),
              _buildPostActionButton(
                icon: Icons.help_outline_rounded,
                label: l10n?.questionAction ?? 'Question',
                color: AppColors.primary,
                onTap: () => showCreateOrEditPostModal(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
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

  /// Featured Companies Horizontal Carousel
  Widget _buildFeaturedCompaniesCarousel(
    BuildContext context,
    List<JobPosting> companies, {
    AppLocalizations? l10n,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n?.topCompaniesHiring ?? 'Top Companies Hiring',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            InkWell(
              onTap: () => _setTab(1),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      l10n?.explore ?? 'Explore',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: companies.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, idx) {
              final job = companies[idx];
              return InkWell(
                onTap: () {
                  if (job.companyId.isNotEmpty) {
                    context.push('/company/${job.companyId}/careers');
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                              final logoImg = getSafeImageProvider(job.companyLogoUrl);
                              return Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySubtle,
                                  borderRadius: BorderRadius.circular(8),
                                  image: logoImg != null
                                      ? DecorationImage(image: logoImg, fit: BoxFit.cover)
                                      : null,
                                ),
                                child: logoImg == null
                                    ? Center(
                                        child: Text(
                                          job.companyName.isNotEmpty
                                              ? job.companyName[0].toUpperCase()
                                              : 'C',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      )
                                    : null,
                              );
                            },
                          ),
                          const Spacer(),
                          const Icon(Icons.business_rounded,
                              size: 14, color: AppColors.textTertiary),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        job.companyName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.location.formatted,
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
              );
            },
          ),
        ),
      ],
    );
  }

  /// Segmented Filter Pills for the Feed (Horizontally scrollable to prevent overflow)
  Widget _buildFeedFilterBar(AppLocalizations? l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip(0, l10n?.allFeed ?? '🌟 All Feed'),
          const SizedBox(width: 8),
          _buildFilterChip(1, l10n?.discussionsFeed ?? '💬 Discussions'),
          const SizedBox(width: 8),
          _buildFilterChip(2, l10n?.recommendedJobsFeed ?? '💼 Recommended Jobs'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFeedFilter == index;
    return InkWell(
      onTap: () => setState(() => _selectedFeedFilter = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  /// Dynamic Feed Content generator
  List<Widget> _buildFeedContent(
    BuildContext context, {
    required List<CommunityPost> allPosts,
    required List<JobPosting> recommendedJobs,
    required List<String> candidateSkills,
    required String? userId,
    required CandidateJobsProvider jobsProvider,
    AppLocalizations? l10n,
  }) {
    // Mode 1: Discussions Only
    if (_selectedFeedFilter == 1) {
      if (allPosts.isEmpty) {
        return [
          _buildEmptyFeedCard(
            icon: Icons.forum_outlined,
            message: l10n?.noCommentsYet ?? 'No community discussions yet. Be the first to share an insight!',
            actionLabel: l10n?.createPostTitle ?? 'Create Post',
            onAction: () => showCreateOrEditPostModal(context),
          ),
        ];
      }
      return allPosts
          .map((post) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CommunityPostCard(post: post),
              ))
          .toList();
    }

    final spotlightMatchMap =
        jobsProvider.computeSkillMatches(recommendedJobs, candidateSkills);

    // Mode 2: Recommended Jobs Only
    if (_selectedFeedFilter == 2) {
      if (recommendedJobs.isEmpty) {
        return [
          _buildEmptyFeedCard(
            icon: Icons.work_outline_rounded,
            message: l10n?.noMatchingJobsTitle ?? 'No published jobs matching your criteria yet.',
            actionLabel: l10n?.browseJobs ?? 'Browse All Jobs',
            onAction: () => _setTab(1),
          ),
        ];
      }
      return recommendedJobs.map((job) {
        final match = spotlightMatchMap[job.id] ?? 100;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildJobSpotlightCard(
            context,
            job,
            matchPercent: match,
            userId: userId,
            l10n: l10n,
          ),
        );
      }).toList();
    }

    // Mode 0: All Feed (Blended stream of posts & spotlight jobs)
    final List<Widget> feedWidgets = [];
    final int maxItems = allPosts.length + recommendedJobs.length;

    if (maxItems == 0) {
      return [
        _buildEmptyFeedCard(
          icon: Icons.dynamic_feed_rounded,
          message: l10n?.welcomeFeedMessage ?? 'Welcome to Test2Hire! Community posts and jobs will appear here.',
          actionLabel: l10n?.browseJobs ?? 'Explore Jobs',
          onAction: () => _setTab(1),
        ),
      ];
    }

    int postIdx = 0;
    int jobIdx = 0;

    while (postIdx < allPosts.length || jobIdx < recommendedJobs.length) {
      // Add up to 2 posts
      for (int i = 0; i < 2 && postIdx < allPosts.length; i++) {
        feedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CommunityPostCard(post: allPosts[postIdx]),
          ),
        );
        postIdx++;
      }

      // Interleave 1 recommended job spotlight
      if (jobIdx < recommendedJobs.length) {
        final job = recommendedJobs[jobIdx];
        final match = spotlightMatchMap[job.id] ?? 100;
        feedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildJobSpotlightCard(
              context,
              job,
              matchPercent: match,
              userId: userId,
              l10n: l10n,
            ),
          ),
        );
        jobIdx++;
      }
    }

    return feedWidgets;
  }

  /// Modern, spacious in-feed Job Spotlight Card
  Widget _buildJobSpotlightCard(
    BuildContext context,
    JobPosting job, {
    int? matchPercent,
    String? userId,
    AppLocalizations? l10n,
  }) {
    final jobsProvider = context.read<CandidateJobsProvider>();
    final isSaved = jobsProvider.isJobSaved(job.id);

    return InkWell(
      onTap: () {
        jobsProvider.recordJobViewed(job.id, userId: userId);
        context.push('/jobs/${job.id}', extra: job);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Company Avatar + Job Title + Bookmark
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (job.companyId.isNotEmpty) {
                      context.push('/company/${job.companyId}/careers');
                    }
                  },
                  child: Builder(
                    builder: (context) {
                      final logoImg = getSafeImageProvider(job.companyLogoUrl);
                      return Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(10),
                          image: logoImg != null
                              ? DecorationImage(image: logoImg, fit: BoxFit.cover)
                              : null,
                        ),
                        child: logoImg == null
                            ? Center(
                                child: Text(
                                  job.companyName.isNotEmpty
                                      ? job.companyName[0].toUpperCase()
                                      : 'C',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${job.companyName} • ${job.location.formatted}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    size: 22,
                    color: isSaved ? AppColors.primary : AppColors.textTertiary,
                  ),
                  onPressed: () {
                    jobsProvider.toggleSaveJob(job.id, userId: userId);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Chips Row: Workplace Type, Salary, Skill Match
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    job.workplaceType.localizedName(Localizations.localeOf(context).languageCode == 'ar'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (job.salaryRange != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      job.salaryRange!.formatted,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                if (matchPercent != null && matchPercent > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: AppColors.successSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      '$matchPercent% ${l10n?.skillMatch ?? "Skill Match"}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),

            // Bottom CTA row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n?.sponsoredJob ?? 'Sponsored Job Recommendation',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    jobsProvider.recordJobViewed(job.id, userId: userId);
                    context.push('/jobs/${job.id}', extra: job);
                  },
                  child: Row(
                    children: [
                      Text(
                        l10n?.viewJob ?? 'View Job',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_rounded, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFeedCard({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textTertiary.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onAction,
            child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
