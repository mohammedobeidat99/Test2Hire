import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/app_routes.dart';
import 'package:mobile_app/core/constants/app_colors.dart';
import 'package:mobile_app/core/constants/app_typography.dart';
import 'package:mobile_app/features/evaluation/domain/entities/candidate_scorecard.dart';
import 'package:mobile_app/features/evaluation/presentation/providers/evaluation_provider.dart';
import 'package:provider/provider.dart';

class JobApplicantsRankingScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;

  const JobApplicantsRankingScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<JobApplicantsRankingScreen> createState() => _JobApplicantsRankingScreenState();
}

class _JobApplicantsRankingScreenState extends State<JobApplicantsRankingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EvaluationProvider>().listenJobRankings(widget.jobId);
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
            const Text('ترتيب وتصنيف المتقدمين', style: TextStyle(fontSize: 16)),
            Text(
              widget.jobTitle,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          Consumer<EvaluationProvider>(
            builder: (context, provider, _) {
              final topCandidates = provider.jobRankings.take(3).toList();
              if (topCandidates.length < 2) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.compare_arrows_rounded, color: AppColors.primary),
                tooltip: 'مقارنة المتصدرين الذكية (AI Compare)',
                onPressed: () {
                  final appIds = topCandidates.map((c) => c.applicationId).join(',');
                  context.push(
                    '${AppRoutes.candidateComparison.replaceAll(':id', widget.jobId)}?jobTitle=${Uri.encodeComponent(widget.jobTitle)}&appIds=$appIds',
                  );
                },
              );
            },
          ),
          Consumer<EvaluationProvider>(
            builder: (context, evalProvider, _) => IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'إعادة الترتيب التلقائي',
              onPressed: evalProvider.isLoading || evalProvider.isCalculating
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await evalProvider.recalculateJobRankings(widget.jobId);
                      if (!mounted) return;
                      if (evalProvider.errorMessage != null) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(evalProvider.errorMessage!),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      } else if (evalProvider.successMessage != null) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(evalProvider.successMessage!),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
            ),
          ),
        ],
      ),
      body: Consumer<EvaluationProvider>(
        builder: (context, provider, _) {
          final rankings = provider.jobRankings;

          return Column(
            children: [
              // Filters Header: Sort & Recommendation Pills
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sort Chips
                    Row(
                      children: [
                        const Text(
                          'ترتيب حسب: ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildSortChip(
                                  label: 'المعدل الكلي',
                                  filter: RankingSortFilter.compositeScore,
                                  provider: provider,
                                ),
                                const SizedBox(width: 8),
                                _buildSortChip(
                                  label: 'السيرة الذاتية',
                                  filter: RankingSortFilter.cvMatch,
                                  provider: provider,
                                ),
                                const SizedBox(width: 8),
                                _buildSortChip(
                                  label: 'الاختبار التقني',
                                  filter: RankingSortFilter.examScore,
                                  provider: provider,
                                ),
                                const SizedBox(width: 8),
                                _buildSortChip(
                                  label: 'المقابلة',
                                  filter: RankingSortFilter.interviewScore,
                                  provider: provider,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.getJobRankings(widget.jobId),
                  child: provider.isLoading && rankings.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      : rankings.isEmpty && provider.errorMessage != null
                          ? LayoutBuilder(
                              builder: (context, constraints) => SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            size: 48,
                                            color: AppColors.error,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            provider.errorMessage!,
                                            textAlign: TextAlign.center,
                                            style: AppTypography.bodySmall.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                provider.getJobRankings(widget.jobId),
                                            icon: const Icon(Icons.refresh),
                                            label: const Text('إعادة المحاولة'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : rankings.isEmpty
                              ? LayoutBuilder(
                                  builder: (context, constraints) =>
                                      SingleChildScrollView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.leaderboard_outlined,
                                                size: 64,
                                                color: AppColors.textTertiary,
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'لا توجد بطاقات أداء محتسبة بعد',
                                                style: AppTypography.titleLarge,
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'يمكنك احتساب بطاقات الأداء من شاشة المتقدمين (Applicants).',
                                                style:
                                                    AppTypography.bodySmall.copyWith(
                                                  color: AppColors.textSecondary,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: rankings.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = rankings[index];
                                    final rank = index + 1;
                                    return _buildRankingCard(context, item, rank);
                                  },
                                ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSortChip({
    required String label,
    required RankingSortFilter filter,
    required EvaluationProvider provider,
  }) {
    final isSelected = provider.sortFilter == filter;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      onSelected: (_) => provider.setSortFilter(filter),
    );
  }

  Widget _buildRankingCard(
    BuildContext context,
    CandidateScorecard item,
    int displayRank,
  ) {
    final isTopThree = displayRank <= 3;
    final badgeColor = displayRank == 1
        ? const Color(0xFFD97706) // Gold
        : displayRank == 2
            ? const Color(0xFF64748B) // Silver
            : displayRank == 3
                ? const Color(0xFFB45309) // Bronze
                : AppColors.textTertiary;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        context.push(
          '${AppRoutes.scorecardDetail}/${item.applicationId}?candidateName=${Uri.encodeComponent(item.candidateName)}',
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTopThree ? badgeColor.withValues(alpha: 0.5) : AppColors.border,
            width: isTopThree ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rank Number Badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: badgeColor, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                '#$displayRank',
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Candidate Name & Recommendation
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.candidateName,
                    style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(item.recommendation.icon, size: 14, color: item.recommendation.color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          item.recommendation.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            color: item.recommendation.color,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Breakdown mini pills
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildMiniMetric('CV: ${item.breakdown.cvMatchScore}%'),
                      _buildMiniMetric('Exam: ${item.breakdown.examScore}%'),
                      _buildMiniMetric('Interview: ${item.breakdown.interviewScore}%'),
                    ],
                  ),
                ],
              ),
            ),

            // Composite Score
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.compositeScore}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: item.compositeScore >= 75 ? const Color(0xFF047857) : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'المعدل الكلي',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
    );
  }
}
