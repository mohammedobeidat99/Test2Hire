import 'package:flutter/material.dart';
import 'package:mobile_app/core/constants/app_colors.dart';
import 'package:mobile_app/core/constants/app_typography.dart';
import 'package:mobile_app/features/ai_assistant/presentation/providers/ai_assistant_provider.dart';
import 'package:provider/provider.dart';

class CandidateComparisonScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final List<String> candidateAppIds;

  const CandidateComparisonScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.candidateAppIds,
  });

  @override
  State<CandidateComparisonScreen> createState() => _CandidateComparisonScreenState();
}

class _CandidateComparisonScreenState extends State<CandidateComparisonScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.candidateAppIds.length >= 2) {
        context.read<AiAssistantProvider>().compareCandidates(
              applicationIds: widget.candidateAppIds,
              jobId: widget.jobId,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('مقارنة المرشحين الذكية', style: TextStyle(fontSize: 16)),
            Text(
              widget.jobTitle,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Consumer<AiAssistantProvider>(
        builder: (context, provider, _) {
          if (provider.isComparing) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'جاري تحليل ومقارنة المرشحين بواسطة الذكاء الاصطناعي...',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          final comparison = provider.activeComparison;

          if (comparison == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      provider.errorMessage != null
                          ? Icons.error_outline_rounded
                          : Icons.compare_arrows_rounded,
                      size: 64,
                      color: provider.errorMessage != null ? AppColors.error : AppColors.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage != null
                          ? 'تعذر إجراء المقارنة الذكية'
                          : 'لم يتم إجراء مقارنة بعد',
                      style: AppTypography.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.errorMessage ??
                          'يرجى تحديد مرشحين على الأقل لإجراء المقارنة التنافسية المباشرة.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    if (provider.errorMessage != null && widget.candidateAppIds.length >= 2) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => provider.compareCandidates(
                          applicationIds: widget.candidateAppIds,
                          jobId: widget.jobId,
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Winner Announcement Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF047857),
                        const Color(0xFF10B981).withValues(alpha: 0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF047857).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'توصية التوظيف الأولى (AI Top Choice)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        comparison.winnerCandidateName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        comparison.comparativeRationale,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      if (comparison.keyDifferentiators.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 12),
                        ...comparison.keyDifferentiators.map((diff) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.star, color: Colors.amberAccent, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      diff,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'المقارنة جنباً إلى جنب (Side-by-Side Metrics)',
                  style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Side-by-side Candidate Cards
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: comparison.candidates.map((cand) {
                      final isWinner = cand.applicationId == comparison.winnerCandidateId;
                      return Container(
                        width: 240,
                        margin: const EdgeInsetsDirectional.only(end: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isWinner ? const Color(0xFF047857) : AppColors.border,
                            width: isWinner ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isWinner)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF047857).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '★ الفائز التنافسي',
                                  style: TextStyle(
                                    color: Color(0xFF047857),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            Text(
                              cand.candidateName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'الترتيب: #${cand.ranking}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 14),
                            _buildMetricRow('المعدل الكلي', '${cand.compositeScore}%', isWinner),
                            const SizedBox(height: 8),
                            _buildMetricRow('مطابقة السيرة', '${cand.cvMatchScore}%', false),
                            const SizedBox(height: 8),
                            _buildMetricRow('الاختبار التقني', '${cand.examScore}%', false),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, bool highlight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: highlight ? const Color(0xFF047857) : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
