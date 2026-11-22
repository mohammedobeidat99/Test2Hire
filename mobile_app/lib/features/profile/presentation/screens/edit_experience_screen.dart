import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/candidate_profile.dart';
import '../providers/profile_provider.dart';

class EditExperienceScreen extends StatefulWidget {
  const EditExperienceScreen({super.key});

  @override
  State<EditExperienceScreen> createState() => _EditExperienceScreenState();
}

class _EditExperienceScreenState extends State<EditExperienceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _startDate = DateTime(2022, 1, 1);
  DateTime? _endDate = DateTime.now();

  bool _isCurrent = true;

  @override
  void dispose() {
    _companyController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showAddExperienceModal() {
    String? modalError;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isSaving = ctx.watch<ProfileProvider>().isSaving;
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            final dateFmt = DateFormat.yMMM();

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isArabic ? 'إضافة خبرة عملية' : 'Add Work Experience', style: AppTypography.headlineSmall),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: isSaving ? null : () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (modalError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
                          ),
                          child: Text(modalError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                        ),
                      ],
                      AppTextField(
                        label: isArabic ? 'اسم الشركة' : 'Company Name',
                        hint: 'e.g. Google, Tech Startup',
                        controller: _companyController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Company is required.' : null,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: isArabic ? 'المسمى الوظيفي' : 'Job Title',
                        hint: 'e.g. Flutter Mobile Developer',
                        controller: _titleController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Title is required.' : null,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: isArabic ? 'الموقع (اختياري)' : 'Location (Optional)',
                        hint: 'e.g. Remote / Dubai',
                        controller: _locationController,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text('${isArabic ? "البدء" : "Start"}: ${dateFmt.format(_startDate)}'),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: _startDate,
                                  firstDate: DateTime(1970),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null && ctx.mounted) {
                                  setModalState(() {
                                    _startDate = picked;
                                    if (_endDate != null && _endDate!.isBefore(_startDate)) {
                                      _endDate = _startDate;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          if (!_isCurrent) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.event_available, size: 16),
                                label: Text('${isArabic ? "الانتهاء" : "End"}: ${_endDate != null ? dateFmt.format(_endDate!) : "Select"}'),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: _endDate ?? _startDate,
                                    firstDate: _startDate,
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null && ctx.mounted) {
                                    setModalState(() => _endDate = picked);
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _isCurrent,
                        title: Text(isArabic ? 'أعمل هنا حالياً' : 'I am currently working here', style: AppTypography.bodyMedium),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setModalState(() {
                            _isCurrent = val ?? false;
                            if (_isCurrent) {
                              _endDate = null;
                            } else {
                              _endDate ??= DateTime.now();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: isArabic ? 'المسؤوليات والإنجازات' : 'Role Responsibilities & Achievements',
                        hint: 'Built features, optimized app performance, managed CI/CD...',
                        controller: _descController,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        text: isArabic ? 'حفظ الخبرة' : 'Save Experience',
                        isLoading: isSaving,
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          final item = ExperienceItem(
                            company: _companyController.text.trim(),
                            title: _titleController.text.trim(),
                            location: _locationController.text.trim(),
                            startDate: _startDate,
                            endDate: _isCurrent ? null : _endDate,
                            isCurrent: _isCurrent,
                            description: _descController.text.trim(),
                          );

                          final provider = context.read<ProfileProvider>();
                          final ok = await provider.addExperience(item);
                          if (!ctx.mounted) return;
                          if (ok) {
                            _companyController.clear();
                            _titleController.clear();
                            _locationController.clear();
                            _descController.clear();
                            Navigator.pop(modalCtx);
                          } else {
                            setModalState(() {
                              modalError = provider.errorMessage ?? 'Failed to save experience.';
                            });
                          }
                        },
                      ),
                    ],
                  ),
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
    final provider = context.watch<ProfileProvider>();
    final experience = provider.profile?.experience ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n?.editExperienceTitle ?? 'Work Experience'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isArabic ? 'المناصب والخبرات' : 'Positions & Roles', style: AppTypography.titleLarge),
                  IconButton.filledTonal(
                    onPressed: _showAddExperienceModal,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (experience.isEmpty) ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.work_outline_rounded, size: 64, color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        Text(l10n?.noExperienceRecorded ?? 'No experience records added yet.', style: AppTypography.headlineSmall),
                        const SizedBox(height: 6),
                        Text(isArabic ? 'اضغط على "+" لإضافة تدريب، دوام جزئي أو دوام كامل.' : 'Tap "+" above to add internships, part-time or full-time roles.', style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ListView.separated(
                    itemCount: experience.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),

                    itemBuilder: (ctx, index) {
                      final item = experience[index];
                      final formatter = DateFormat.yMMM();
                      final start = formatter.format(item.startDate);
                      final end = item.isCurrent ? 'Present' : (item.endDate != null ? formatter.format(item.endDate!) : '');

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.business_center_rounded, color: AppColors.accent, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, style: AppTypography.titleLarge),
                                  const SizedBox(height: 2),
                                  Text(item.company, style: AppTypography.bodyMedium),
                                  const SizedBox(height: 4),
                                  Text('$start - $end', style: AppTypography.bodySmall),
                                  if (item.description != null && item.description!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(item.description!, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary)),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                              onPressed: provider.isSaving
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(this.context);
                                      final ok = await provider.removeExperience(index);
                                      if (!mounted || ok) return;
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(provider.errorMessage ?? 'Failed to remove experience.'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
