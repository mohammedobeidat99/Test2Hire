import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../company/presentation/providers/company_provider.dart';
import '../../domain/entities/hiring_campaign.dart';
import '../providers/sourcing_provider.dart';

class TalentPoolSearchScreen extends StatefulWidget {
  const TalentPoolSearchScreen({super.key});

  @override
  State<TalentPoolSearchScreen> createState() =>
      _TalentPoolSearchScreenState();
}

class _TalentPoolSearchScreenState extends State<TalentPoolSearchScreen> {
  final _searchController = TextEditingController();
  final _skillFilterController = TextEditingController();
  final List<String> _filterSkills = [];
  bool _onlyAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeSearch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _skillFilterController.dispose();
    super.dispose();
  }

  void _executeSearch() {
    context.read<SourcingProvider>().searchTalentPool(
          query: _searchController.text.trim(),
          skills: _filterSkills,
          onlyAvailable: _onlyAvailable ? true : null,
        );
  }

  void _addFilterSkill() {
    final s = _skillFilterController.text.trim();
    if (s.isNotEmpty && !_filterSkills.contains(s)) {
      setState(() {
        _filterSkills.add(s);
        _skillFilterController.clear();
      });
      _executeSearch();
    }
  }

  void _openInviteDialog(TalentCandidateProfile candidate) {
    final messageController = TextEditingController(
      text:
          'مرحباً ${candidate.fullName}، يسعدنا دعوتك للانضمام إلى فريقنا واستعراض الفرص الوظيفية المتاحة لدينا.',
    );
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Consumer<SourcingProvider>(
          builder: (dialogCtx, provider, _) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: Text('إرسال دعوة استقطاب لـ ${candidate.fullName}'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'سيتم إرسال إشعار مباشر للمرشح بالدعوة للتقديم والتواصل مع فريق الاستقطاب.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          dialogError!,
                          style: const TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: messageController,
                      label: 'نص رسالة الدعوة',
                      maxLines: 3,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: provider.isActionInProgress
                        ? null
                        : () => Navigator.of(dialogCtx).pop(),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: provider.isActionInProgress
                        ? null
                        : () async {
                            final msg = messageController.text.trim();
                            if (msg.isEmpty) {
                              setDialogState(() {
                                dialogError = 'يرجى كتابة نص رسالة الدعوة.';
                              });
                              return;
                            }
                            setDialogState(() => dialogError = null);

                            final nav = Navigator.of(dialogCtx);
                            final messenger = ScaffoldMessenger.of(context);
                            final company = context.read<CompanyProvider>().company;
                            final user = context.read<AuthProvider>().user;
                            final companyId = company?.id ?? user?.uid ?? '';
                            final companyName =
                                company?.name ?? user?.fullName ?? 'Company';

                            final invite = TalentPoolInvite(
                              id: '',
                              companyId: companyId,
                              companyName: companyName,
                              candidateId: candidate.candidateId,
                              candidateName: candidate.fullName,
                              inviteMessage: msg,
                              sentAt: DateTime.now(),
                            );

                            final success = await provider.sendTalentInvite(invite);
                            if (success) {
                              if (nav.mounted) nav.pop();
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(provider.successMessage ??
                                        'تم إرسال دعوة التوظيف بنجاح'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } else if (ctx.mounted) {
                              setDialogState(() {
                                dialogError = provider.errorMessage ??
                                    'تعذر إرسال الدعوة، حاول مرة أخرى.';
                              });
                            }
                          },
                    child: provider.isActionInProgress
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('إرسال الدعوة'),
                  ),
                ],
              );
            },
          ),
        );
      },
    ).whenComplete(messageController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SourcingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('قاعدة المواهب (Talent Pool Directory)'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _searchController,
                        hint: 'ابحث بالاسم، المسمى الوظيفي، أو المهارات...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        onFieldSubmitted: (_) => _executeSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _executeSearch,
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _skillFilterController,
                        hint: 'تصفية بالمهارة (مثال: Flutter)',
                        onFieldSubmitted: (_) => _addFilterSkill(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: _addFilterSkill,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                if (_filterSkills.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _filterSkills.map((s) {
                      return Chip(
                        label: Text(s, style: const TextStyle(fontSize: 11)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          setState(() => _filterSkills.remove(s));
                          _executeSearch();
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Checkbox(
                      value: _onlyAvailable,
                      onChanged: (v) {
                        setState(() => _onlyAvailable = v ?? false);
                        _executeSearch();
                      },
                    ),
                    const Text('المتاحين للعمل الفوري فقط',
                        style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Candidate Results List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<SourcingProvider>().searchTalentPool(
                    query: _searchController.text.trim(),
                    skills: _filterSkills,
                    onlyAvailable: _onlyAvailable ? true : null,
                  ),
              child: provider.isSearching && provider.talentPool.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.talentPool.isEmpty
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
                                              onPressed: _executeSearch,
                                              icon: const Icon(Icons.refresh),
                                              label: const Text('إعادة المحاولة'),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.person_search_outlined,
                                                size: 56, color: AppColors.textTertiary),
                                            const SizedBox(height: 12),
                                            Text('لم يتم العثور على مواهب مطابقة',
                                                style: AppTypography.headlineSmall),
                                            const SizedBox(height: 4),
                                            Text('جرّب تعديل معايير البحث أو الكلمات الدلالية.',
                                                textAlign: TextAlign.center,
                                                style: AppTypography.bodySmall),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.talentPool.length,
                          itemBuilder: (context, index) {
                            final candidate = provider.talentPool[index];
                            return _TalentCard(
                              candidate: candidate,
                              onInvite: () => _openInviteDialog(candidate),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TalentCard extends StatelessWidget {
  final TalentCandidateProfile candidate;
  final VoidCallback onInvite;

  const _TalentCard({
    required this.candidate,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final avatarProvider = getSafeImageProvider(candidate.photoUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: avatarProvider,
                child: avatarProvider == null
                    ? Text(
                        candidate.fullName.isNotEmpty
                            ? candidate.fullName[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.fullName,
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (candidate.headline != null &&
                        candidate.headline!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        candidate.headline!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'خبرة: ${candidate.experienceYears} سنوات • ${candidate.location ?? "عالمي"}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              if (candidate.avgAssessmentScore != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${candidate.avgAssessmentScore!.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (candidate.skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: candidate.skills.map((s) {
                return Chip(
                  label: Text(s, style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppColors.surface,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          AppButton(
            text: 'توجيه دعوة استقطاب مباشرة',
            icon: Icons.mark_email_read_outlined,
            variant: AppButtonVariant.outline,
            onPressed: onInvite,
          ),
        ],
      ),
    );
  }
}
