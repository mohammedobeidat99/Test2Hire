import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../company/presentation/providers/company_provider.dart';
import '../../domain/entities/take_home_challenge.dart';
import '../providers/assessments_hub_provider.dart';

class CreateTakeHomeChallengeScreen extends StatefulWidget {
  const CreateTakeHomeChallengeScreen({super.key});

  @override
  State<CreateTakeHomeChallengeScreen> createState() =>
      _CreateTakeHomeChallengeScreenState();
}

class _CreateTakeHomeChallengeScreenState
    extends State<CreateTakeHomeChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _briefController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _starterTemplateController = TextEditingController();
  final _techInputController = TextEditingController();
  final _deliverableInputController = TextEditingController();

  ChallengeDifficulty _difficulty = ChallengeDifficulty.intermediate;
  int _deadlineDays = 3;
  final List<String> _techStack = [];
  final List<String> _deliverables = [];

  @override
  void dispose() {
    _titleController.dispose();
    _briefController.dispose();
    _instructionsController.dispose();
    _starterTemplateController.dispose();
    _techInputController.dispose();
    _deliverableInputController.dispose();
    super.dispose();
  }

  void _addTech() {
    final val = _techInputController.text.trim();
    if (val.isNotEmpty && !_techStack.contains(val)) {
      setState(() {
        _techStack.add(val);
        _techInputController.clear();
      });
    }
  }

  void _addDeliverable() {
    final val = _deliverableInputController.text.trim();
    if (val.isNotEmpty && !_deliverables.contains(val)) {
      setState(() {
        _deliverables.add(val);
        _deliverableInputController.clear();
      });
    }
  }

  Future<void> _saveChallenge() async {
    if (!_formKey.currentState!.validate()) return;
    final company = context.read<CompanyProvider>().company;
    final user = context.read<AuthProvider>().user;

    final companyId = company?.id ?? user?.uid ?? '';
    final companyName = company?.name ?? user?.fullName ?? 'Company';

    final challenge = TakeHomeChallenge(
      id: '',
      companyId: companyId,
      companyName: companyName,
      title: _titleController.text.trim(),
      brief: _briefController.text.trim(),
      detailedInstructions: _instructionsController.text.trim(),
      difficulty: _difficulty,
      deadlineDays: _deadlineDays,
      techStack: _techStack,
      deliverables: _deliverables,
      starterTemplateUrl: _starterTemplateController.text.trim().isNotEmpty
          ? _starterTemplateController.text.trim()
          : null,
      createdAt: DateTime.now(),
    );

    final provider = context.read<AssessmentsHubProvider>();
    final success = await provider.createChallenge(challenge);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.successMessage ?? 'تم إنشاء التحدي بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'فشل إنشاء التحدي العملي. يرجى المحاولة مجدداً.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssessmentsHubProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء تحدي عملي (Take-Home Task)'),
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
                'تصميم مشروع تقييم منزلي للمرشحين لاختبار المهارات العملية البرمجية والتحليلية في سيناريو واقعي.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              AppTextField(
                controller: _titleController,
                label: 'عنوان التحدي / المشروع',
                hint: 'مثال: Fullstack E-Commerce Microservice API',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'يرجى إدخال عنوان التحدي' : null,
              ),
              const SizedBox(height: 16),

              // Brief
              AppTextField(
                controller: _briefController,
                label: 'الملخص والمستهدف من التحدي',
                hint: 'نبذة موجزة تشرح هدف المشروع وما هو متوقع من المرشح...',
                maxLines: 2,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'يرجى إدخال ملخص التحدي' : null,
              ),
              const SizedBox(height: 16),

              // Difficulty & Deadline
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مستوى الصعوبة',
                            style: AppTypography.bodySmall
                                .copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<ChallengeDifficulty>(
                          initialValue: _difficulty,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          items: ChallengeDifficulty.values.map((d) {
                            return DropdownMenuItem(
                              value: d,
                              child: Text(d.displayName),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _difficulty = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مهلة التسليم (أيام)',
                            style: AppTypography.bodySmall
                                .copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          initialValue: _deadlineDays,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          items: [1, 2, 3, 5, 7, 10].map((days) {
                            return DropdownMenuItem(
                              value: days,
                              child: Text('$days أيام'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _deadlineDays = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tech Stack Chips
              Text('التقنيات وحزمة العمل (Tech Stack)',
                  style: AppTypography.bodySmall
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _techInputController,
                      hint: 'مثال: Flutter, NestJS, PostgreSQL',
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addTech,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (_techStack.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _techStack.map((tech) {
                    return Chip(
                      label: Text(tech),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _techStack.remove(tech)),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),

              // Deliverables
              Text('المخرجات المطلوبة للتسليم',
                  style: AppTypography.bodySmall
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _deliverableInputController,
                      hint: 'مثال: Docker Compose file مع اختبارات الوحدة',
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addDeliverable,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (_deliverables.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._deliverables.map((del) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check, size: 16),
                      title: Text(del, style: AppTypography.bodySmall),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () =>
                            setState(() => _deliverables.remove(del)),
                      ),
                    )),
              ],
              const SizedBox(height: 16),

              // Instructions
              AppTextField(
                controller: _instructionsController,
                label: 'التعليمات التفصيلية ومعايير القبول',
                hint: 'اشرح هيكل الحل، القيود، المتطلبات الوظيفية وغير الوظيفية...',
                maxLines: 5,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'يرجى كتابة تعليمات المشروع التفصيلية'
                    : null,
              ),
              const SizedBox(height: 16),

              // Starter Template URL
              AppTextField(
                controller: _starterTemplateController,
                label: 'رابط قالب البداية أو الكود الأولي (اختياري)',
                hint: 'https://github.com/company/project-starter-repo',
                prefixIcon: const Icon(Icons.code_rounded),
              ),
              const SizedBox(height: 24),

              AppButton(
                text: 'نشر وتفعيل التحدي للمرشحين',
                icon: Icons.check_circle_outline,
                isLoading: provider.isSubmitting,
                onPressed: _saveChallenge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
