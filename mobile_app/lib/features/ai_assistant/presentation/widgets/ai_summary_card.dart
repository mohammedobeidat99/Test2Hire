import 'package:flutter/material.dart';
import 'package:mobile_app/core/constants/app_colors.dart';
import 'package:mobile_app/core/constants/app_typography.dart';
import 'package:mobile_app/features/ai_assistant/domain/entities/candidate_ai_summary.dart';

class AiSummaryCard extends StatelessWidget {
  final CandidateAiSummary summary;
  final VoidCallback? onRegenerate;
  final bool isRegenerating;

  const AiSummaryCard({
    super.key,
    required this.summary,
    this.onRegenerate,
    this.isRegenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    final decision = summary.recommendationDecision;
    final risk = summary.hiringRisk;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with AI Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التحليل التنفيذي الذكي (Gemini AI)',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'دقة التحليل: ${summary.confidenceScore}% ثقة',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Decision Badge
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: decision.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: decision.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(decision.icon, size: 14, color: decision.color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          decision.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: decision.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Risk Level Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: risk.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: risk.color),
                const SizedBox(width: 6),
                Text(
                  risk.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: risk.color,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          // Summary text
          Text(
            summary.summaryText,
            style: AppTypography.bodyMedium.copyWith(
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Key Strengths
          if (summary.keyStrengths.isNotEmpty) ...[
            Text(
              'أبرز نقاط القوة التنافسية (Key Strengths)',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...summary.keyStrengths.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
          ],

          // Potential Red Flags
          if (summary.potentialRedFlags.isNotEmpty) ...[
            Text(
              'الفجوات المحتملة ونقاط الحذر (Potential Flags)',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...summary.potentialRedFlags.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
          ],

          // Suggested Questions
          if (summary.suggestedQuestions.isNotEmpty) ...[
            Text(
              'أسئلة مقابلة مقترحة موجهة (Tailored Interview Questions)',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...summary.suggestedQuestions.map((q) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.help_outline, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          q,
                          style: AppTypography.bodySmall.copyWith(
                            fontStyle: FontStyle.italic,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          if (onRegenerate != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isRegenerating ? null : onRegenerate,
                icon: isRegenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(isRegenerating ? 'جاري التحليل...' : 'تحديث التحليل الذكي'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
