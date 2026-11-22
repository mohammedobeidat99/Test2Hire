import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bgColor, textColor) = _resolveStatusTheme(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (String, Color, Color) _resolveStatusTheme(String status) {
    switch (status.toUpperCase()) {
      case 'APPLIED':
        return ('Applied', const Color(0xFFE0F2FE), const Color(0xFF0369A1));
      case 'UNDER_REVIEW':
        return ('Under Review', const Color(0xFFFEF3C7), const Color(0xFFB45309));
      case 'SHORTLISTED':
        return ('Shortlisted', const Color(0xFFE0E7FF), const Color(0xFF4338CA));
      case 'EXAM_PENDING':
      case 'EXAM_ASSIGNED':
        return ('Exam Assigned', const Color(0xFFEDE9FE), const Color(0xFF6D28D9));
      case 'EXAM_IN_PROGRESS':
        return ('Exam in Progress', const Color(0xFFE0E7FF), const Color(0xFF4338CA));
      case 'EXAM_COMPLETED':
      case 'COMPLETED':
        return ('Exam Completed', const Color(0xFFF1F5F9), const Color(0xFF475569));
      case 'PASSED':
        return ('Passed', const Color(0xFFDCFCE7), const Color(0xFF15803D));
      case 'FAILED':
      case 'TERMINATED':
      case 'TERMINATED_VIOLATION':
        return ('Failed', const Color(0xFFFEE2E2), const Color(0xFFB91C1C));
      case 'INTERVIEW_INVITED':
        return ('Interview Invited', const Color(0xFFFCE7F3), const Color(0xFFBE185D));
      case 'INTERVIEW_SCHEDULED':
        return ('Interview Scheduled', const Color(0xFFCCFBF1), const Color(0xFF0F766E));
      case 'OFFER_EXTENDED':
        return ('Offer Extended', const Color(0xFFECFDF5), const Color(0xFF047857));
      case 'HIRED':
        return ('Hired', const Color(0xFFD1FAE5), const Color(0xFF065F46));
      case 'SELECTED':
        return ('Selected', const Color(0xFFD1FAE5), const Color(0xFF047857));
      case 'REJECTED':
        return ('Rejected', const Color(0xFFFEE2E2), const Color(0xFF991B1B));
      case 'WITHDRAWN':
        return ('Withdrawn', const Color(0xFFF3F4F6), const Color(0xFF4B5563));
      case 'OPEN':
      case 'PUBLISHED':
        return ('Published', const Color(0xFFDCFCE7), const Color(0xFF15803D));
      case 'DRAFT':
        return ('Draft', const Color(0xFFFEF3C7), const Color(0xFFB45309));
      case 'CLOSED':
        return ('Closed', const Color(0xFFFEE2E2), const Color(0xFF991B1B));
      case 'ARCHIVED':
        return ('Archived', const Color(0xFFF1F5F9), const Color(0xFF475569));
      default:
        return (status, AppColors.divider, AppColors.textSecondary);
    }
  }
}
