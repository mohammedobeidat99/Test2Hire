import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/url_launcher_helper.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/interview.dart';
import '../providers/candidate_interviews_provider.dart';

class CandidateInterviewsScreen extends StatefulWidget {
  const CandidateInterviewsScreen({super.key});

  @override
  State<CandidateInterviewsScreen> createState() => _CandidateInterviewsScreenState();
}

class _CandidateInterviewsScreenState extends State<CandidateInterviewsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<CandidateInterviewsProvider>().listenCandidateInterviews(user.uid);
      }
    });
  }

  void _showRsvpDialog(BuildContext context, Interview interview) {
    int selectedSlot = 0;
    final declineReasonController = TextEditingController();
    final dateFormat = DateFormat('EEE, MMM d • h:mm a', 'en_US');
    String? dialogError;

    showDialog(
      context: context,
      builder: (dCtx) => Consumer<CandidateInterviewsProvider>(
        builder: (dCtx, provider, _) => StatefulBuilder(
          builder: (context, setDialogState) {
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isArabic ? 'تأكيد المقابلة: ${interview.companyName}' : 'Interview RSVP: ${interview.companyName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'الوظيفة: ${interview.jobTitle}' : 'Position: ${interview.jobTitle}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(isArabic ? 'طريقة المقابلة: ${interview.type == InterviewType.videoCall ? "عبر الفيديو" : "حضوري"}' : 'Format: ${interview.type.displayName}'),
                    const SizedBox(height: 16),
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

                  Text(
                    Localizations.localeOf(context).languageCode == 'ar' ? 'اختر الموعد الأنسب لك:' : 'Select your preferred time slot:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  if (interview.slots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        Localizations.localeOf(context).languageCode == 'ar' ? 'لا توجد مواعيد محددة مدرجة حالياً.' : 'No specific time slots are currently listed.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ...interview.slots.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final slot = entry.value;
                      final isChosen = selectedSlot == idx;

                      return InkWell(
                        onTap: () => setDialogState(() => selectedSlot = idx),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isChosen
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.divider.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isChosen ? AppColors.primary : AppColors.border,
                              width: isChosen ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isChosen ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isChosen ? AppColors.primary : AppColors.textTertiary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dateFormat.format(slot.startTime),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                                    color: isChosen ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),

                  Text(Localizations.localeOf(context).languageCode == 'ar' ? 'سبب الاعتذار (في حال عدم التمكن من الحضور):' : 'Decline Reason (Only if declining):', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: declineReasonController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Schedule conflict, accepted another offer...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: provider.isResponding ? null : () => Navigator.pop(dCtx),
                child: const Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: provider.isResponding
                    ? null
                    : () async {
                        setDialogState(() => dialogError = null);
                        final nav = Navigator.of(dCtx);
                        final messenger = ScaffoldMessenger.of(this.context);

                        final success = await provider.respondToInterview(
                          interviewId: interview.id,
                          response: 'DECLINE',
                          declineReason: declineReasonController.text.trim().isNotEmpty
                              ? declineReasonController.text.trim()
                              : 'Candidate unavailable',
                        );

                        if (success) {
                          if (nav.mounted) nav.pop();
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Interview invitation declined.')),
                            );
                          }
                        } else if (dCtx.mounted) {
                          setDialogState(() {
                            dialogError = provider.errorMessage ?? 'Failed to decline interview.';
                          });
                        }
                      },
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Decline'),
              ),
              ElevatedButton(
                onPressed: provider.isResponding
                    ? null
                    : () async {
                        setDialogState(() => dialogError = null);
                        final nav = Navigator.of(dCtx);
                        final messenger = ScaffoldMessenger.of(this.context);

                        final success = await provider.respondToInterview(
                          interviewId: interview.id,
                          response: 'ACCEPT',
                          selectedSlotIndex: selectedSlot,
                        );

                        if (success) {
                          if (nav.mounted) nav.pop();
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(isArabic ? 'تم تأكيد موعد المقابلة! رابط اللقاء متاح.' : 'Interview confirmed! Meeting link is ready.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } else if (dCtx.mounted) {
                          setDialogState(() {
                            dialogError = provider.errorMessage ?? 'Failed to confirm interview.';
                          });
                        }
                      },
                child: provider.isResponding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Accept & Confirm'),
              ),
            ],
          );
          },
        ),
      ),
    ).whenComplete(declineReasonController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<CandidateInterviewsProvider>();
    final dateFormat = DateFormat('EEE, MMM d, yyyy • h:mm a', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.myInterviewsTitle ?? 'My Interviews'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final user = context.read<AuthProvider>().user;
              if (user != null) provider.loadCandidateInterviews(user.uid);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = context.read<AuthProvider>().user;
          if (user != null) await provider.loadCandidateInterviews(user.uid);
        },
        child: provider.isLoading && provider.interviews.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.interviews.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: provider.errorMessage != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
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
                                          if (user != null) provider.loadCandidateInterviews(user.uid);
                                        },
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : EmptyStateWidget(
                                icon: Icons.video_call_rounded,
                                title: l10n?.noInterviewsTitle ?? 'No Interviews Scheduled',
                                description: l10n?.noInterviewsSubtitle ?? 'When employers review your application and invite you for a virtual or in-person interview, your scheduled meetings will appear here.',
                              ),
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
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
                                    interview.companyName.isNotEmpty
                                        ? interview.companyName[0].toUpperCase()
                                        : 'C',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        interview.jobTitle.isNotEmpty ? interview.jobTitle : 'Interview',
                                        style: AppTypography.headlineSmall,
                                      ),
                                      Text(
                                        '${interview.companyName.isNotEmpty ? interview.companyName : "Company"} • ${interview.type.displayName}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                                  Expanded(
                                    child: Text(
                                      dateFormat.format(slot.startTime),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),

                            if (interview.location != null && interview.location!.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textTertiary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      interview.location!,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            if (interview.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(interview.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],

                            if (interview.interviewerNames.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.people_outline, size: 14, color: AppColors.textTertiary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Interviewers: ${interview.interviewerNames.join(", ")}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            if (interview.isPendingCandidate ||
                                (interview.isConfirmed &&
                                    interview.type == InterviewType.videoCall &&
                                    (interview.meetingUrl?.isNotEmpty ?? false))) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (interview.isPendingCandidate) ...[
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                      label: Text(l10n?.confirmAttendance ?? 'Confirm Attendance'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.success,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: provider.isResponding
                                          ? null
                                          : () async {
                                              final messenger = ScaffoldMessenger.of(context);
                                              final ok = await provider.respondToInterview(
                                                interviewId: interview.id,
                                                response: 'ACCEPT',
                                                selectedSlotIndex: interview.selectedSlotIndex ?? 0,
                                              );
                                              if (ok) {
                                                if (!mounted) return;
                                                messenger.showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Interview attendance confirmed!'),
                                                    backgroundColor: AppColors.success,
                                                  ),
                                                );
                                              } else if (mounted) {
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(provider.errorMessage ?? 'Failed to confirm interview.'),
                                                    backgroundColor: AppColors.error,
                                                  ),
                                                );
                                              }
                                            },
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.tune_rounded, size: 16),
                                      label: const Text('Options / Decline'),
                                      onPressed: () => _showRsvpDialog(context, interview),
                                    ),
                                  ],

                                  if (interview.isConfirmed &&
                                      interview.type == InterviewType.videoCall &&
                                      (interview.meetingUrl?.isNotEmpty ?? false))
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.video_camera_front, size: 16),
                                      label: Text(l10n?.joinMeeting ?? 'Join Video Meeting'),
                                      onPressed: () async {
                                        final url = interview.meetingUrl;
                                        if (url != null && url.isNotEmpty) {
                                          await UrlLauncherHelper.openUrl(context, url);
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
