import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/url_launcher_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/profile_provider.dart';

class CVUploadCard extends StatelessWidget {
  const CVUploadCard({super.key});

  Future<void> _pickAndUploadCV(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return; // User dismissed file picker
      }

      final file = result.files.first;
      Uint8List? fileBytes = file.bytes;

      // On Android/iOS, FilePicker often returns file.path instead of in-memory bytes
      if (!kIsWeb && fileBytes == null && file.path != null) {
        final localFile = File(file.path!);
        if (await localFile.exists()) {
          fileBytes = await localFile.readAsBytes();
        }
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read the selected document. Please try another file.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Max size limit (10MB)
      if (fileBytes.lengthInBytes > 10 * 1024 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File exceeds the 10MB limit. Please upload a smaller document.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        final profileProvider = context.read<ProfileProvider>();
        final success = await profileProvider.uploadCV(fileBytes, file.name);
        if (context.mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Resume / CV uploaded successfully.'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(profileProvider.errorMessage ?? 'Failed to upload CV. Please try again.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking/uploading CV: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;
    final hasCV = profile?.cvUrl != null && profile!.cvUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(l10n?.cvCardTitle ?? 'Curriculum Vitae (CV)', style: AppTypography.titleLarge),
                ],
              ),
              if (hasCV)
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          if (hasCV) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.cvFileName ?? 'Candidate_Resume.pdf',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(l10n?.cvReadyForApplications ?? 'Ready for job applications', style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: AppColors.primary, size: 22),
                    tooltip: 'Download / View Resume',
                    onPressed: () => UrlLauncherHelper.openUrl(
                      context,
                      profile.cvUrl ?? '',
                      successMessage: 'Opening CV / Resume...',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                    tooltip: 'Delete Resume',
                    onPressed: profileProvider.isSaving
                        ? null
                        : () async {
                            final ok = await profileProvider.deleteCV();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Resume removed.'
                                      : (profileProvider.errorMessage ??
                                          'Failed to delete resume.'),
                                ),
                                backgroundColor:
                                    ok ? AppColors.success : AppColors.error,
                              ),
                            );
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: l10n?.downloadResume ?? 'Download CV',
                    variant: AppButtonVariant.outline,
                    icon: Icons.download_rounded,
                    onPressed: () => UrlLauncherHelper.openUrl(
                      context,
                      profile.cvUrl ?? '',
                      successMessage: 'Opening CV / Resume...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    text: l10n?.replaceResume ?? 'Replace CV',
                    variant: AppButtonVariant.primary,
                    icon: Icons.upload_file_rounded,
                    isLoading: profileProvider.isSaving,
                    onPressed: () => _pickAndUploadCV(context),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              l10n?.uploadResumePrompt ?? 'Upload your CV in PDF format (Max 10MB). Having an attached resume is required when applying for jobs.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            AppButton(
              text: l10n?.uploadResume ?? 'Upload Resume / CV',
              icon: Icons.upload_file_rounded,
              isLoading: profileProvider.isSaving,
              onPressed: () => _pickAndUploadCV(context),
            ),
          ],
        ],
      ),
    );
  }
}
