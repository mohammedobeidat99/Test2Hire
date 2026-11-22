import 'package:flutter/material.dart';
import 'package:mobile_app/core/constants/app_colors.dart';
import 'package:mobile_app/core/constants/app_typography.dart';
import 'package:mobile_app/features/ai_assistant/presentation/providers/ai_assistant_provider.dart';
import 'package:mobile_app/features/ai_assistant/presentation/widgets/ai_summary_card.dart';
import 'package:mobile_app/features/evaluation/domain/entities/candidate_scorecard.dart';
import 'package:mobile_app/features/evaluation/presentation/providers/evaluation_provider.dart';
import 'package:mobile_app/features/evaluation/presentation/widgets/scorecard_widget.dart';
import 'package:provider/provider.dart';

class ScorecardDetailScreen extends StatefulWidget {
  final String applicationId;
  final String candidateName;

  const ScorecardDetailScreen({
    super.key,
    required this.applicationId,
    required this.candidateName,
  });

  @override
  State<ScorecardDetailScreen> createState() => _ScorecardDetailScreenState();
}

class _ScorecardDetailScreenState extends State<ScorecardDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EvaluationProvider>().listenScorecard(widget.applicationId);
      context.read<AiAssistantProvider>().listenAiSummary(widget.applicationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('بطاقة تقييم: ${widget.candidateName}'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Consumer<EvaluationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.activeScorecard == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final scorecard = provider.activeScorecard;

          if (scorecard == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.analytics_outlined, size: 64, color: AppColors.textTertiary),
                    const SizedBox(height: 16),
                    Text(
                      'لم يتم احتساب بطاقة التقييم بعد',
                      style: AppTypography.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'اضغط على الزر أدناه لتجميع نتائج السيرة الذاتية والاختبارات والمقابلات وحساب الترتيب آلياً.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: provider.isCalculating
                          ? null
                          : () {
                              provider.calculateScorecard(
                                applicationId: widget.applicationId,
                              );
                            },
                      icon: provider.isCalculating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.calculate_outlined),
                      label: const Text('حساب بطاقة الأداء الآن'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
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
                ScorecardWidget(
                  scorecard: scorecard,
                  isRecalculating: provider.isCalculating,
                  onRecalculate: () {
                    provider.calculateScorecard(
                      applicationId: widget.applicationId,
                    );
                  },
                ),
                const SizedBox(height: 24),
                // AI Summary Card & Generator (Phase 15)
                Consumer<AiAssistantProvider>(
                  builder: (context, aiProvider, _) {
                    final aiSummary = aiProvider.activeSummary;
                    if (aiProvider.isGenerating) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: AppColors.primary),
                              SizedBox(height: 12),
                              Text('جاري إعداد التحليل الذكي بواسطة Gemini AI...'),
                            ],
                          ),
                        ),
                      );
                    }

                    if (aiSummary != null) {
                      return AiSummaryCard(
                        summary: aiSummary,
                        isRegenerating: aiProvider.isGenerating,
                        onRegenerate: () {
                          aiProvider.generateCandidateAiSummary(widget.applicationId);
                        },
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'التحليل التنفيذي وتوليد الأسئلة الذكية',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  'احصل على تقرير نقاط القوة والمخاطر وأسئلة المقابلة المقترحة.',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              aiProvider.generateCandidateAiSummary(widget.applicationId);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('تحليل AI'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Quick hiring recommendation guidance box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'توصيات قرار التوظيف',
                            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _getGuidanceText(scorecard.recommendation),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getGuidanceText(ScorecardRecommendation rec) {
    switch (rec) {
      case ScorecardRecommendation.stronglyRecommended:
        return 'المرشح حقق درجات استثنائية عبر كافة محاور التقييم (80% فما فوق). يوصى بتقديم عرض عمل فوري (Job Offer) للمرشح.';
      case ScorecardRecommendation.recommended:
        return 'المرشح مؤهل جداً وحقق متطلبات الدور الوظيفي بنجاح (65% فما فوق). مناسب جداً للخطوة التالية.';
      case ScorecardRecommendation.neutral:
        return 'أداء المرشح متوسط أو لم تكتمل كافة مراحل التقييم بعد (كالمقابلة الشخصية). يرجى استكمال التقييم أو مراجعة التفاصيل.';
      case ScorecardRecommendation.notRecommended:
        return 'المعدل التراكمي للمرشح يقل عن الحد الأدنى المطلوب لهذه الوظيفة. يوصى بالاعتذار وتغيير الحالة إلى مرفوض.';
    }
  }
}
