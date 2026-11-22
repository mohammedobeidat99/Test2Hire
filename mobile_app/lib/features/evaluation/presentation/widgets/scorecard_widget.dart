import 'package:flutter/material.dart';
import 'package:mobile_app/core/constants/app_colors.dart';
import 'package:mobile_app/core/constants/app_typography.dart';
import 'package:mobile_app/features/evaluation/domain/entities/candidate_scorecard.dart';

class ScorecardWidget extends StatelessWidget {
  final CandidateScorecard scorecard;
  final VoidCallback? onRecalculate;
  final bool isRecalculating;

  const ScorecardWidget({
    super.key,
    required this.scorecard,
    this.onRecalculate,
    this.isRecalculating = false,
  });

  @override
  Widget build(BuildContext context) {
    final recommendation = scorecard.recommendation;
    final breakdown = scorecard.breakdown;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & Overall Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: recommendation.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(recommendation.icon, color: recommendation.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scorecard.candidateName,
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scorecard.candidateEmail,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Composite Score Circular Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _getScoreColor(scorecard.compositeScore).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getScoreColor(scorecard.compositeScore).withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${scorecard.compositeScore}%',
                      style: AppTypography.titleLarge.copyWith(
                        color: _getScoreColor(scorecard.compositeScore),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'المعدل الكلي',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getScoreColor(scorecard.compositeScore),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 18),

          // Recommendation & Ranking Banner
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: recommendation.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(recommendation.icon, color: recommendation.color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recommendation.displayName,
                          style: TextStyle(
                            color: recommendation.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (scorecard.ranking != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.leaderboard_outlined, color: AppColors.primary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'الترتيب: #${scorecard.ranking}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),
          Text(
            'تفصيل محاور التقييم (Evaluation Breakdown)',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          // Component Progress Bars
          _buildScoreBar(
            title: 'مطابقة السيرة الذاتية (CV Match)',
            weightText: '${(scorecard.weights.cvMatchWeight * 100).toInt()}%',
            score: breakdown.cvMatchScore,
            color: AppColors.primary,
            icon: Icons.description_outlined,
          ),
          const SizedBox(height: 12),

          _buildScoreBar(
            title: 'نتيجة الاختبار التقني (Exam)',
            weightText: '${(scorecard.weights.examScoreWeight * 100).toInt()}%',
            score: breakdown.examScore,
            color: AppColors.accent,
            icon: Icons.quiz_outlined,
          ),
          const SizedBox(height: 12),

          _buildScoreBar(
            title: 'تقييم المقابلة (Interview)',
            weightText: '${(scorecard.weights.interviewWeight * 100).toInt()}%',
            score: breakdown.interviewScore,
            color: const Color(0xFF10B981),
            icon: Icons.groups_outlined,
          ),

          if (onRecalculate != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isRecalculating ? null : onRecalculate,
                icon: isRecalculating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(isRecalculating ? 'جاري التحديث...' : 'إعادة حساب بطاقة الأداء'),
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

  Widget _buildScoreBar({
    required String title,
    required String weightText,
    required int score,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'الوزن: $weightText',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$score%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0),
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF047857);
    if (score >= 65) return AppColors.primary;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }
}
