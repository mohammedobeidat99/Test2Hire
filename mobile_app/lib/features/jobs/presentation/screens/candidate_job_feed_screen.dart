import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../applications/domain/entities/job_application.dart';
import '../../../applications/presentation/providers/candidate_applications_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/job_posting.dart';
import '../providers/candidate_jobs_provider.dart';

enum _JobsViewTab {
  all,
  recommended,
  saved,
  applied,
  recentlyViewed,
}

class CandidateJobFeedScreen extends StatefulWidget {
  final bool embeddedInShell;

  const CandidateJobFeedScreen({
    super.key,
    this.embeddedInShell = false,
  });

  @override
  State<CandidateJobFeedScreen> createState() => _CandidateJobFeedScreenState();
}

class _CandidateJobFeedScreenState extends State<CandidateJobFeedScreen> {
  final TextEditingController _searchController = TextEditingController();
  _JobsViewTab _activeTab = _JobsViewTab.all;

  static const List<String> _categories = [
    'All',
    'Engineering',
    'Data & AI',
    'Cloud & DevOps',
    'Product & Design',
  ];

  static const List<Color> _companyPalette = [
    Color(0xFF1E40AF),
    Color(0xFF0F766E),
    Color(0xFF6D28D9),
    Color(0xFF0369A1),
    Color(0xFFB45309),
    Color(0xFFBE123C),
  ];

