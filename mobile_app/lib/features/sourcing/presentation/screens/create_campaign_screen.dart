import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../company/presentation/providers/company_provider.dart';
import '../../domain/entities/hiring_campaign.dart';
import '../providers/sourcing_provider.dart';

class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _departmentController = TextEditingController();
  final _targetCountController = TextEditingController(text: '25');
  final _skillInputController = TextEditingController();

  final List<String> _skills = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _departmentController.dispose();
    _targetCountController.dispose();
    _skillInputController.dispose();
    super.dispose();
  }

  void _addSkill() {
    final s = _skillInputController.text.trim();
    if (s.isNotEmpty && !_skills.contains(s)) {
      setState(() {
        _skills.add(s);
        _skillInputController.clear();
      });
    }
  }

  Future<void> _launchCampaign() async {
    if (!_formKey.currentState!.validate()) return;
    final company = context.read<CompanyProvider>().company;
    final user = context.read<AuthProvider>().user;

    final companyId = company?.id ?? user?.uid ?? '';
    final companyName = company?.name ?? user?.fullName ?? 'Company';

    final targetCount = int.tryParse(_targetCountController.text.trim()) ?? 10;

    final campaign = HiringCampaign(
      id: '',
      companyId: companyId,
      companyName: companyName,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      targetDepartment: _departmentController.text.trim(),
      targetHiresCount: targetCount,
      requiredSkills: _skills,
      createdAt: DateTime.now(),
    );

    final provider = context.read<SourcingProvider>();
    final success = await provider.createCampaign(campaign);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.successMessage ?? 'تم إطلاق الحملة بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'تعذر إطلاق الحملة، حاول مرة أخرى.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SourcingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إطلاق حملة توظيف موسعة'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تخصيص حملة التوظيف الموسعة لتوظيف دفعات كبيرة في أقسام محددة وتتبع التقدم نحو الهدف.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              AppTextField(
                controller: _titleController,
                label: 'مسمى الحملة',
                hint: 'مثال: Graduate Engineering Acceleration Program 2026',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'يرجى إدخال مسمى الحملة' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _departmentController,
                      label: 'القسم المستهدف',
                      hint: 'مثال: Mobile Engineering',
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'يرجى إدخال القسم'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AppTextField(
                      controller: _targetCountController,
                      label: 'المستهدف العددي (شخص)',
                      hint: 'مثال: 30',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'أدخل العدد المطلوب';
                        }
                        final parsed = int.tryParse(v.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'أدخل رقماً أكبر من صفر';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _descriptionController,
                label: 'وصف الحملة والأهداف',
                hint: 'اشرح المعايير العامة للحملة والشريحة المستهدفة...',
                maxLines: 3,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'يرجى كتابة وصف الحملة'
                    : null,
              ),
              const SizedBox(height: 16),

              Text('المهارات الرئيسية المطلوبة بالحملة',
                  style: AppTypography.bodySmall
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _skillInputController,
                      hint: 'مثال: Flutter, Dart, Clean Architecture',
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addSkill,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (_skills.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skills.map((skill) {
                    return Chip(
                      label: Text(skill),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _skills.remove(skill)),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),

              AppButton(
                text: 'إطلاق الحملة وتفعيل التتبع',
                icon: Icons.rocket_launch_rounded,
                isLoading: provider.isActionInProgress,
                onPressed: _launchCampaign,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
