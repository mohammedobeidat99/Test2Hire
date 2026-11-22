import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/url_launcher_helper.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/interview.dart';
import '../providers/company_interviews_provider.dart';

class CompanyInterviewsScreen extends StatefulWidget {
  const CompanyInterviewsScreen({super.key});

  @override
  State<CompanyInterviewsScreen> createState() => _CompanyInterviewsScreenState();
}

class _CompanyInterviewsScreenState extends State<CompanyInterviewsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<CompanyInterviewsProvider>().listenCompanyInterviews(user.uid);
      }
    });
  }

  void _showFeedbackModal(BuildContext context, Interview interview) {
    int score = 80;
    String recommendation = 'RECOMMEND_HIRE';
    final notesController = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (dCtx) => Consumer<CompanyInterviewsProvider>(
        builder: (dCtx, provider, _) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Interview Evaluation: ${interview.candidateName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dialogError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          dialogError!,
                          style: const TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    ],
                  const Text('Evaluation Score (0 - 100):', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: score.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '$score',
                          onChanged: (val) {
                            setDialogState(() => score = val.round());
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$score%',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Hiring Recommendation:', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: recommendation,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(
                        value: 'RECOMMEND_HIRE',
                        child: Text('Recommend Hire (Strong Pass)', style: TextStyle(color: AppColors.success)),
                      ),
                      DropdownMenuItem(
                        value: 'NEUTRAL',
                        child: Text('Neutral / Borderline', style: TextStyle(color: AppColors.warning)),
                      ),
                      DropdownMenuItem(
                        value: 'DO_NOT_HIRE',
                        child: Text('Do Not Hire', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => recommendation = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  const Text('Recruiter / Interviewer Notes:', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      hintText: 'Technical strengths, behavioral alignment, cultural fit...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: provider.isSaving ? null : () => Navigator.pop(dCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: provider.isSaving
                    ? null
                    : () async {
                        setDialogState(() => dialogError = null);
                        final nav = Navigator.of(dCtx);
                        final messenger = ScaffoldMessenger.of(this.context);

                        final success = await provider.submitFeedback(
                          interviewId: interview.id,
                          score: score,
                          recommendation: recommendation,
                          notes: notesController.text.trim(),
                        );

                        if (success) {
                          if (nav.mounted) nav.pop();
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Interview evaluation submitted successfully!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } else if (dCtx.mounted) {
                          setDialogState(() {
                            dialogError = provider.errorMessage ?? 'Failed to submit feedback.';
                          });
                        }
                      },
                child: provider.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Feedback'),
              ),
            ],
          );
          },
        ),
      ),
    ).whenComplete(notesController.dispose);
  }

  Future<void> _confirmCancelInterview(BuildContext context, Interview interview) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Interview?'),
        content: Text(
          'Are you sure you want to cancel the scheduled interview with ${interview.candidateName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Interview'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Interview'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final provider = context.read<CompanyInterviewsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.cancelInterview(interview.id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Interview cancelled.'
              : (provider.errorMessage ?? 'Failed to cancel interview.'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompanyInterviewsProvider>();
    final dateFormat = DateFormat('EEE, MMM d, yyyy • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Candidate Interviews'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final user = context.read<AuthProvider>().user;
              if (user != null) provider.loadCompanyInterviews(user.uid);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: Text('All (${provider.totalCount})'),
                  selected: provider.statusFilter == null,
                  onSelected: (_) => provider.setStatusFilter(null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Confirmed (${provider.confirmedCount})'),
                  selected: provider.statusFilter == InterviewStatus.confirmed,
                  onSelected: (_) => provider.setStatusFilter(InterviewStatus.confirmed),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Pending RSVP (${provider.pendingCount})'),
                  selected: provider.statusFilter == InterviewStatus.pendingCandidate,
                  onSelected: (_) => provider.setStatusFilter(InterviewStatus.pendingCandidate),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Completed (${provider.completedCount})'),
                  selected: provider.statusFilter == InterviewStatus.completed,
                  onSelected: (_) => provider.setStatusFilter(InterviewStatus.completed),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final user = context.read<AuthProvider>().user;
                if (user != null) await provider.loadCompanyInterviews(user.uid);
              },
              child: provider.isLoading && provider.allInterviews.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.interviews.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: provider.errorMessage != null
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                                            const SizedBox(height: 12),
                                            Text(
                                              provider.errorMessage!,
                                              textAlign: TextAlign.center,
                                              style: AppTypography.bodyMedium,
                                            ),
                                            const SizedBox(height: 16),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                final user = context.read<AuthProvider>().user;
                                                if (user != null) provider.loadCompanyInterviews(user.uid);
                                              },
                                              icon: const Icon(Icons.refresh),
                                              label: const Text('Retry'),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.video_call_outlined, size: 56, color: AppColors.textTertiary),
                                            const SizedBox(height: 12),
                                            Text('No interviews found', style: AppTypography.headlineSmall),
                                            const SizedBox(height: 4),
                                            Text(
                                              provider.statusFilter == null
                                                  ? 'No candidates have been scheduled for an interview yet.'
                                                  : 'No interviews found for the selected filter.',
                                              textAlign: TextAlign.center,
                                              style: AppTypography.bodySmall,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: provider.interviews.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final interview = provider.interviews[index];
                          final slot = interview.activeSlot;

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
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                        child: Text(
                                          interview.candidateName.isNotEmpty
                                              ? interview.candidateName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(interview.candidateName, style: AppTypography.headlineSmall),
                                            Text(
                                              '${interview.jobTitle} • ${interview.type.displayName}',
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(interview.status).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          interview.status.displayName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(interview.status),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),

                                  if (slot != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.event, size: 16, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Text(
                                          dateFormat.format(slot.startTime),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),

                                  if (interview.description.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      interview.description,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],

                                  if (interview.feedback != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.verified, size: 16, color: AppColors.success),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Score: ${interview.feedback!.score}% (${interview.feedback!.recommendation.replaceAll('_', ' ')})',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 14),

                                  // Actions Row
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (interview.type == InterviewType.videoCall &&
                                          (interview.meetingUrl?.isNotEmpty ?? false))
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.video_camera_front, size: 16),
                                          label: const Text('Join Call'),
                                          onPressed: () async {
                                            await UrlLauncherHelper.openUrl(
                                              context,
                                              interview.meetingUrl!,
                                            );
                                          },
                                        ),

                                      if (interview.status != InterviewStatus.completed &&
                                          interview.status != InterviewStatus.cancelled)
                                        TextButton.icon(
                                          icon: const Icon(Icons.rate_review_outlined, size: 16),
                                          label: const Text('Evaluate'),
                                          onPressed: () => _showFeedbackModal(context, interview),
                                        ),

                                      if (interview.status != InterviewStatus.cancelled &&
                                          interview.status != InterviewStatus.completed)
                                        IconButton(
                                          icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
                                          tooltip: 'Cancel Interview',
                                          onPressed: provider.isSaving
                                              ? null
                                              : () => _confirmCancelInterview(context, interview),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(InterviewStatus status) {
    switch (status) {
      case InterviewStatus.confirmed:
        return AppColors.success;
      case InterviewStatus.pendingCandidate:
        return AppColors.warning;
      case InterviewStatus.completed:
        return AppColors.primary;
      case InterviewStatus.cancelled:
      case InterviewStatus.declined:
        return AppColors.error;
    }
  }
}
