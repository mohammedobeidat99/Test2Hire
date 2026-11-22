import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:mobile_app/core/constants/app_colors.dart';
import 'package:mobile_app/core/constants/app_typography.dart';
import 'package:mobile_app/core/services/url_launcher_helper.dart';
import 'package:mobile_app/l10n/generated/app_localizations.dart';
import 'package:mobile_app/features/assessments/domain/entities/take_home_challenge.dart';
import 'package:mobile_app/features/assessments/presentation/providers/assessments_hub_provider.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class TakeHomeChallengeDetailScreen extends StatefulWidget {
  final String challengeId;

  const TakeHomeChallengeDetailScreen({
    super.key,
    required this.challengeId,
  });

  @override
  State<TakeHomeChallengeDetailScreen> createState() =>
      _TakeHomeChallengeDetailScreenState();
}

class _TakeHomeChallengeDetailScreenState
    extends State<TakeHomeChallengeDetailScreen> {
  final _githubController = TextEditingController();
  final _demoController = TextEditingController();
  final _notesController = TextEditingController();

  String? _uploadedFileUrl;
  String? _uploadedFileName;
  bool _isUploadingFile = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AssessmentsHubProvider>();
      final user = context.read<AuthProvider>().user;
      provider.loadChallengeById(widget.challengeId);
      if (user != null) {
        if (user.isCompany) {
          provider.listenChallengeSubmissions(widget.challengeId);
        } else {
          provider.listenCandidateSubmissions(user.uid);
        }
      }
    });
  }

  @override
  void dispose() {
    _githubController.dispose();
    _demoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAssignmentFile(String candidateId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'zip', 'docx', 'doc', 'png', 'jpg', 'jpeg', 'txt'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    // Validate max 15 MB
    if (file.size > 15 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File size exceeds the 15 MB maximum limit.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUploadingFile = true;
      _uploadProgress = 0.05;
    });

    try {
      final sanitized = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath =
          'assignment_submissions/${widget.challengeId}/${candidateId}_${DateTime.now().millisecondsSinceEpoch}_$sanitized';
      final ref = FirebaseStorage.instance.ref().child(storagePath);

      final ext = file.name.split('.').last.toLowerCase();
      String contentType = 'application/octet-stream';
      if (ext == 'zip') {
        contentType = 'application/zip';
      } else if (ext == 'pdf') {
        contentType = 'application/pdf';
      } else if (ext == 'docx') {
        contentType =
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      } else if (ext == 'doc') {
        contentType = 'application/msword';
      } else if (ext == 'txt') {
        contentType = 'text/plain';
      } else if (ext == 'png') {
        contentType = 'image/png';
      } else if (ext == 'jpg' || ext == 'jpeg') {
        contentType = 'image/jpeg';
      }
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'candidateId': candidateId,
          'challengeId': widget.challengeId,
        },
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
        throw Exception('Unable to read selected file.');
      }

      task.snapshotEvents.listen((snap) {
        if (!mounted) return;
        final total = snap.totalBytes > 0 ? snap.totalBytes : 1;
        setState(() {
          _uploadProgress = snap.bytesTransferred / total;
        });
      });

      final snap = await task;
      final downloadUrl = await snap.ref.getDownloadURL();

      if (!mounted) return;
      setState(() {
        _uploadedFileUrl = downloadUrl;
        _uploadedFileName = file.name;
        _isUploadingFile = false;
        if (_githubController.text.trim().isEmpty) {
          _githubController.text = downloadUrl;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploaded "${file.name}" successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingFile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _submitSolution(TakeHomeChallenge challenge) async {
    final primaryUrl = _githubController.text.trim().isNotEmpty
        ? _githubController.text.trim()
        : (_uploadedFileUrl ?? '');

    if (primaryUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please attach a solution file or provide a GitHub repository / solution link.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final combinedNotes = [
      if (_uploadedFileName != null)
        'Attached File: $_uploadedFileName ($_uploadedFileUrl)',
      if (_notesController.text.trim().isNotEmpty) _notesController.text.trim(),
    ].join('\n');

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final provider = context.read<AssessmentsHubProvider>();
    final ok = await provider.submitChallengeSolution(
      challengeId: challenge.id,
      companyId: challenge.companyId,
      candidateId: user.uid,
      candidateName: user.fullName,
      candidateEmail: user.email,
      githubRepoUrl: primaryUrl,
      liveDemoUrl: _demoController.text.trim().isEmpty
          ? _uploadedFileUrl
          : _demoController.text.trim(),
      candidateNotes: combinedNotes.isEmpty ? null : combinedNotes,
    );

    if (ok) {
      try {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': challenge.companyId,
          'title': 'New Assignment Submitted: ${challenge.title}',
          'body':
              '${user.fullName} submitted their solution for "${challenge.title}".',
          'type': 'GENERAL',
          'actionUrl': '/company/exams',
          'isRead': false,
          'data': {'senderId': user.uid},
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تم تسليم الواجب العملي بنجاح! تم إشعار صاحب العمل.' : 'Assignment submitted successfully! The employer has been notified.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to submit assignment. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n?.assignmentsTab ?? 'Assignment Details'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Consumer<AssessmentsHubProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.selectedChallenge == null) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          final challenge = provider.selectedChallenge;
          if (challenge == null) {
            if (provider.errorMessage != null) {
              return Center(
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
                            provider.loadChallengeById(widget.challengeId),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const Center(child: Text('Assignment not found.'));
          }

          final existingSubmission = provider.candidateSubmissions
              .where((s) => s.challengeId == challenge.id)
              .firstOrNull;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              challenge.difficulty.toShortString(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isArabic ? 'الموعد النهائي: ${challenge.deadlineDays} أيام' : 'Deadline: ${challenge.deadlineDays} Days',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        challenge.title,
                        style: AppTypography.headlineSmall
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isArabic ? 'مكلف من: ${challenge.companyName}' : 'Assigned by: ${challenge.companyName}',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        challenge.brief,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textPrimary),
                      ),
                      if (challenge.starterTemplateUrl != null &&
                          challenge.starterTemplateUrl!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () => UrlLauncherHelper.openUrl(
                            context,
                            challenge.starterTemplateUrl!,
                            successMessage: 'Opening reference materials...',
                          ),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: Text(isArabic ? 'تحميل الملفات والمراجع التأسيسية' : 'Download Reference / Starter Files'),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  l10n?.challengeInstructions ?? 'Detailed Instructions',
                  style:
                      AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    challenge.detailedInstructions,
                    style: AppTypography.bodyMedium.copyWith(height: 1.55),
                  ),
                ),

                // Deliverables
                if (challenge.deliverables.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    isArabic ? 'المخرجات والمتطلبات المطلوبة' : 'Required Deliverables',
                    style: AppTypography.titleLarge
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...challenge.deliverables.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded,
                                size: 18, color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                                child:
                                    Text(item, style: AppTypography.bodyMedium)),
                          ],
                        ),
                      )),
                ],

                // Rubrics
                if (challenge.rubrics.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    isArabic ? 'معايير التقييم والدرجات' : 'Evaluation Rubric',
                    style: AppTypography.titleLarge
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...challenge.rubrics.map((r) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  if (r.description.isNotEmpty)
                                    Text(
                                      r.description,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${r.maxPoints} pts',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],

                const SizedBox(height: 24),

                // Candidate Submission Box or Company Review List
                if (user != null && !user.isCompany)
                  _buildCandidateSubmissionCard(
                    challenge,
                    existingSubmission,
                    provider,
                    user.uid,
                  )
                else if (user != null && user.isCompany)
                  _buildCompanySubmissionsList(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCandidateSubmissionCard(
    TakeHomeChallenge challenge,
    ChallengeSubmission? existingSubmission,
    AssessmentsHubProvider provider,
    String candidateId,
  ) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (existingSubmission != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppColors.success),
                const SizedBox(width: 8),
                Text(
                  'Status: ${existingSubmission.status.toShortString()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Solution Link / File: ${existingSubmission.githubRepoUrl}',
              style: const TextStyle(fontSize: 12),
            ),
            if (existingSubmission.candidateNotes != null &&
                existingSubmission.candidateNotes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Notes: ${existingSubmission.candidateNotes}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            if (existingSubmission.score != null) ...[
              const SizedBox(height: 12),
              Text(
                'Final Score: ${existingSubmission.score!.toStringAsFixed(0)} / 100',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
            if (existingSubmission.reviewerFeedback != null &&
                existingSubmission.reviewerFeedback!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Reviewer Feedback: ${existingSubmission.reviewerFeedback}'),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'تسليم حل الواجب العملي' : 'Submit Your Assignment Solution',
            style:
                AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic ? 'ارفع ملف الحل (.pdf أو .zip أو .docx حتى 15 ميغابايت) أو زوّدنا برابط مستودع GitHub والنسخة التجريبية.' : 'Upload a solution archive/document (.pdf, .zip, .docx up to 15 MB) or provide your GitHub repository & live demo links.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // File Upload Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.upload_file_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _uploadedFileName ??
                            'No solution file attached yet (.pdf, .zip, .docx)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _uploadedFileName != null
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _uploadedFileName != null
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isUploadingFile
                          ? null
                          : () => _pickAndUploadAssignmentFile(candidateId),
                      icon: const Icon(Icons.attach_file_rounded, size: 16),
                      label: Text(
                        _uploadedFileName != null ? 'Replace' : (isArabic ? 'إرفاق ملف' : 'Attach File'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                if (_isUploadingFile) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: AppColors.border,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _githubController,
            decoration: InputDecoration(
              labelText: isArabic ? 'رابط مستودع GitHub أو ملف الحل *' : 'GitHub Repository or Solution File URL *',
              hintText: 'https://github.com/username/project-repo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _demoController,
            decoration: InputDecoration(
              labelText: isArabic ? 'رابط النسخة المباشرة (اختياري)' : 'Live Demo URL (Optional)',
              hintText: 'https://project-demo.vercel.app',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: isArabic ? 'ملاحظات التنفيذ وتعليمات التشغيل' : 'Implementation Notes & Instructions',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isUploadingFile || provider.isSubmitting)
                  ? null
                  : () => _submitSolution(challenge),
              icon: const Icon(Icons.send_rounded),
              label: Text(
                provider.isSubmitting
                    ? 'Submitting Assignment...'
                    : _isUploadingFile
                        ? 'Uploading File...'
                        : (l10n?.submitChallenge ?? 'Submit Final Assignment'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanySubmissionsList(AssessmentsHubProvider provider) {
    final submissions = provider.submissions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Candidate Submissions (${submissions.length})',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (submissions.isEmpty)
          const Text('No submissions received for this assignment yet.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              final sub = submissions[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.candidateName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Repo / File: ${sub.githubRepoUrl}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.primary)),
                    if (sub.liveDemoUrl != null)
                      Text('Demo: ${sub.liveDemoUrl}',
                          style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    Text('Status: ${sub.status.toShortString()}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
