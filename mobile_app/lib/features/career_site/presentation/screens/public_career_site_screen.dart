import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/app_routes.dart';
import 'package:mobile_app/core/constants/app_colors.dart';
import 'package:mobile_app/core/constants/app_typography.dart';
import 'package:mobile_app/core/widgets/app_image.dart';
import 'package:mobile_app/core/services/url_launcher_helper.dart';
import 'package:mobile_app/features/career_site/presentation/providers/career_page_provider.dart';
import 'package:mobile_app/features/community/presentation/providers/community_provider.dart';
import 'package:mobile_app/features/jobs/domain/entities/job_posting.dart';
import 'package:provider/provider.dart';

class PublicCareerSiteScreen extends StatefulWidget {
  final String companyId;

  const PublicCareerSiteScreen({
    super.key,
    required this.companyId,
  });

  @override
  State<PublicCareerSiteScreen> createState() => _PublicCareerSiteScreenState();
}

class _PublicCareerSiteScreenState extends State<PublicCareerSiteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CareerPageProvider>().listenCareerPage(widget.companyId);
      final communityProvider = context.read<CommunityProvider>();
      if (communityProvider.allPosts.isEmpty) {
        communityProvider.listenFeed();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final companyPosts = context
        .watch<CommunityProvider>()
        .allPosts
        .where((p) => p.companyId == widget.companyId || p.authorId == widget.companyId)
        .toList();

    return Consumer<CareerPageProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.careerPage == null) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        final page = provider.careerPage;
        final jobs = provider.publicJobs;

        if (page == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Company Profile')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: provider.errorMessage != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(provider.errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => provider.listenCareerPage(widget.companyId),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      )
                    : const Text('Company profile not found.'),
              ),
            ),
          );
        }

        final brandColor = page.branding.brandColor;
        final websiteUrl = page.branding.websiteUrl;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              // Dynamic Themed Sliver AppBar with Cover & Logo
              SliverAppBar(
                expandedHeight: 190,
                pinned: true,
                backgroundColor: brandColor,
                title: Text(
                  page.companyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (page.branding.coverImageUrl != null &&
                          page.branding.coverImageUrl!.isNotEmpty)
                        AppSafeImage(
                          url: page.branding.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: brandColor),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                brandColor,
                                brandColor.withValues(alpha: 0.78),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Company Header Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Identity Card
                      Container(
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
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: brandColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: page.logoUrl != null &&
                                            page.logoUrl!.isNotEmpty
                                        ? AppSafeImage(
                                            url: page.logoUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Center(
                                              child: Text(
                                                page.companyName.isNotEmpty
                                                    ? page.companyName[0].toUpperCase()
                                                    : 'C',
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w800,
                                                  color: brandColor,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              page.companyName.isNotEmpty
                                                  ? page.companyName[0].toUpperCase()
                                                  : 'C',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                color: brandColor,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              page.companyName,
                                              style: AppTypography.headlineSmall
                                                  .copyWith(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          if (page.isApproved)
                                            const Icon(
                                              Icons.verified_rounded,
                                              color: Color(0xFF047857),
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        page.industry,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: brandColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined,
                                              size: 14, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              page.location,
                                              style: AppTypography.bodySmall.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (websiteUrl != null && websiteUrl.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => UrlLauncherHelper.openUrl(
                                    context,
                                    websiteUrl,
                                    successMessage: 'Opening company website...',
                                  ),
                                  icon: Icon(Icons.language_rounded,
                                      size: 16, color: brandColor),
                                  label: Text(
                                    'Visit Official Website ($websiteUrl)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: brandColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Company Stats Row
                      Row(
                        children: [
                          Expanded(
                            child: _CompanyStatTile(
                              label: 'Open Roles',
                              value: '${jobs.length}',
                              icon: Icons.work_outline_rounded,
                              color: brandColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CompanyStatTile(
                              label: 'Status',
                              value: page.isApproved ? 'Verified' : 'Partner',
                              icon: Icons.verified_user_outlined,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CompanyStatTile(
                              label: 'Community Posts',
                              value: '${companyPosts.length}',
                              icon: Icons.forum_outlined,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),

                      if (page.branding.tagline != null &&
                          page.branding.tagline!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: brandColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: brandColor.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            page.branding.tagline!,
                            style: TextStyle(
                              color: brandColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About ${page.companyName}',
                              style: AppTypography.titleLarge
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              page.description.isNotEmpty
                                  ? page.description
                                  : '${page.companyName} is a verified employer on Test2Hire hiring top engineering and business talent through structured skill assessments.',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.5,
                              ),
                            ),
                            if (page.branding.perksAndBenefits.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Benefits & Culture',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: page.branding.perksAndBenefits.map((perk) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_outline,
                                            size: 14, color: brandColor),
                                        const SizedBox(width: 6),
                                        Text(perk,
                                            style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),
                      Text(
                        'Open Job Opportunities (${jobs.length})',
                        style: AppTypography.titleLarge
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // Job Listings Sliver List
              if (jobs.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: Text(
                        'No open vacancies published at this moment.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final job = jobs[index];
                        return _buildJobCard(context, job, brandColor);
                      },
                      childCount: jobs.length,
                    ),
                  ),
                ),

              // Company Community Updates
              if (companyPosts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Company Updates (${companyPosts.length})',
                          style: AppTypography.titleLarge
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ...companyPosts.take(3).map((post) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.content,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.thumb_up_alt_outlined,
                                        size: 13, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${post.likesCount} likes • ${post.commentsCount} comments',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJobCard(BuildContext context, JobPosting job, Color brandColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            PositionedDirectional(
              top: 0,
              bottom: 0,
              start: 0,
              width: 4,
              child: Container(color: brandColor),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                context.push(AppRoutes.jobDetail.replaceAll(':id', job.id), extra: job);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      style: AppTypography.bodyLarge
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      job.jobType.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: brandColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${job.location.formatted} • ${job.workplaceType.displayName} • ${job.experienceLevel.displayName}',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      job.salaryRange?.formatted ?? 'Competitive Package',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: brandColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      context.push(
                        AppRoutes.jobDetail.replaceAll(':id', job.id),
                        extra: job,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('View & Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
          ],
        ),
      ),
    );
  }
}

class _CompanyStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _CompanyStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
