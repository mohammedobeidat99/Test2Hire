import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../company/presentation/providers/company_provider.dart';
import '../../domain/entities/hiring_campaign.dart';
import '../providers/sourcing_provider.dart';

class BulkCampaignsScreen extends StatefulWidget {
  const BulkCampaignsScreen({super.key});

  @override
  State<BulkCampaignsScreen> createState() => _BulkCampaignsScreenState();
}

class _BulkCampaignsScreenState extends State<BulkCampaignsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final company = context.read<CompanyProvider>().company;
      final user = context.read<AuthProvider>().user;
      final companyId = company?.id ?? user?.uid ?? '';
      if (companyId.isNotEmpty) {
        context.read<SourcingProvider>().listenCompanyCampaigns(companyId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SourcingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('حملات التوظيف الموسعة (Bulk Hiring)'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search_rounded),
            tooltip: 'قاعدة المواهب',
            onPressed: () => context.push(AppRoutes.talentPool),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createCampaign),
        icon: const Icon(Icons.add),
        label: const Text('إطلاق حملة جديدة'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final company = context.read<CompanyProvider>().company;
          final user = context.read<AuthProvider>().user;
          final companyId = company?.id ?? user?.uid ?? '';
          if (companyId.isNotEmpty) {
            provider.listenCompanyCampaigns(companyId);
            await Future.delayed(const Duration(milliseconds: 350));
          }
        },
        child: provider.isLoading && provider.campaigns.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.campaigns.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: provider.errorMessage != null
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline,
                                          size: 48, color: AppColors.error),
                                      const SizedBox(height: 12),
                                      Text(
                                        provider.errorMessage!,
                                        textAlign: TextAlign.center,
                                        style: AppTypography.bodyMedium,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          final company = context.read<CompanyProvider>().company;
                                          final user = context.read<AuthProvider>().user;
                                          final companyId = company?.id ?? user?.uid ?? '';
                                          if (companyId.isNotEmpty) {
                                            provider.listenCompanyCampaigns(companyId);
                                          }
                                        },
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('إعادة المحاولة'),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.campaign_outlined,
                                          size: 64, color: AppColors.textTertiary),
                                      const SizedBox(height: 16),
                                      Text(
                                        'لا توجد حملات توظيف نشطة حالياً',
                                        style: AppTypography.headlineSmall,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'أطلق حملات التوظيف الجماعية لإدارة استقطاب وتعيين مئات الكفاءات بمسارات متزامنة.',
                                        textAlign: TextAlign.center,
                                        style: AppTypography.bodySmall,
                                      ),
                                      const SizedBox(height: 20),
                                      AppButton(
                                        text: 'بدء حملة توظيف الآن',
                                        icon: Icons.rocket_launch_rounded,
                                        onPressed: () => context.push(AppRoutes.createCampaign),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: provider.campaigns.length,
                    itemBuilder: (context, index) {
                      final campaign = provider.campaigns[index];
                      return _CampaignCard(campaign: campaign);
                    },
                  ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final HiringCampaign campaign;

  const _CampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final pct = (campaign.progressPercentage * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
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
              Expanded(
                child: Text(
                  campaign.title,
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  campaign.status.displayName,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'القسم: ${campaign.targetDepartment} • المستهدف: ${campaign.targetHiresCount} مقعد',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(campaign.description, style: AppTypography.bodyMedium),
          const SizedBox(height: 16),

          // Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تم تعيين: ${campaign.currentHiredCount} من أصل ${campaign.targetHiresCount}',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: campaign.progressPercentage,
              minHeight: 8,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),

          if (campaign.requiredSkills.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: campaign.requiredSkills.map((s) {
                return Chip(
                  label: Text(s, style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppColors.surface,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
