import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/services/url_launcher_helper.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../applications/domain/entities/job_application.dart';
import '../../../applications/presentation/providers/candidate_applications_provider.dart';
import '../../../assessments/domain/entities/take_home_challenge.dart';
import '../../../assessments/presentation/providers/assessments_hub_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/exam_template_model.dart';
import '../../domain/entities/exam_template.dart';
import '../providers/candidate_exams_provider.dart';

class CandidateExamsScreen extends StatefulWidget {
  final bool embeddedInShell;
  final int initialTabIndex;

  const CandidateExamsScreen({
    super.key,
    this.embeddedInShell = false,
    this.initialTabIndex = 0,
  });

  @override
  State<CandidateExamsScreen> createState() => _CandidateExamsScreenState();
}

class _CandidateExamsScreenState extends State<CandidateExamsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  final TextEditingController _accessCodeController = TextEditingController();
  bool _isValidatingCode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<CandidateExamsProvider>().listenCandidateAttempts(user.uid);
        context.read<CandidateApplicationsProvider>().listenApplications(user.uid);
        final assessmentsHub = context.read<AssessmentsHubProvider>();
        assessmentsHub.listenAvailableChallenges();
        assessmentsHub.listenCandidateSubmissions(user.uid);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context
            .read<CandidateExamsProvider>()
            .loadCandidateAttempts(user.uid, isBackground: true);
        context
            .read<CandidateApplicationsProvider>()
            .loadApplications(user.uid, isBackground: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  List<TakeHomeChallenge> _visibleChallenges(
    BuildContext context,
    AssessmentsHubProvider assessmentsProvider,
    CandidateApplicationsProvider appsProvider,
  ) {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null || uid.isEmpty) return const [];

    final userSubmittedChallengeIds = assessmentsProvider.candidateSubmissions
        .where((s) => s.candidateId == uid)
        .map((s) => s.challengeId)
        .toSet();

    final appliedJobIds = appsProvider.applications
        .where((a) =>
            a.candidateId == uid && a.status != ApplicationStatus.withdrawn)
        .map((a) => a.jobId)
        .where((id) => id.isNotEmpty)
        .toSet();

    return assessmentsProvider.challenges.where((c) {
      if (c.candidateId == uid) return true;
      if (userSubmittedChallengeIds.contains(c.id)) return true;
      if ((c.candidateId == null || c.candidateId!.isEmpty) &&
          c.jobId != null &&
          c.jobId!.isNotEmpty &&
          appliedJobIds.contains(c.jobId)) {
        return true;
      }
      return false;
    }).toList();
  }

  Future<void> _validateAccessCodeAndOpenRunner(
    BuildContext context,
    String rawCode,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final code = rawCode.trim();
    if (code.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter your examination access code.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _isValidatingCode = true);

    try {
      // 1. Check in-memory attempts first, then fallback to Firestore query
      final provider = context.read<CandidateExamsProvider>();
      ExamAttempt? matched = provider.attempts
          .where((a) => a.token.trim().toLowerCase() == code.toLowerCase())
          .firstOrNull;

      if (matched == null) {
        final snap = await FirebaseFirestore.instance
            .collection('examAttempts')
            .where('candidateId', isEqualTo: user.uid)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final docToken = (data['token'] ?? '').toString().trim();
          if (docToken.toLowerCase() == code.toLowerCase()) {
            matched = ExamAttemptModel.fromFirestore(doc);
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() => _isValidatingCode = false);

      if (matched == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
                'Invalid access code or examination not assigned to your account.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (matched.isTerminated) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
                'This examination session was terminated due to proctoring rules.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (matched.isTerminated) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
                'This examination attempt was terminated due to proctoring violations and cannot be resumed.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (matched.isCompleted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
                'This examination has already been submitted and cannot be retaken.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      if (matched.expiresAt != null &&
          matched.expiresAt!.isBefore(DateTime.now())) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
                'This examination access code has expired past its deadline.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (!context.mounted) return;
      // Launch official web examination portal exclusively
      await UrlLauncherHelper.openUrl(
        context,
        matched.assessmentUrl,
        successMessage: 'Opening Official Examination Portal...',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isValidatingCode = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Verification error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _launchOfficialExamPortal(
    BuildContext context,
    ExamAttempt attempt,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();

    if (attempt.isTerminated) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'This examination session was terminated and cannot be resumed.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (attempt.isCompleted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'This examination has already been completed and cannot be retaken.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (attempt.expiresAt != null && attempt.expiresAt!.isBefore(now)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('This examination has expired past its deadline.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await UrlLauncherHelper.openUrl(
      context,
      attempt.assessmentUrl,
      successMessage: 'Launching Official Examination Website...',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final examsProvider = context.watch<CandidateExamsProvider>();
    final assessmentsProvider = context.watch<AssessmentsHubProvider>();
    final appsProvider = context.watch<CandidateApplicationsProvider>();
    final visibleChallenges =
        _visibleChallenges(context, assessmentsProvider, appsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embeddedInShell,
        title: Text(l10n?.assessmentsHeader ?? 'Assessments & Assignments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Assessments',
            onPressed: () {
              final user = context.read<AuthProvider>().user;
              if (user != null) {
                examsProvider.loadCandidateAttempts(user.uid);
                appsProvider.loadApplications(user.uid, isBackground: true);
                assessmentsProvider.listenAvailableChallenges();
                assessmentsProvider.listenCandidateSubmissions(user.uid);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.quiz_outlined, size: 18),
              text: '${l10n?.examinationsTab ?? "Examinations"} (${examsProvider.attempts.length})',
            ),
            Tab(
              icon: const Icon(Icons.assignment_outlined, size: 18),
              text: '${l10n?.assignmentsTab ?? "Assignments"} (${visibleChallenges.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExaminationsTab(context, examsProvider),
          _buildAssignmentsTab(context, assessmentsProvider, visibleChallenges),
        ],
      ),
    );
  }

  Widget _buildExaminationsTab(
    BuildContext context,
    CandidateExamsProvider provider,
  ) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        final user = context.read<AuthProvider>().user;
        if (user != null) {
          await provider.loadCandidateAttempts(user.uid);
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Access Code Validation Entry Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.vpn_key_rounded,
                          size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n?.haveExamAccessCode ?? 'Have an Examination Access Code?',
                            style: AppTypography.bodyLarge
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(l10n?.enterExamKeyHint ?? 'Enter your unique exam key to verify eligibility and launch your timed examination.',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _accessCodeController,
                        decoration: InputDecoration(
                          hintText: l10n?.pasteExamAccessCode ?? 'Paste exam access code (e.g. EXM-...)',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isValidatingCode
                          ? null
                          : () => _validateAccessCodeAndOpenRunner(
                              context, _accessCodeController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isValidatingCode
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n?.verifyAndStart ?? 'Verify & Start'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (provider.isLoading && provider.attempts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.attempts.isEmpty && provider.errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final user = context.read<AuthProvider>().user;
                        if (user != null) {
                          provider.listenCandidateAttempts(user.uid);
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (provider.attempts.isEmpty)
            EmptyStateWidget(
              icon: Icons.quiz_rounded,
              title: l10n?.noAssignedExamsTitle ?? 'No Assigned Examinations Yet',
              description: l10n?.noAssignedExamsSubtitle ?? 'When employers assign online technical assessments for your job applications, they will appear here with your unique access code.',
              actionLabel: l10n?.browseOpenJobs ?? 'Browse Open Jobs',
              actionIcon: Icons.work_outline_rounded,
              onAction: () => context.push('/jobs'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.attempts.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAttemptCard(context, provider.attempts[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab(
    BuildContext context,
    AssessmentsHubProvider provider,
    List<TakeHomeChallenge> challenges,
  ) {
    final l10n = AppLocalizations.of(context);
    final uid = context.read<AuthProvider>().user?.uid;
    final submissions = uid == null
        ? const <ChallengeSubmission>[]
        : provider.candidateSubmissions
            .where((s) => s.candidateId == uid)
            .toList();

    return RefreshIndicator(
      onRefresh: () async {
        final user = context.read<AuthProvider>().user;
        provider.listenAvailableChallenges();
        if (user != null) {
          provider.listenCandidateSubmissions(user.uid);
        }
      },
      child: provider.isLoading && challenges.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : challenges.isEmpty && provider.errorMessage != null
              ? LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                                provider.errorMessage!,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    provider.listenAvailableChallenges(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : challenges.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              minHeight: constraints.maxHeight),
                          child: Center(
                            child: EmptyStateWidget(
                              icon: Icons.assignment_turned_in_outlined,
                              title: l10n?.noChallengesTitle ??
                                  'No Candidate Assignments',
                              description: l10n?.noChallengesSubtitle ??
                                  'Practical take-home tasks and project assignments from employers will appear here.',
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: challenges.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final challenge = challenges[index];
                        final sub = submissions
                            .where((s) => s.challengeId == challenge.id)
                            .firstOrNull;
                        return _buildAssignmentCard(context, challenge, sub);
                      },
                    ),
    );
  }

  Widget _buildAssignmentCard(
    BuildContext context,
    TakeHomeChallenge challenge,
    ChallengeSubmission? submission,
  ) {
    final isSubmitted = submission != null;
    final statusColor = isSubmitted ? AppColors.success : AppColors.warning;
    final statusLabel = isSubmitted
        ? submission.status.toShortString()
        : 'PENDING SUBMISSION';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/assessments/challenge/${challenge.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.folder_special_outlined,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(challenge.title, style: AppTypography.headlineSmall),
                        const SizedBox(height: 2),
                        Text(
                          'Company: ${challenge.companyName}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                challenge.brief,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildMetaChip(
                    Icons.schedule_rounded,
                    'Due in ${challenge.deadlineDays} days',
                  ),
                  _buildMetaChip(
                    Icons.layers_outlined,
                    challenge.difficulty.toShortString(),
                  ),
                  if (submission?.score != null)
                    _buildMetaChip(
                      Icons.grade_rounded,
                      'Score: ${submission!.score!.toStringAsFixed(0)}/100',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    isSubmitted
                        ? 'View Submission & Feedback'
                        : 'Open Assignment & Upload Solution',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptCard(BuildContext context, ExamAttempt attempt) {
    final l10n = AppLocalizations.of(context);
    final isTerminated = attempt.isTerminated;
    final isCompleted = attempt.isCompleted && !isTerminated;
    final isExpired = attempt.expiresAt != null &&
        attempt.expiresAt!.isBefore(DateTime.now()) &&
        !isCompleted &&
        !isTerminated;

    final Color badgeColor = isTerminated
        ? AppColors.error
        : isCompleted
            ? AppColors.success
            : isExpired
                ? AppColors.error
                : AppColors.warning;
    final String badgeText = isTerminated
        ? 'TERMINATED'
        : isCompleted
            ? 'COMPLETED'
            : isExpired
                ? 'EXPIRED'
                : attempt.status.displayName.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
                      Text(attempt.examTitle,
                          style: AppTypography.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        'Role: ${attempt.jobTitle}',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${attempt.durationMinutes} minutes',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 16),
                const Icon(Icons.verified_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Passing score: ${attempt.passingPercentage}%',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),

            // Schedule & Deadline Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      const Text(
                        'Available From: ',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                      Expanded(
                        child: Text(
                          attempt.invitationSentAt != null
                              ? DateFormat('yyyy/MM/dd • hh:mm a')
                                  .format(attempt.invitationSentAt!)
                              : 'Immediately Available',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.event_busy_rounded,
                          size: 13, color: Colors.deepOrange),
                      const SizedBox(width: 6),
                      const Text(
                        'Deadline: ',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                      Expanded(
                        child: Text(
                          attempt.expiresAt != null
                              ? DateFormat('yyyy/MM/dd • hh:mm a')
                                  .format(attempt.expiresAt!)
                              : 'Within 7 days of assignment',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Access Key / Token Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Examination Access Code:',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          attempt.token,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.copy, size: 14),
                    label:
                        Text(l10n?.copyCode ?? 'Copy Code', style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: attempt.token));
                      _accessCodeController.text = attempt.token;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Access code copied & filled in the verifier!'),
                          backgroundColor: AppColors.success,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (isTerminated)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.gpp_bad_outlined, color: AppColors.error, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'FAILED (0%) • Session terminated due to proctoring violations. Reported to the hiring team.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (isCompleted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: attempt.passed
                      ? AppColors.successSubtle
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: attempt.passed
                      ? null
                      : Border.all(
                          color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      attempt.passed
                          ? Icons.check_circle_rounded
                          : Icons.cancel_outlined,
                      color: attempt.passed
                          ? AppColors.success
                          : AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Examination Completed • Official Score: ${attempt.score.toStringAsFixed(0)}% (${attempt.passed ? "PASSED" : "FAILED"})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: attempt.passed
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isExpired ? AppColors.error : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isExpired
                      ? null
                      : () => _launchOfficialExamPortal(context, attempt),
                  icon: const Icon(Icons.open_in_browser, size: 18),
                  label: Text(
                    isExpired
                        ? 'Examination Expired'
                        : (l10n?.officialExamWebsite ?? 'Take Exam on Official Website'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
