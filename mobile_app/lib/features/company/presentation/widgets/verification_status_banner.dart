import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/entities/company_profile.dart';

class VerificationStatusBanner extends StatelessWidget {
  final CompanyProfile company;

  const VerificationStatusBanner({super.key, required this.company});

  @override
  Widget build(BuildContext context) {
    switch (company.verificationStatus) {
      case CompanyVerificationStatus.approved:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF15803D), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verified Employer',
                      style: AppTypography.labelLarge.copyWith(color: const Color(0xFF14532D)),
                    ),
                    Text(
                      'Your company account is verified. You have full access to publish jobs and assess candidates.',
                      style: AppTypography.bodySmall.copyWith(color: const Color(0xFF166534)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case CompanyVerificationStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: Color(0xFFB45309), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification In Review',
                      style: AppTypography.labelLarge.copyWith(color: const Color(0xFF78350F)),
                    ),
                    Text(
                      'Admins are reviewing your company profile. You can prepare question banks and exam drafts now.',
                      style: AppTypography.bodySmall.copyWith(color: const Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case CompanyVerificationStatus.rejected:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cancel_rounded, color: AppColors.error, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Declined',
                      style: AppTypography.labelLarge.copyWith(color: const Color(0xFF7F1D1D)),
                    ),
                    Text(
                      company.verificationNotes?.isNotEmpty ?? false
                          ? 'Reason: ${company.verificationNotes}'
                          : 'Please update your company details with official documentation to request re-review.',
                      style: AppTypography.bodySmall.copyWith(color: const Color(0xFF991B1B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case CompanyVerificationStatus.suspended:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Row(
            children: [
              const Icon(Icons.block_rounded, color: Colors.black87, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Company account is currently suspended. Please contact platform administration.',
                  style: AppTypography.bodySmall.copyWith(color: Colors.black87),
                ),
              ),
            ],
          ),
        );
    }
  }
}