  Color _companyAccentColor(String key) {
    if (key.isEmpty) return AppColors.primary;
    final hash = key.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    return _companyPalette[hash % _companyPalette.length];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final jobsProvider = context.read<CandidateJobsProvider>();
      if (jobsProvider.jobs.isEmpty) {
        jobsProvider.listenJobs();
      }
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        jobsProvider.loadCandidateJobPreferences(uid);
        context.read<CandidateApplicationsProvider>().listenApplications(uid);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterModal(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final provider = context.read<CandidateJobsProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n?.filterAndSortJobs ?? 'Filter & Sort Jobs', style: AppTypography.headlineSmall),
                        TextButton(
                          onPressed: () {
                            provider.clearFilters();
                            Navigator.pop(modalCtx);
                          },
                          child: Text(l10n?.resetAll ?? 'Reset All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Text(l10n?.sortBy ?? 'Sort By',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: JobSortOption.values.map((opt) {
                        final isSelected = provider.sortOption == opt;
                        return ChoiceChip(
                          label: Text(opt.localizedName(isArabic)),
                          selected: isSelected,
                          onSelected: (_) {
                            setModalState(() {
                              provider.setSortOption(opt);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Workplace Type
                    Text(l10n?.workArrangement ?? 'Work Arrangement',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: WorkplaceType.values.map((wp) {
                        final isSelected = provider.selectedWorkplaceType == wp;
                        return ChoiceChip(
                          label: Text(wp.localizedName(isArabic)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              provider.setWorkplaceType(selected ? wp : null);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Job Type
                    Text(l10n?.employmentType ?? 'Employment Type',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: JobType.values.map((jt) {
                        final isSelected = provider.selectedJobType == jt;
                        return ChoiceChip(
                          label: Text(jt.localizedName(isArabic)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              provider.setJobType(selected ? jt : null);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Experience Level
                    Text(l10n?.experienceLevel ?? 'Experience Level',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ExperienceLevel.values.map((el) {
                        final isSelected = provider.selectedExperienceLevel == el;
                        return ChoiceChip(
                          label: Text(el.localizedName(isArabic)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              provider.setExperienceLevel(selected ? el : null);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(l10n?.applyFilters ?? 'Apply Filters'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final jobsProvider = context.watch<CandidateJobsProvider>();
    final appsProvider = context.watch<CandidateApplicationsProvider>();
    final candidateProfile = context.watch<ProfileProvider>().profile;
    final authUser = context.watch<AuthProvider>().user;
    final candidateSkills = candidateProfile?.skills ?? [];

    final baseFiltered = jobsProvider.getSortedAndFilteredJobs(candidateSkills);
    final skillMatches =
        jobsProvider.computeSkillMatches(baseFiltered, candidateSkills);
    final appliedIds = appsProvider.applications.map((a) => a.jobId).toSet();

    List<JobPosting> displayedJobs;
    switch (_activeTab) {
      case _JobsViewTab.all:
        displayedJobs = baseFiltered;
        break;
      case _JobsViewTab.recommended:
        displayedJobs = List<JobPosting>.from(baseFiltered)
          ..sort((a, b) =>
              (skillMatches[b.id] ?? 0).compareTo(skillMatches[a.id] ?? 0));
        break;
      case _JobsViewTab.saved:
        displayedJobs = baseFiltered
            .where((j) => jobsProvider.isJobSaved(j.id))
            .toList();
        break;
      case _JobsViewTab.applied:
        displayedJobs =
            baseFiltered.where((j) => appliedIds.contains(j.id)).toList();
        break;
      case _JobsViewTab.recentlyViewed:
        displayedJobs = jobsProvider.recentlyViewedJobs;
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embeddedInShell,
        title: Text(l10n?.jobsRecruitmentTitle ?? 'Jobs & Recruitment'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/candidate/applications'),
            icon: const Icon(Icons.assignment_turned_in_outlined, size: 17),
            label: Text('${l10n?.applied ?? "Applied"} (${appsProvider.applications.length})'),
          ),
          IconButton(
            tooltip: l10n?.filterAndSortTooltip ?? 'Filter & Sort',
            icon: Stack(
              children: [
                const Icon(Icons.tune_rounded),
                if (jobsProvider.hasActiveFilters)
                  PositionedDirectional(
                    end: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showFilterModal(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n?.searchJobsPlaceholder ?? 'Search by job title, company, or skill...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          jobsProvider.setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: (val) => jobsProvider.setSearchQuery(val),
            ),
          ),

          // View Sub-Tabs (All, Recommended, Saved, Applied, Recently Viewed)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildViewTabChip('${l10n?.allJobsTab ?? "All Jobs"} (${baseFiltered.length})', _JobsViewTab.all),
                _buildViewTabChip(l10n?.recommendedTab ?? 'Recommended', _JobsViewTab.recommended),
                _buildViewTabChip(
                  '${l10n?.savedTab ?? "Saved"} (${jobsProvider.savedJobIds.length})',
                  _JobsViewTab.saved,
                ),
                _buildViewTabChip(
                  '${l10n?.appliedTab ?? "Applied"} (${appliedIds.length})',
                  _JobsViewTab.applied,
                ),
                _buildViewTabChip(
                  '${l10n?.recentlyViewedTab ?? "Recently Viewed"} (${jobsProvider.recentlyViewedJobIds.length})',
                  _JobsViewTab.recentlyViewed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Category Filter Chips
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final cat = _categories[idx];
                final isSelected = jobsProvider.selectedCategory == cat;
                return InkWell(
                  onTap: () => jobsProvider.setCategory(cat),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      isArabic ? (cat == 'All' ? 'الكل' : cat == 'Engineering' ? 'الهندسة والبرمجة' : cat == 'Data & AI' ? 'البيانات والذكاء الاصطناعي' : cat == 'Cloud & DevOps' ? 'السحابة والديف أوبس' : 'المنتجات والتصميم') : cat,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Active filter pills
          if (jobsProvider.hasActiveFilters)
            Container(
              height: 34,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (jobsProvider.selectedWorkplaceType != null)
                    _buildActiveChip(
                      jobsProvider.selectedWorkplaceType!.localizedName(isArabic),
                      () => jobsProvider.setWorkplaceType(null),
                    ),
                  if (jobsProvider.selectedJobType != null)
                    _buildActiveChip(
                      jobsProvider.selectedJobType!.localizedName(isArabic),
                      () => jobsProvider.setJobType(null),
                    ),
                  if (jobsProvider.selectedExperienceLevel != null)
                    _buildActiveChip(
                      jobsProvider.selectedExperienceLevel!.localizedName(isArabic),
                      () => jobsProvider.setExperienceLevel(null),
                    ),
                ],
              ),
            ),

          // Jobs Feed
          Expanded(
            child: jobsProvider.isLoading && jobsProvider.jobs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => jobsProvider.fetchJobs(),
                    child: jobsProvider.errorMessage != null && jobsProvider.jobs.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.error_outline_rounded,
                            title: 'Failed to load vacancies',
                            description: jobsProvider.errorMessage!,
                            actionLabel: 'Retry',
                            actionIcon: Icons.refresh_rounded,
                            onAction: () => jobsProvider.listenJobs(force: true),
                          )
                        : displayedJobs.isEmpty
                            ? EmptyStateWidget(
                                icon: _activeTab == _JobsViewTab.saved
                                    ? Icons.bookmark_border_rounded
                                    : Icons.search_off_rounded,
                                title: _activeTab == _JobsViewTab.saved
                                    ? (l10n?.noSavedJobsTitle ?? 'No Saved Jobs Yet')
                                    : (l10n?.noMatchingJobsTitle ?? 'No Matching Vacancies'),
                                description: _activeTab == _JobsViewTab.saved
                                    ? 'Tap the bookmark icon on any job card to save it here for quick access.'
                                    : 'Try adjusting your search query or switching tabs to discover open roles.',
                                actionLabel: l10n?.allJobsTab ?? 'Show All Jobs',
                                actionIcon: Icons.work_outline_rounded,
                                onAction: () {
                                  setState(() => _activeTab = _JobsViewTab.all);
                                  _searchController.clear();
                                  jobsProvider.clearFilters();
                                },
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                                itemCount: displayedJobs.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final job = displayedJobs[index];
                                  final match = skillMatches[job.id] ??
                                      jobsProvider.calculateSkillMatch(
                                          job, candidateSkills);
                                  return _buildCandidateJobCard(
                                    context,
                                    job,
                                    match,
                                    authUser?.uid,
                                  );
                                },
                              ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewTabChip(String label, _JobsViewTab tab) {
    final isSelected = _activeTab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        onSelected: (_) => setState(() => _activeTab = tab),
      ),
    );
  }

  Widget _buildActiveChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onRemove,
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildCandidateJobCard(
    BuildContext context,
    JobPosting job,
    int matchPercent,
    String? userId,
  ) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final jobsProvider = context.read<CandidateJobsProvider>();
    final appsProvider = context.watch<CandidateApplicationsProvider>();
    final isSaved = jobsProvider.isJobSaved(job.id);
    final existingApp = appsProvider.applications
        .where((a) => a.jobId == job.id)
        .firstOrNull;
    final companyAccent =
        _companyAccentColor(job.companyId.isNotEmpty ? job.companyId : job.companyName);

    final publishedText = job.createdAt != null
        ? DateFormat('MMM d, yyyy').format(job.createdAt!)
        : 'Recently posted';

    return Container(
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
              child: Container(color: companyAccent),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                jobsProvider.recordJobViewed(job.id, userId: userId);
                context.push('/jobs/${job.id}', extra: job);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Company Header + Bookmark + Match
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (job.companyId.isNotEmpty) {
                        context.push('/company/${job.companyId}/careers');
                      }
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: companyAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: companyAccent.withValues(alpha: 0.25)),
                      ),
                      child: (job.companyLogoUrl != null &&
                              job.companyLogoUrl!.trim().isNotEmpty)
                          ? AppSafeImage(
                              url: job.companyLogoUrl!,
                              width: 46,
                              height: 46,
                              borderRadius: BorderRadius.circular(12),
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Center(
                                child: Text(
                                  job.companyName.trim().isNotEmpty
                                      ? job.companyName.trim()[0].toUpperCase()
                                      : 'C',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: companyAccent,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                job.companyName.trim().isNotEmpty
                                    ? job.companyName.trim()[0].toUpperCase()
                                    : 'C',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: companyAccent,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: AppTypography.headlineSmall.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        GestureDetector(
                          onTap: () {
                            if (job.companyId.isNotEmpty) {
                              context.push('/company/${job.companyId}/careers');
                            }
                          },
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  job.companyName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: companyAccent,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.open_in_new_rounded,
                                  size: 12, color: companyAccent),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${job.location.formatted} • $publishedText',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: isSaved ? 'Remove from Saved' : 'Save Job',
                    icon: Icon(
                      isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: isSaved ? AppColors.primary : AppColors.textSecondary,
                    ),
                    onPressed: () {
                      jobsProvider.toggleSaveJob(job.id, userId: userId);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Short Description Snippet
              if (job.description.trim().isNotEmpty) ...[
                Text(
                  job.description.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Badges Row (Workplace, Type, Experience, Match, Applied status)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildPill(job.workplaceType.localizedName(isArabic), companyAccent),
                  _buildPill(job.jobType.localizedName(isArabic), AppColors.textPrimary),
                  _buildPill(job.experienceLevel.localizedName(isArabic), AppColors.accent),
                  if (matchPercent > 0)
                    _buildPill(
                      '$matchPercent% ${l10n?.skillMatch ?? "Skill Match"}',
                      matchPercent >= 70 ? AppColors.success : AppColors.warning,
                    ),
                  if (existingApp != null)
                    _buildPill(
                      '${l10n?.applied ?? "Applied"}: ${existingApp.status.toShortString()}',
                      AppColors.success,
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Required Skills
              if (job.requiredSkills.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: job.requiredSkills.take(4).map((skill) {
                    return Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        skill,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textPrimary),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],

              // Footer
              Row(
                children: [
                  if (job.salaryRange != null)
                    Text(
                      job.salaryRange!.formatted,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: companyAccent,
                      ),
                    )
                  else
                    Text(
                      isArabic ? 'راتب مجزٍ وتنافسي' : 'Competitive Salary',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    existingApp != null ? (l10n?.viewApplicationDetails ?? 'View Application') : (l10n?.jobDetailsTitle ?? 'View Details & Apply'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: companyAccent,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: companyAccent),
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

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
