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

class EditEducationScreen extends StatefulWidget {
  const EditEducationScreen({super.key});

  @override
  State<EditEducationScreen> createState() => _EditEducationScreenState();
}

class _EditEducationScreenState extends State<EditEducationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _institutionController = TextEditingController();
  final _degreeController = TextEditingController();
  final _fieldController = TextEditingController();
  DateTime _startDate = DateTime(2020, 9, 1);
  DateTime? _endDate = DateTime(2024, 6, 30);

  bool _isCurrent = false;

  @override
  void dispose() {
    _institutionController.dispose();
    _degreeController.dispose();
    _fieldController.dispose();
    super.dispose();
  }

  void _showAddEducationModal() {
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
                          Text(isArabic ? 'إضافة مؤهل تعليمي' : 'Add Education', style: AppTypography.headlineSmall),
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
                        label: isArabic ? 'المؤسسة التعليمية / الجامعة' : 'Institution / University',
                        hint: 'e.g. University of Jordan',
                        controller: _institutionController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Institution required.' : null,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: isArabic ? 'الدرجة العلمية' : 'Degree',
                        hint: "e.g. Bachelor's Degree, Master's",
                        controller: _degreeController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Degree required.' : null,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: isArabic ? 'التخصص' : 'Field of Study',
                        hint: 'e.g. Computer Science, Software Engineering',
                        controller: _fieldController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Field required.' : null,
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
                                  firstDate: DateTime(1960),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
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
                                label: Text('${isArabic ? "التخرج" : "End"}: ${_endDate != null ? dateFmt.format(_endDate!) : "Select"}'),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: _endDate ?? _startDate,
                                    firstDate: _startDate,
                                    lastDate: DateTime.now().add(const Duration(days: 3650)),
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
                        title: Text(isArabic ? 'أدرس هنا حالياً' : 'I am currently studying here', style: AppTypography.bodyMedium),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setModalState(() {
                            _isCurrent = val ?? false;
                            if (_isCurrent) {
                              _endDate = null;
                            } else {
                              _endDate ??= _startDate;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        text: isArabic ? 'حفظ المؤهل' : 'Save Education',
                        isLoading: isSaving,
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          final item = EducationItem(
                            institution: _institutionController.text.trim(),
                            degree: _degreeController.text.trim(),
                            fieldOfStudy: _fieldController.text.trim(),
                            startDate: _startDate,
                            endDate: _isCurrent ? null : _endDate,
                            isCurrent: _isCurrent,
                          );

                          final provider = context.read<ProfileProvider>();
                          final ok = await provider.addEducation(item);
                          if (!ctx.mounted) return;
                          if (ok) {
                            _institutionController.clear();
                            _degreeController.clear();
                            _fieldController.clear();
                            Navigator.pop(modalCtx);
                          } else {
                            setModalState(() {
                              modalError = provider.errorMessage ?? 'Failed to save education.';
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
    final provider = context.watch<ProfileProvider>();
    final education = provider.profile?.education ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n?.editEducationTitle ?? 'Education'),
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
                  Text('Degrees & Qualifications', style: AppTypography.titleLarge),
                  IconButton.filledTonal(
                    onPressed: _showAddEducationModal,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (education.isEmpty) ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.school_outlined, size: 64, color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        Text(l10n?.noEducationHistory ?? 'No education history added yet.', style: AppTypography.headlineSmall),
                        const SizedBox(height: 6),
                        Text('Tap "+" above to add your university degrees or diplomas.', style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ListView.separated(
                    itemCount: education.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),

                    itemBuilder: (ctx, index) {
                      final item = education[index];
                      final formatter = DateFormat.y();
                      final startYear = formatter.format(item.startDate);
                      final endYear = item.isCurrent ? 'Present' : (item.endDate != null ? formatter.format(item.endDate!) : '');

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
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.institution, style: AppTypography.titleLarge),
                                  const SizedBox(height: 2),
                                  Text('${item.degree} • ${item.fieldOfStudy}', style: AppTypography.bodyMedium),
                                  const SizedBox(height: 4),
                                  Text('$startYear - $endYear', style: AppTypography.bodySmall),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                              onPressed: provider.isSaving
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(this.context);
                                      final ok = await provider.removeEducation(index);
                                      if (!mounted || ok) return;
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(provider.errorMessage ?? 'Failed to remove education.'),
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
