import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../company/presentation/providers/company_provider.dart';
import '../../../exams/presentation/providers/company_exams_provider.dart';
import '../../domain/entities/job_posting.dart';
import '../providers/company_jobs_provider.dart';

class CreateEditJobScreen extends StatefulWidget {
  final JobPosting? existingJob;

  const CreateEditJobScreen({super.key, this.existingJob});

  @override
  State<CreateEditJobScreen> createState() => _CreateEditJobScreenState();
}

class _CreateEditJobScreenState extends State<CreateEditJobScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _cityController;
  late TextEditingController _countryController;
  late TextEditingController _descriptionController;
  late TextEditingController _minSalaryController;
  late TextEditingController _maxSalaryController;
  late TextEditingController _skillInputController;
  late TextEditingController _requirementsController;
  late TextEditingController _responsibilitiesController;

  late JobType _selectedJobType;
  late WorkplaceType _selectedWorkplaceType;
  late ExperienceLevel _selectedExperienceLevel;
  late bool _isNegotiable;
  late bool _isDisclosed;
  late String _currency;
  late List<String> _requiredSkills;
  String? _selectedExamId;

  @override
  void initState() {
    super.initState();
    final j = widget.existingJob;

    _titleController = TextEditingController(text: j?.title ?? '');
    _cityController = TextEditingController(text: j?.location.city ?? '');
    _countryController = TextEditingController(text: j?.location.country ?? '');
    _descriptionController = TextEditingController(text: j?.description ?? '');
    _minSalaryController = TextEditingController(
        text: j?.salaryRange?.min != null ? j!.salaryRange!.min!.toStringAsFixed(0) : '');
    _maxSalaryController = TextEditingController(
        text: j?.salaryRange?.max != null ? j!.salaryRange!.max!.toStringAsFixed(0) : '');
    _skillInputController = TextEditingController();
    _requirementsController = TextEditingController(
        text: j != null ? j.requirements.join('\n') : '');
    _responsibilitiesController = TextEditingController(
        text: j != null ? j.responsibilities.join('\n') : '');

    _selectedJobType = j?.jobType ?? JobType.fullTime;
    _selectedWorkplaceType = j?.workplaceType ?? WorkplaceType.onSite;
    _selectedExperienceLevel = j?.experienceLevel ?? ExperienceLevel.mid;
    _isNegotiable = j?.salaryRange?.isNegotiable ?? false;
    _isDisclosed = j?.salaryRange?.isDisclosed ?? true;
    _currency = j?.salaryRange?.currency ?? 'JOD';
    _requiredSkills = List.from(j?.requiredSkills ?? []);
    _selectedExamId = j?.examId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<CompanyExamsProvider>().loadCompanyExams(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _descriptionController.dispose();
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    _skillInputController.dispose();
    _requirementsController.dispose();
    _responsibilitiesController.dispose();
    super.dispose();
  }

  void _addSkill() {
    final skill = _skillInputController.text.trim();
    if (skill.isNotEmpty && !_requiredSkills.contains(skill)) {
      setState(() {
        _requiredSkills.add(skill);
        _skillInputController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _requiredSkills.remove(skill);
    });
  }

  Future<void> _submit(JobStatus targetStatus) async {
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<AuthProvider>().user;
    final company = context.read<CompanyProvider>().company;

    if (user == null) return;

    final minSal = double.tryParse(_minSalaryController.text.trim());
    final maxSal = double.tryParse(_maxSalaryController.text.trim());
    if ((minSal != null && minSal < 0) ||
        (maxSal != null && maxSal < 0) ||
        (minSal != null && maxSal != null && minSal > maxSal)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid salary range (min must be <= max).'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final salary = JobSalaryRange(
      min: minSal,
      max: maxSal,
      currency: _currency,
      isNegotiable: _isNegotiable,
      isDisclosed: _isDisclosed,
    );

    final location = JobLocation(
      city: _cityController.text.trim(),
      country: _countryController.text.trim(),
    );

    final reqs = _requirementsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final resps = _responsibilitiesController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final provider = context.read<CompanyJobsProvider>();

    if (widget.existingJob != null) {
      final updated = widget.existingJob!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        jobType: _selectedJobType,
        workplaceType: _selectedWorkplaceType,
        experienceLevel: _selectedExperienceLevel,
        location: location,
        salaryRange: salary,
        requiredSkills: _requiredSkills,
        requirements: reqs,
        responsibilities: resps,
        status: targetStatus,
        examId: _selectedExamId,
        updatedAt: DateTime.now(),
      );

      final ok = await provider.updateJob(updated);
      if (!mounted) return;
      if (ok) {
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to update job vacancy.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else {
      final id = await provider.createJob(
        companyId: user.uid,
        companyName: company?.name ?? 'Company',
        companyLogoUrl: company?.logoUrl,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        jobType: _selectedJobType,
        workplaceType: _selectedWorkplaceType,
        experienceLevel: _selectedExperienceLevel,
        location: location,
        salaryRange: salary,
        requiredSkills: _requiredSkills,
        requirements: reqs,
        responsibilities: resps,
        status: targetStatus,
        examId: _selectedExamId,
      );

      if (!mounted) return;
      if (id != null) {
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to create job vacancy.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingJob != null;
    final isSaving = context.watch<CompanyJobsProvider>().isSaving;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Vacancy' : 'Post New Vacancy'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Basic details
              Text('Job Details', style: AppTypography.headlineSmall),
              const SizedBox(height: 12),
              AppTextField(
                controller: _titleController,
                label: 'Job Title *',
                hint: 'e.g. Senior Mobile Engineer (Flutter)',
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Job title is required' : null,
              ),
              const SizedBox(height: 16),

              // Dropdowns row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<JobType>(
                      isExpanded: true,
                      initialValue: _selectedJobType,
                      decoration: const InputDecoration(
                        labelText: 'Job Type',
                        border: OutlineInputBorder(),
                      ),
                      items: JobType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedJobType = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<WorkplaceType>(
                      isExpanded: true,
                      initialValue: _selectedWorkplaceType,
                      decoration: const InputDecoration(
                        labelText: 'Workplace',
                        border: OutlineInputBorder(),
                      ),
                      items: WorkplaceType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedWorkplaceType = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<ExperienceLevel>(
                isExpanded: true,
                initialValue: _selectedExperienceLevel,
                decoration: const InputDecoration(
                  labelText: 'Experience Level',
                  border: OutlineInputBorder(),
                ),
                items: ExperienceLevel.values.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level.displayName, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedExperienceLevel = val);
                },
              ),
              const SizedBox(height: 16),

              // Location
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _cityController,
                      label: 'City',
                      hint: 'Amman / Dubai / Riyadh',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _countryController,
                      label: 'Country',
                      hint: 'Jordan / UAE / KSA',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Salary Range
              Text('Compensation & Salary', style: AppTypography.headlineSmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      controller: _minSalaryController,
                      label: 'Min Salary',
                      hint: '1000',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      controller: _maxSalaryController,
                      label: 'Max Salary',
                      hint: '2500',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _currency,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'JOD', child: Text('JOD (د.أ)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'SAR', child: Text('SAR (ر.س)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'AED', child: Text('AED (د.إ)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'USD', child: Text('USD (\$)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR (€)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'GBP', child: Text('GBP (£)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'KWD', child: Text('KWD (د.ك)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'QAR', child: Text('QAR (ر.ق)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'BHD', child: Text('BHD (د.ب)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'OMR', child: Text('OMR (ر.ع)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'EGP', child: Text('EGP (ج.م)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'IQD', child: Text('IQD (د.ع)', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _currency = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _isNegotiable,
                        onChanged: (val) => setState(() => _isNegotiable = val ?? false),
                      ),
                      const Text('Negotiable', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _isDisclosed,
                        onChanged: (val) => setState(() => _isDisclosed = val ?? true),
                      ),
                      const Text('Disclosed to candidates', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Required Skills
              Text('Required Skills', style: AppTypography.headlineSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _skillInputController,
                      hint: 'e.g. Flutter, Clean Architecture, SQL',
                      onFieldSubmitted: (_) => _addSkill(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    onPressed: _addSkill,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _requiredSkills.map((skill) {
                  return Chip(
                    label: Text(skill, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removeSkill(skill),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Description
              Text('Description & Criteria', style: AppTypography.headlineSmall),
              const SizedBox(height: 12),
              AppTextField(
                controller: _descriptionController,
                label: 'Role Summary / Description *',
                hint: 'Describe the core mission, team dynamics, and objectives...',
                maxLines: 4,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _responsibilitiesController,
                label: 'Key Responsibilities (One per line)',
                hint: '- Develop performant mobile applications\n- Collaborate with product design team\n- Write clean unit & widget tests',
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _requirementsController,
                label: 'Requirements & Qualifications (One per line)',
                hint: '- Bachelor degree in Computer Science\n- 3+ years Flutter experience\n- Strong understanding of State Management',
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              // Linked Assessment
              Text('Online Assessment (Optional)', style: AppTypography.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Link an exam template to automatically evaluate applicants.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Consumer<CompanyExamsProvider>(
                builder: (context, examsProv, _) {
                  final exams = examsProv.exams;
                  return DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _selectedExamId,
                    decoration: InputDecoration(
                      labelText: 'Select Assessment Template',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.quiz_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No Assessment Linked'),
                      ),
                      ...exams.map(
                        (e) => DropdownMenuItem<String?>(
                          value: e.id,
                          child: Text(
                            '${e.title} (${e.durationMinutes}m - ${e.passingPercentage}%)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedExamId = val);
                    },
                  );
                },
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSaving ? null : () => _submit(JobStatus.draft),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Save as Draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: isEditing ? 'Save Changes' : 'Publish Job',
                      isLoading: isSaving,
                      onPressed: () => _submit(JobStatus.published),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
