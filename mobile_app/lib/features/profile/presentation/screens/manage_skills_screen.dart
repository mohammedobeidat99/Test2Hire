import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/profile_provider.dart';

class ManageSkillsScreen extends StatefulWidget {
  const ManageSkillsScreen({super.key});

  @override
  State<ManageSkillsScreen> createState() => _ManageSkillsScreenState();
}

class _ManageSkillsScreenState extends State<ManageSkillsScreen> {
  final _skillInputController = TextEditingController();
  late List<String> _skills;

  final List<String> _popularSuggestions = [
    'Flutter',
    'Dart',
    'Firebase',
    'Cloud Firestore',
    'React',
    'Next.js',
    'TypeScript',
    'JavaScript',
    'Node.js',
    'REST APIs',
    'SQL',
    'PostgreSQL',
    'Git',
    'Docker',
    'Clean Architecture',
    'UI/UX Design',
    'Problem Solving',
    'Agile / Scrum',
  ];

  @override
  void initState() {
    super.initState();
    final current = context.read<ProfileProvider>().profile?.skills ?? [];
    _skills = List<String>.from(current);
  }

  @override
  void dispose() {
    _skillInputController.dispose();
    super.dispose();
  }

  void _addSkill(String skill) {
    final trimmed = skill.trim();
    if (trimmed.isEmpty) return;
    if (_skills.any((s) => s.toLowerCase() == trimmed.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skill is already in your list.')),
      );
      return;
    }
    setState(() {
      _skills.add(trimmed);
      _skillInputController.clear();
    });
  }

  void _removeSkill(String skill) {
    setState(() {
      _skills.remove(skill);
    });
  }

  Future<void> _handleSave() async {
    final provider = context.read<ProfileProvider>();
    final success = await provider.updateSkills(_skills);
    if (success && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final provider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n?.manageSkillsTitle ?? 'Manage Skills'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isArabic ? 'مهاراتك المكتسبة (${_skills.length})' : 'Your Skills (${_skills.length})', style: AppTypography.titleLarge),
              const SizedBox(height: 6),
              Text(
                isArabic ? 'أضف 3 مهارات على الأقل لزيادة فرص الترشيح للوظائف والاختبارات.' : 'Add at least 3 skills to match with relevant job postings and examination requirements.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 16),

              // Skill Input Field
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skillInputController,
                      decoration: InputDecoration(
                        hintText: isArabic ? 'اكتب مهارة (مثال: Flutter، Python)...' : 'Type a skill (e.g. Flutter, Go, GraphQL)...',
                        prefixIcon: Icon(Icons.code_rounded, size: 20),
                      ),
                      onSubmitted: _addSkill,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _addSkill(_skillInputController.text),
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(50, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Current Selected Skills Chips
              if (_skills.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skills.map((skill) {
                    return Chip(
                      label: Text(skill, style: AppTypography.labelLarge.copyWith(color: AppColors.primary)),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                      side: const BorderSide(color: AppColors.primaryLight, width: 1),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
                      onDeleted: () => _removeSkill(skill),
                    );
                  }).toList(),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text(
                      'No skills added yet. Select suggested skills below or type your own.',
                      style: AppTypography.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              Text('Suggested Skills', style: AppTypography.titleLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _popularSuggestions.map((suggestion) {
                  final isAdded = _skills.any((s) => s.toLowerCase() == suggestion.toLowerCase());
                  return ActionChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAdded) ...[
                          const Icon(Icons.check_rounded, size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                        ] else ...[
                          const Icon(Icons.add_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                        ],
                        Text(suggestion),
                      ],
                    ),
                    backgroundColor: isAdded ? AppColors.success.withValues(alpha: 0.1) : Colors.white,
                    side: BorderSide(
                      color: isAdded ? AppColors.success : AppColors.border,
                    ),
                    onPressed: () {
                      if (!isAdded) {
                        _addSkill(suggestion);
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 40),
              AppButton(
                text: l10n?.saveChanges ?? 'Save Skills',
                isLoading: provider.isSaving,
                onPressed: _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
