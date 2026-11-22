import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/url_launcher_helper.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../exams/domain/entities/exam_template.dart';
import '../../../exams/presentation/providers/company_exams_provider.dart';
import '../../../interviews/presentation/screens/schedule_interview_dialog.dart';
import '../../../offers/presentation/screens/create_offer_dialog.dart';
import '../../domain/entities/job_application.dart';
import '../providers/company_applicants_provider.dart';

class CompanyApplicantsScreen extends StatefulWidget {
  final String jobId;
  final String? jobTitle;

  const CompanyApplicantsScreen({
    super.key,
    required this.jobId,
    this.jobTitle,
  });

  @override
  State<CompanyApplicantsScreen> createState() => _CompanyApplicantsScreenState();
}

class _CompanyApplicantsScreenState extends State<CompanyApplicantsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyApplicantsProvider>().listenJobApplicants(widget.jobId);
    });
  }

  Future<void> _downloadOrViewCv(BuildContext context, String cvUrl, String fileName) async {
    await UrlLauncherHelper.openUrl(
      context,
      cvUrl,
      successMessage: 'Opening CV / Resume ($fileName)...',
    );
  }

  void _showActionDialog(BuildContext context, JobApplication app) {
    final provider = context.read<CompanyApplicantsProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Candidate: ${app.candidateName}',
                    style: AppTypography.headlineSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),

                ListTile(
                  leading: const Icon(Icons.download_rounded, color: AppColors.primary),
                  title: const Text('Download / View Resume (تحميل السيرة الذاتية)'),
                  subtitle: Text(app.cvFileName.isNotEmpty ? app.cvFileName : 'Candidate_Resume.pdf'),
                  trailing: const Icon(Icons.open_in_new, size: 18, color: AppColors.textTertiary),
                  onTap: () {
                    Navigator.pop(ctx);
                    _downloadOrViewCv(context, app.cvUrl, app.cvFileName);
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.auto_awesome, color: AppColors.secondary),
                  title: const Text('AI Resume Analysis & Fit Scoring'),
                  subtitle: Text(
                    app.aiParsedCv != null
                        ? 'View detailed AI extraction & fit metrics'
                        : 'Trigger Gemini AI parse & calculate match score',
                  ),
                  trailing: provider.isAiParsing && provider.parsingApplicationId == app.id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (app.aiParsedCv != null) {
                      _showAiInsightsSheet(context, app);
                    } else {
                      final result = await provider.parseApplicantCv(app.id);
                      if (result != null && context.mounted) {
                        final updated = provider.applicants.firstWhere(
                          (a) => a.id == app.id,
                          orElse: () => app,
                        );
                        _showAiInsightsSheet(context, updated);
                      }
                    }
                  },
                ),

                if (app.status == ApplicationStatus.applied)
                  ListTile(
                    leading: const Icon(Icons.rate_review_outlined, color: AppColors.primary),
                    title: const Text('Move to Under Review'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await provider.updateApplicantStatus(app.id, ApplicationStatus.underReview);
                    },
                  ),

                if (app.hasExamAssigned)
                  ListTile(
                    leading: const Icon(Icons.vpn_key_outlined, color: AppColors.primary),
                    title: const Text('View Exam Key & Portal (رمز ورابط الامتحان)'),
                    subtitle: Text('${app.examTitle ?? "Online Assessment"} • Key: ${app.examToken ?? "Generated"}'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showExamDetailsDialog(context, app);
                    },
                  ),

                if (app.status != ApplicationStatus.rejected)
                  ListTile(
                    leading: const Icon(Icons.quiz_outlined, color: AppColors.info),
                    title: Text(app.hasExamAssigned ? 'Re-assign Online Assessment' : 'Assign Online Assessment (تعيين امتحان)'),
                    subtitle: Text(app.hasExamAssigned ? 'Change exam template or customized duration' : 'AI exam matching & generate candidate access key'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAssignExamDialog(context, app);
                    },
                  ),

                ListTile(
                  leading: const Icon(Icons.video_call_outlined, color: AppColors.success),
                  title: const Text('Invite to Interview'),
                  subtitle: const Text('Schedule video meeting or in-person interview'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => ScheduleInterviewDialog(application: app),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.analytics_outlined, color: AppColors.primary),
                  title: const Text('Candidate Scorecard & Evaluation'),
                  subtitle: const Text('View weighted composite scoring, ranking & recommendations'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(
                      '${AppRoutes.scorecardDetail}/${app.id}?candidateName=${Uri.encodeComponent(app.candidateName)}',
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.verified_outlined, color: Color(0xFF047857)),
                  title: const Text('Select / Make Job Offer'),
                  subtitle: const Text('Configure compensation, benefits, and formal offer letter'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => CreateOfferDialog(application: app),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: AppColors.error),
                  title: const Text('Reject Candidate', style: TextStyle(color: AppColors.error)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    _showRejectDialog(context, app);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }

  void _showAssignExamDialog(BuildContext context, JobApplication app) {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      context.read<CompanyExamsProvider>().loadCompanyExams(user.uid);
    }

    String? selectedExamId;
    final durationController = TextEditingController(
      text: (app.examDurationMinutes ?? 45).toString(),
    );
    int deadlineDays = 7;
    String? aiRecommendationNote;
    bool hasAutoMatched = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final examsProv = dialogCtx.watch<CompanyExamsProvider>();
          final exams = examsProv.exams;

          void performAiMatch() {
            if (exams.isEmpty) return;
            final candidateSkills = <String>[];
            if (app.aiParsedCv != null) {
              candidateSkills.addAll(
                app.aiParsedCv!.extractedSkills.map((s) => s.toLowerCase().trim()),
              );
            }
            final targetRole = (widget.jobTitle ?? app.jobTitle).toLowerCase();

            ExamTemplate? bestMatch;
            int bestScore = -1;

            for (final ex in exams) {
              int score = 0;
              final examText = '${ex.title} ${ex.description}'.toLowerCase();
              if (targetRole.isNotEmpty && examText.contains(targetRole)) {
                score += 5;
              }
              for (final skill in candidateSkills) {
                if (skill.length > 2 && examText.contains(skill)) {
                  score += 2;
                }
              }
              if (score > bestScore) {
                bestScore = score;
                bestMatch = ex;
              }
            }

            final matched = bestMatch ?? exams.first;
            setDialogState(() {
              selectedExamId = matched.id;
              durationController.text = matched.durationMinutes.toString();
              hasAutoMatched = true;
              aiRecommendationNote = bestScore > 0
                  ? 'AI matched: "${matched.title}" with applicant skills profile.'
                  : 'AI suggested template: "${matched.title}".';
            });
          }

          // Initial auto-selection if not set
          if (!hasAutoMatched && exams.isNotEmpty && selectedExamId == null) {
            hasAutoMatched = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => performAiMatch());
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.quiz_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Assign Online Assessment',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: examsProv.isLoading
                ? const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : exams.isEmpty
                    ? SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.auto_awesome, color: AppColors.secondary, size: 22),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'No Assessment Templates Yet',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No exams found for your company. Generate a ready-to-use technical assessment for "${widget.jobTitle ?? app.jobTitle}" in 1 click using AI:',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.secondary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: examsProv.isSaving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.auto_awesome, size: 18),
                                      label: Text(
                                        examsProv.isSaving
                                            ? 'Generating Assessment...'
                                            : '⚡ Generate AI Assessment (إنشاء فوري)',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: examsProv.isSaving
                                          ? null
                                          : () async {
                                              final curUser = context.read<AuthProvider>().user;
                                              if (curUser == null) return;
                                              final targetRole = widget.jobTitle ?? app.jobTitle;
                                              final newId = await examsProv.quickGenerateExamForRole(
                                                companyId: curUser.uid,
                                                roleTitle: targetRole,
                                              );
                                              if (newId != null) {
                                                setDialogState(() {
                                                  selectedExamId = newId;
                                                  hasAutoMatched = true;
                                                  aiRecommendationNote = 'AI generated and selected "$targetRole Assessment" with verified questions.';
                                                });
                                              }
                                            },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Create Custom Template Manually', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  Navigator.pop(dCtx);
                                  context.push(AppRoutes.createExam);
                                },
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Candidate: ${app.candidateName}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Target Role: ${widget.jobTitle ?? app.jobTitle}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),

                            // AI Auto-Matcher Box
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.auto_awesome, size: 16, color: AppColors.secondary),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          'AI Assessment Matcher',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: performAiMatch,
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Row(
                                            children: [
                                              Icon(Icons.refresh, size: 13, color: AppColors.secondary),
                                              SizedBox(width: 2),
                                              Text('Auto Match', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (aiRecommendationNote != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        aiRecommendationNote!,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                                      ),
                                    )
                                  else
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Matches available exams to applicant\'s CV skills & target role.',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Exam Dropdown
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: selectedExamId,
                              decoration: InputDecoration(
                                labelText: 'Exam Template (نموذج الامتحان)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                prefixIcon: const Icon(Icons.assignment_outlined),
                              ),
                              items: exams.map((e) {
                                return DropdownMenuItem(
                                  value: e.id,
                                  child: Text(
                                    '${e.title} (${e.durationMinutes}m)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setDialogState(() {
                                  selectedExamId = val;
                                  final ex = exams.firstWhere((x) => x.id == val, orElse: () => exams.first);
                                  durationController.text = ex.durationMinutes.toString();
                                });
                              },
                            ),
                            const SizedBox(height: 14),

                            // Duration input
                            TextFormField(
                              controller: durationController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                labelText: 'Duration / مدة الامتحان',
                                hintText: 'e.g. 45',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                prefixIcon: const Icon(Icons.timer_outlined),
                                suffixText: 'mins',
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Deadline Days Dropdown
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: deadlineDays,
                              decoration: InputDecoration(
                                labelText: 'Deadline / مهلة الإنجاز',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                prefixIcon: const Icon(Icons.event_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(value: 3, child: Text('3 Days', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 5, child: Text('5 Days', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 7, child: Text('7 Days (Default)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 14, child: Text('14 Days', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 30, child: Text('30 Days', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => deadlineDays = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel'),
              ),
              if (exams.isNotEmpty)
                ElevatedButton(
                  onPressed: selectedExamId == null || examsProv.isSaving
                      ? null
                      : () async {
                          final duration = int.tryParse(durationController.text.trim()) ?? 45;
                          final nav = Navigator.of(dCtx);
                          final scaffoldMessenger = ScaffoldMessenger.of(this.context);
                          final applicantsProv = this.context.read<CompanyApplicantsProvider>();

                          final result = await examsProv.assignExam(
                            examId: selectedExamId!,
                            applicationId: app.id,
                            candidateId: app.candidateId,
                            jobId: app.jobId,
                            durationMinutes: duration,
                            deadlineDays: deadlineDays,
                          );

                          if (result != null) {
                            nav.pop();
                            applicantsProv.loadJobApplicants(widget.jobId);
                            if (mounted) {
                              _showExamAssignedSuccessDialog(this.context, app, result);
                            }
                          } else {
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(examsProv.errorMessage ?? 'Failed to assign assessment. Please try again.'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  child: examsProv.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Assign & Send Key'),
                ),
            ],
          );
        },
      ),
    ).whenComplete(durationController.dispose);
  }

  void _showExamAssignedSuccessDialog(
    BuildContext context,
    JobApplication app,
    AssignExamResult result,
  ) {
    final directUrl = result.assessmentUrl;

    showDialog(
      context: context,
      builder: (sCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Assessment Assigned!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assessment token generated for ${app.candidateName}. The candidate has been notified and can view and copy the key directly in their mobile app.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              const Text(
                'Candidate Exam Key / رمز الامتحان:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        result.token,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                      tooltip: 'Copy Exam Key',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: result.token));
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Exam Key copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('Duration: ${result.durationMinutes} minutes', style: const TextStyle(fontSize: 12)),
                ],
              ),
              if (result.expiresAt != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Deadline: ${result.expiresAt!.day}/${result.expiresAt!.month}/${result.expiresAt!.year}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.link, size: 16),
                      label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: directUrl));
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Direct Exam Link copied!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open Portal', style: TextStyle(fontSize: 12)),
                      onPressed: () => UrlLauncherHelper.openUrl(
                        this.context,
                        directUrl,
                        successMessage: 'Opening Assessment Portal...',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(sCtx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showExamDetailsDialog(BuildContext context, JobApplication app) {
    final token = app.examToken ?? '';
    final directUrl = token.isNotEmpty
        ? '${ExamAttempt.webExamPortalUrl}/exam/$token'
        : ExamAttempt.webExamPortalUrl;

    showDialog(
      context: context,
      builder: (sCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.quiz_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Assigned Assessment',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Candidate: ${app.candidateName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Template: ${app.examTitle ?? "Online Assessment"}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (app.examDurationMinutes != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Duration: ${app.examDurationMinutes} minutes',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              if (token.isNotEmpty) ...[
                const Text(
                  'Candidate Access Key / رمز الامتحان:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          token,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: AppColors.primary),
                        tooltip: 'Copy Key',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: token));
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Exam Key copied to clipboard!')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: directUrl));
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Direct link copied!')),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_browser, size: 14),
                        label: const Text('Open Exam', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final uri = Uri.parse(directUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Key has not been generated for this application yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(sCtx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(sCtx);
              _showAssignExamDialog(context, app);
            },
            child: const Text('Re-assign Assessment'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, JobApplication app) {
    final reasonController = TextEditingController();
    final provider = context.read<CompanyApplicantsProvider>();

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reject ${app.candidateName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optionally provide feedback to the candidate explaining why their application was not advanced:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Seeking candidate with more senior experience...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              final messenger = ScaffoldMessenger.of(this.context);
              Navigator.pop(dCtx);
              final ok = await provider.updateApplicantStatus(
                app.id,
                ApplicationStatus.rejected,
                reason: reason.isNotEmpty ? reason : null,
              );
              if (!ok) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(provider.errorMessage ?? 'Failed to reject applicant.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    ).whenComplete(reasonController.dispose);
  }

  void _showAiInsightsSheet(BuildContext context, JobApplication app) {
    final ai = app.aiParsedCv;
    if (ai == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: AppColors.secondary, size: 28),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'AI Candidate Insights',
                                style: AppTypography.headlineMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download CV', style: TextStyle(fontSize: 12)),
                        onPressed: () => _downloadOrViewCv(context, app.cvUrl, app.cvFileName),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Powered by Google Gemini 3.5 Flash',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  ),
                  const Divider(height: 24),

                  // Score Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CV Match', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(
                                '${ai.cvMatchScore}%',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Overall Fit', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(
                                '${app.overallFitScore ?? ai.cvMatchScore}%',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // AI Recommendation Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getRecommendationColor(ai.aiRecommendation).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _getRecommendationColor(ai.aiRecommendation).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.insights, color: _getRecommendationColor(ai.aiRecommendation)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ai.aiRecommendation.replaceAll('_', ' '),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getRecommendationColor(ai.aiRecommendation),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(ai.aiRationale, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Matched Skills
                  const Text('Matched Skills', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  ai.matchedSkills.isEmpty
                      ? const Text('No exact skills matched against job requirements.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: ai.matchedSkills.map((s) => Chip(
                            label: Text(s, style: const TextStyle(fontSize: 12, color: AppColors.success)),
                            backgroundColor: AppColors.success.withValues(alpha: 0.12),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )).toList(),
                        ),
                  const SizedBox(height: 16),

                  // Missing Skills
                  const Text('Missing Job Requirements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  ai.missingSkills.isEmpty
                      ? const Text('Candidate meets all key skill requirements!', style: TextStyle(color: AppColors.success, fontSize: 12))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: ai.missingSkills.map((s) => Chip(
                            label: Text(s, style: const TextStyle(fontSize: 12, color: AppColors.error)),
                            backgroundColor: AppColors.error.withValues(alpha: 0.1),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )).toList(),
                        ),
                  const SizedBox(height: 16),

                  // Candidate Overview
                  const Text('Extracted Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.work_outline, size: 20),
                    title: const Text('Experience'),
                    subtitle: Text('${ai.yearsOfExperience} years estimated'),
                  ),
                  if (ai.educationLevel.isNotEmpty)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.school_outlined, size: 20),
                      title: const Text('Education'),
                      subtitle: Text(ai.educationLevel),
                    ),
                  if (ai.extractedSkills.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('All Technical Skills Extracted:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ai.extractedSkills.map((s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.divider,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getRecommendationColor(String rec) {
    switch (rec) {
      case 'STRONG_MATCH':
        return AppColors.success;
      case 'POTENTIAL_MATCH':
        return AppColors.primary;
      case 'PARTIAL_MATCH':
        return AppColors.warning;
      case 'NOT_RECOMMENDED':
      default:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompanyApplicantsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Job Applicants', style: TextStyle(fontSize: 16)),
            if (widget.jobTitle != null)
              Text(
                widget.jobTitle!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'ترتيب وتصنيف المتقدمين (Rankings)',
            icon: const Icon(Icons.leaderboard_outlined, color: AppColors.primary),
            onPressed: () {
              context.push(
                '${AppRoutes.jobRankings.replaceAll(':id', widget.jobId)}?jobTitle=${Uri.encodeComponent(widget.jobTitle ?? "Job Applicants")}',
              );
            },
          ),
          IconButton(
            tooltip: provider.sortByExamScore ? 'Sorting by Exam Score' : 'Sort by Exam Score',
            icon: Icon(
              Icons.military_tech_rounded,
              color: provider.sortByExamScore ? Colors.amber[800] : null,
            ),
            onPressed: () => provider.toggleSortByExamScore(),
          ),
          IconButton(
            tooltip: provider.sortByFitScore ? 'Sorting by AI Fit Score' : 'Sort by Fit Score',
            icon: Icon(
              Icons.auto_awesome,
              color: provider.sortByFitScore ? AppColors.secondary : null,
            ),
            onPressed: () => provider.toggleSortByFitScore(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadJobApplicants(widget.jobId),
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
                  selected: provider.statusFilter == null && !provider.filterTopPerformers,
                  onSelected: (_) {
                    if (provider.filterTopPerformers) provider.toggleTopPerformersFilter();
                    provider.setStatusFilter(null);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.emoji_events, size: 16, color: Colors.amber),
                  label: Text('Top Performers 🏆 (${provider.topPerformersCount})'),
                  selected: provider.filterTopPerformers,
                  selectedColor: Colors.amber.withValues(alpha: 0.25),
                  onSelected: (_) => provider.toggleTopPerformersFilter(),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Applied (${provider.appliedCount})'),
                  selected: provider.statusFilter == ApplicationStatus.applied,
                  onSelected: (_) => provider.setStatusFilter(ApplicationStatus.applied),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Under Review (${provider.underReviewCount})'),
                  selected: provider.statusFilter == ApplicationStatus.underReview,
                  onSelected: (_) => provider.setStatusFilter(ApplicationStatus.underReview),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Selected (${provider.selectedCount})'),
                  selected: provider.statusFilter == ApplicationStatus.selected,
                  onSelected: (_) => provider.setStatusFilter(ApplicationStatus.selected),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Rejected (${provider.rejectedCount})'),
                  selected: provider.statusFilter == ApplicationStatus.rejected,
                  onSelected: (_) => provider.setStatusFilter(ApplicationStatus.rejected),
                ),
              ],
            ),
          ),

          // Applicant List
          Expanded(
            child: provider.isLoading && provider.allApplicants.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.applicants.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.people_outline_rounded,
                        title: 'No Applicants Found',
                        description: provider.statusFilter == null
                            ? 'No candidates have applied to this vacancy yet. Candidates will appear here as they submit their applications.'
                            : 'No applicants match the selected status filter.',
                        actionLabel: provider.statusFilter != null ? 'Clear Filter' : null,
                        actionIcon: Icons.clear_all_rounded,
                        onAction: () => provider.setStatusFilter(null),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: provider.applicants.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final app = provider.applicants[index];
                          return _buildApplicantCard(context, app);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantCard(BuildContext context, JobApplication app) {
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
                    app.candidateName.isNotEmpty
                        ? app.candidateName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.candidateName, style: AppTypography.headlineSmall),
                      if (app.candidateHeadline != null &&
                          app.candidateHeadline!.isNotEmpty)
                        Text(
                          app.candidateHeadline!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                StatusBadge(status: app.status.toShortString()),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () => _showActionDialog(context, app),
                ),
              ],
            ),
            const Divider(height: 20),

            // Contact and CV row
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    app.candidateEmail,
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _downloadOrViewCv(context, app.cvUrl, app.cvFileName),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.file_download_outlined, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              app.cvFileName.isNotEmpty ? app.cvFileName : 'Candidate_CV.pdf',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (app.coverLetter != null && app.coverLetter!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${app.coverLetter}"',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            // Phase 10: AI Match & Fit Score Section
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: app.overallFitScore != null
                    ? AppColors.secondary.withValues(alpha: 0.06)
                    : Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: app.overallFitScore != null
                      ? AppColors.secondary.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: app.overallFitScore != null
                        ? AppColors.secondary
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  if (app.overallFitScore != null) ...[
                    Text(
                      'AI Fit: ${app.overallFitScore}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                    if (app.aiRecommendation != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${app.aiRecommendation!.replaceAll('_', ' ')})',
                        style: TextStyle(
                          fontSize: 11,
                          color: _getRecommendationColor(app.aiRecommendation!),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ] else ...[
                    const Text(
                      'AI Analysis: Not yet analyzed',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      if (app.aiParsedCv != null) {
                        _showAiInsightsSheet(context, app);
                      } else {
                        _showActionDialog(context, app);
                      }
                    },
                    child: Text(
                      app.aiParsedCv != null ? 'View Details' : 'Analyze Now',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Top Performer & Exam Result Banner (if exam completed/scored)
            if (app.examScore != null || app.hasPassedExam || app.status == ApplicationStatus.passed || app.status == ApplicationStatus.failed) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: app.isTopPerformer
                      ? Colors.amber.withValues(alpha: 0.12)
                      : (app.status == ApplicationStatus.failed ? AppColors.error.withValues(alpha: 0.08) : AppColors.info.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: app.isTopPerformer
                        ? Colors.amber.shade700
                        : (app.status == ApplicationStatus.failed ? AppColors.error : AppColors.info),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      app.isTopPerformer ? Icons.emoji_events_rounded : Icons.scoreboard_outlined,
                      color: app.isTopPerformer ? Colors.amber.shade800 : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.isTopPerformer
                                ? '🏆 Top Performer (${app.examScore?.toStringAsFixed(0) ?? "100"}% - Passed)'
                                : 'Exam Score: ${app.examScore?.toStringAsFixed(0) ?? "0"}% (${app.status.displayName})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: app.isTopPerformer ? Colors.amber.shade900 : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            app.examTitle ?? 'Online Assessment',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (app.status != ApplicationStatus.selected && app.status != ApplicationStatus.rejected) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          backgroundColor: app.isTopPerformer ? const Color(0xFF047857) : AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.star_rounded, size: 14),
                        label: Text(
                          app.isTopPerformer ? 'Nominate (ترشيح)' : 'Select',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (cCtx) => AlertDialog(
                              title: Text('Nominate ${app.candidateName}?'),
                              content: Text(
                                'Nominate / Shortlist candidate for this position based on their exam performance (${app.examScore?.toStringAsFixed(0) ?? "Passed"}%)?',
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(cCtx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                                  onPressed: () => Navigator.pop(cCtx, true),
                                  child: const Text('Confirm Nomination'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            await context.read<CompanyApplicantsProvider>().updateApplicantStatus(
                              app.id,
                              ApplicationStatus.selected,
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Assessment Quick Status & Action Row
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: app.hasExamAssigned
                    ? AppColors.primary.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: app.hasExamAssigned
                      ? AppColors.primary.withValues(alpha: 0.25)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    app.hasExamAssigned ? Icons.verified_user_outlined : Icons.assignment_outlined,
                    size: 16,
                    color: app.hasExamAssigned ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      app.hasExamAssigned
                          ? 'Assessment: ${app.examTitle ?? "Online Test"}'
                          : 'No Assessment Assigned (لم يتم تعيين امتحان)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: app.hasExamAssigned ? AppColors.primary : AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      backgroundColor: app.hasExamAssigned ? AppColors.primary : AppColors.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      if (app.hasExamAssigned) {
                        _showExamDetailsDialog(context, app);
                      } else {
                        _showAssignExamDialog(context, app);
                      }
                    },
                    child: Text(
                      app.hasExamAssigned ? 'View Key' : '⚡ Assign',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
