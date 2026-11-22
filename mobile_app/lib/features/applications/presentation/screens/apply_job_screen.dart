import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../jobs/domain/entities/job_posting.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/candidate_applications_provider.dart';

class ApplyJobScreen extends StatefulWidget {
  final JobPosting job;

  const ApplyJobScreen({super.key, required this.job});

  @override
  State<ApplyJobScreen> createState() => _ApplyJobScreenState();
}

class _ApplyJobScreenState extends State<ApplyJobScreen> {
  final TextEditingController _coverLetterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null && context.read<ProfileProvider>().profile == null) {
        context.read<ProfileProvider>().loadProfile(uid);
      }
    });
  }

  @override
  void dispose() {
    _coverLetterController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final authUser = context.read<AuthProvider>().user;
    var candidateProfile = context.read<ProfileProvider>().profile;
    final appsProvider = context.read<CandidateApplicationsProvider>();

    if (authUser == null) return;

    if (candidateProfile == null) {
      await context.read<ProfileProvider>().loadProfile(authUser.uid);
      if (!mounted) return;
      candidateProfile = context.read<ProfileProvider>().profile;
    }

    if (candidateProfile == null) {
      final profileErr = context.read<ProfileProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(profileErr ?? 'Could not load your profile. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final cvUrl = candidateProfile.cvUrl;
    final cvName = candidateProfile.cvFileName ?? 'Resume.pdf';

    if (cvUrl == null || cvUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'يرجى رفع سيرتك الذاتية في ملفك الشخصي أولاً.' : 'Please upload your CV in your profile before applying.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final appId = await appsProvider.submitApplication(
      jobId: widget.job.id,
      jobTitle: widget.job.title,
      companyId: widget.job.companyId,
      companyName: widget.job.companyName,
      companyLogoUrl: widget.job.companyLogoUrl,
      candidateId: authUser.uid,
      candidateName: candidateProfile.fullName,
      candidateEmail: candidateProfile.email,
      candidatePhone: candidateProfile.phoneNumber,
      candidateHeadline: candidateProfile.headline,
      candidatePhotoUrl: candidateProfile.photoUrl,
      cvUrl: cvUrl,
      cvFileName: cvName,
      coverLetter: _coverLetterController.text.trim().isNotEmpty
          ? _coverLetterController.text.trim()
          : null,
    );

    if (appId != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 28),
              SizedBox(width: 8),
              Text('Application Sent!'),
            ],
          ),
          content: Text(
            'Your application for "${widget.job.title}" has been successfully submitted to ${widget.job.companyName}. You can track your progress under My Applications.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dCtx);
                context.pop();
                context.push('/candidate/applications');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'عرض طلباتي' : 'View My Applications'),
            ),
          ],
        ),
      );
    } else if (appsProvider.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appsProvider.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final candidateProfile = context.watch<ProfileProvider>().profile;
    final appsProvider = context.watch<CandidateApplicationsProvider>();
    final completion = candidateProfile?.completionPercentage ?? 0;
    final hasCV = candidateProfile?.cvUrl != null && candidateProfile!.cvUrl!.isNotEmpty;
    final isEligible = completion >= 70 && hasCV;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'التقديم على الوظيفة' : 'Apply for Vacancy'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Job Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: (widget.job.companyLogoUrl != null && widget.job.companyLogoUrl!.trim().isNotEmpty)
                        ? AppSafeImage(
                            url: widget.job.companyLogoUrl!,
                            width: 48,
                            height: 48,
                            borderRadius: BorderRadius.circular(10),
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Center(
                              child: Text(
                                widget.job.companyName.trim().isNotEmpty
                                    ? widget.job.companyName.trim()[0].toUpperCase()
                                    : 'C',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              widget.job.companyName.trim().isNotEmpty
                                      ? widget.job.companyName.trim()[0].toUpperCase()
                                      : 'C',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.job.title, style: AppTypography.headlineSmall),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.job.companyName} • ${widget.job.location.formatted}',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Verification Checklist
            Text(isArabic ? 'ملخص الملف الشخصي' : 'Applicant Profile Summary', style: AppTypography.headlineSmall),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isEligible
                    ? AppColors.success.withValues(alpha: 0.06)
                    : AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEligible
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isEligible ? Icons.verified_user : Icons.warning_amber_rounded,
                        color: isEligible ? AppColors.success : AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEligible ? (isArabic ? 'الملف الشخصي جاهز للتقديم' : 'Profile Ready for Application') : (isArabic ? 'يتطلب الملف استكمال البيانات' : 'Profile Requires Attention'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isEligible ? AppColors.success : AppColors.warning,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$completion% ${isArabic ? "مكتمل" : "Complete"}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isEligible ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildCheckItem(
                    isArabic ? 'الاسم الكامل:' : 'Full Name:',
                    candidateProfile?.fullName ?? 'Not provided',
                    candidateProfile?.fullName.isNotEmpty ?? false,
                  ),
                  const SizedBox(height: 6),
                  _buildCheckItem(
                    isArabic ? 'البريد الإلكتروني:' : 'Email Address:',
                    candidateProfile?.email ?? 'Not provided',
                    candidateProfile?.email.isNotEmpty ?? false,
                  ),
                  const SizedBox(height: 6),
                  _buildCheckItem(
                    isArabic ? 'السيرة الذاتية:' : 'Attached CV / Resume:',
                    hasCV ? (candidateProfile.cvFileName ?? 'Attached') : 'No CV Uploaded',
                    hasCV,
                  ),
                ],
              ),
            ),

            if (!isEligible) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/profile'),
                icon: const Icon(Icons.edit, size: 16),
                label: Text(isArabic ? 'استكمال الملف ورفع السيرة الذاتية' : 'Complete Profile & Upload CV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Optional Cover Letter
            Text(isArabic ? 'رسالة تعريفية (اختياري)' : 'Cover Letter (Optional)', style: AppTypography.headlineSmall),
            const SizedBox(height: 8),
            AppTextField(
              controller: _coverLetterController,
              hint: isArabic ? 'عرّف بنفسك واذكر سبب كونك المرشح الأنسب لهذه الوظيفة...' : 'Introduce yourself and share why you are the ideal fit for this role...',
              maxLines: 5,
            ),
            const SizedBox(height: 32),

            // Submit Button
            AppButton(
              text: isArabic ? 'تأكيد وإرسال طلب التوظيف' : 'Confirm & Submit Application',
              isLoading: appsProvider.isSubmitting,
              onPressed: isEligible ? _handleSubmit : null,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String label, String value, bool isOk) {
    return Row(
      children: [
        Icon(
          isOk ? Icons.check : Icons.close,
          size: 14,
          color: isOk ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
