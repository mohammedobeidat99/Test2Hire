import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/candidate_profile.dart';

class ProfileCompletionCard extends StatelessWidget {
  final CandidateProfile profile;

  const ProfileCompletionCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percentage = profile.completionPercentage;
    final isComplete = percentage >= 70;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete ? AppColors.success.withValues(alpha: 0.3) : AppColors.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isComplete ? Icons.verified_rounded : Icons.pending_actions_rounded,
                    color: isComplete ? AppColors.success : AppColors.warning,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n?.profileStrength ?? 'Profile Strength',
                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                '$percentage%',
                style: AppTypography.headlineSmall.copyWith(
                  color: isComplete ? AppColors.success : AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 10,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isComplete
                ? (l10n?.profileCompleteSuccess ?? 'Great job! Your profile meets the requirements to apply for jobs and take examinations.')
                : (l10n?.profileIncompletePrompt ?? 'Complete required sections (CV, Skills, Education) to reach at least 70% profile completeness.'),
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
