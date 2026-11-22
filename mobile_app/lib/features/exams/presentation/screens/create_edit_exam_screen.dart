import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../questions/presentation/providers/question_banks_provider.dart';
import '../../../questions/presentation/providers/questions_provider.dart';
import '../../domain/entities/exam_template.dart';
import '../providers/company_exams_provider.dart';

class CreateEditExamScreen extends StatefulWidget {
  final ExamTemplate? existingExam;

  const CreateEditExamScreen({
    super.key,
    this.existingExam,
  });

  @override
  State<CreateEditExamScreen> createState() => _CreateEditExamScreenState();
}

class _CreateEditExamScreenState extends State<CreateEditExamScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _durationController;
  late TextEditingController _passingController;

  bool _randomizeQuestions = true;
  bool _randomizeOptions = true;
  bool _proctoringEnabled = true;

  final Set<String> _selectedQuestionIds = {};
  final Set<String> _selectedBankIds = {};

  bool get isEditing => widget.existingExam != null;

  @override
  void initState() {
    super.initState();
    final exam = widget.existingExam;
    _titleController = TextEditingController(text: exam?.title ?? '');
    _descController = TextEditingController(text: exam?.description ?? '');
    _durationController = TextEditingController(text: (exam?.durationMinutes ?? 45).toString());
    _passingController = TextEditingController(text: (exam?.passingPercentage ?? 70).toString());

    if (exam != null) {
      _randomizeQuestions = exam.randomizeQuestions;
      _randomizeOptions = exam.randomizeOptions;
      _proctoringEnabled = exam.proctoringEnabled;
      _selectedQuestionIds.addAll(exam.questionIds);
      _selectedBankIds.addAll(exam.bankIds);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<QuestionBanksProvider>().loadBanks(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _durationController.dispose();
    _passingController.dispose();
    super.dispose();
  }

  void _openAiQuestionGeneratorModal(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final jobTitleController = TextEditingController(
      text: _titleController.text.isNotEmpty ? _titleController.text : 'Full-Stack Software Engineer',
    );
    String selectedDifficulty = 'MID';
    String selectedQuestionType = 'SINGLE_CHOICE';
    int questionCount = 5;
    bool isGenerating = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Generate Questions with AI',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'توليد أسئلة تقنية متقدمة بواسطة الذكاء الاصطناعي',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  AppTextField(
                    controller: jobTitleController,
                    label: 'Job Title / Technical Role (المسمى أو المهارة)',
                    hint: 'e.g. Flutter Mobile Engineer, Backend Node.js, DevOps',
                  ),
                  const SizedBox(height: 16),
                  const Text('Difficulty Level (مستوى الصعوبة):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['JUNIOR', 'MID', 'SENIOR'].map((diff) {
                      final isSelected = selectedDifficulty == diff;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(diff),
                          selected: isSelected,
                          onSelected: (_) => setModalState(() => selectedDifficulty = diff),
                          selectedColor: const Color(0xFF6366F1),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Question Type (نوع وصيغة الأسئلة):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      {'key': 'SINGLE_CHOICE', 'label': 'اختيار من متعدد (MCQ)'},
                      {'key': 'TRUE_FALSE', 'label': 'صح أو خطأ (True/False)'},
                      {'key': 'CODING', 'label': 'أكواد وتحدي عملي (Coding)'},
                      {'key': 'SHORT_ANSWER', 'label': 'مفاهيم وشرح (Concepts)'},
                      {'key': 'MIXED', 'label': 'شامل ومتنوع (Mixed)'},
                    ].map((typeItem) {
                      final isSelected = selectedQuestionType == typeItem['key'];
                      return ChoiceChip(
                        label: Text(typeItem['label']!),
                        selected: isSelected,
                        onSelected: (_) => setModalState(() => selectedQuestionType = typeItem['key']!),
                        selectedColor: const Color(0xFF6366F1),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Number of Questions (عدد الأسئلة):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [3, 5, 10, 15].map((cnt) {
                      final isSelected = questionCount == cnt;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$cnt Questions'),
                          selected: isSelected,
                          onSelected: (_) => setModalState(() => questionCount = cnt),
                          selectedColor: const Color(0xFF6366F1),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  if (errorMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF87171)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFF991B1B),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setModalState(() => errorMessage = null),
                            child: const Icon(Icons.close, color: Color(0xFF991B1B), size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome, size: 20),
                      label: Text(
                        isGenerating ? 'Generating with Gemini AI...' : 'Generate & Add to Exam ✨',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: isGenerating
                          ? null
                          : () async {
                              final role = jobTitleController.text.trim();
                              if (role.isEmpty) {
                                setModalState(() => errorMessage = "يرجى إدخال المسمى أو المهارة أولاً");
                                return;
                              }
                              setModalState(() {
                                isGenerating = true;
                                errorMessage = null;
                              });
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(ctx);
                              final questionsProvider = context.read<QuestionsProvider>();

                              try {
                                final banksProvider = context.read<QuestionBanksProvider>();
                                if (banksProvider.allBanks.isEmpty) {
                                  await banksProvider.loadBanks(user.uid);
                                }

                                String? targetBankId;
                                if (banksProvider.allBanks.isNotEmpty) {
                                  targetBankId = banksProvider.allBanks.first.id;
                                } else {
                                  targetBankId = await banksProvider.createBank(
                                    companyId: user.uid,
                                    title: 'AI Technical Questions Bank',
                                    description: 'Questions generated by AI assessment engine',
                                    category: 'Technical',
                                  );
                                }

                                if (targetBankId == null || targetBankId.isEmpty) {
                                  targetBankId = 'default_ai_bank';
                                }

                                final generated = await questionsProvider.generateQuestionsWithAI(
                                  companyId: user.uid,
                                  bankId: targetBankId,
                                  jobTitle: role,
                                  difficulty: selectedDifficulty,
                                  questionCount: questionCount,
                                  questionType: selectedQuestionType,
                                );

                                if (generated.isNotEmpty) {
                                  if (mounted) {
                                    setState(() {
                                      if (_titleController.text.isEmpty) {
                                        _titleController.text = '$role Assessment';
                                      }
                                      if (_descController.text.isEmpty) {
                                        _descController.text = 'Technical assessment evaluation for $role position.';
                                      }
                                      _selectedBankIds.add(targetBankId!);
                                      for (final q in generated) {
                                        _selectedQuestionIds.add(q.id);
                                      }
                                    });

                                    navigator.pop();
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text('✨ Successfully added ${generated.length} AI-generated questions to assessment!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } else {
                                  setModalState(() {
                                    errorMessage = "لم نتمكن من توليد أسئلة. يرجى التحقق وإعادة المحاولة.";
                                  });
                                }
                              } catch (e) {
                                setModalState(() {
                                  errorMessage = "حدث خطأ أثناء التوليد: ${e.toString()}";
                                });
                              } finally {
                                if (modalCtx.mounted) {
                                  setModalState(() => isGenerating = false);
                                }
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(jobTitleController.dispose);
  }

  void _openQuestionPickerModal(BuildContext context) {
    final banks = context.read<QuestionBanksProvider>().allBanks;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (_, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text('Select Questions from Banks', style: AppTypography.headlineSmall),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: banks.isEmpty
                      ? const Center(child: Text('No question banks found. Create a bank first.'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: banks.length,
                          itemBuilder: (context, index) {
                            final bank = banks[index];
                            return ExpansionTile(
                              title: Text(bank.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${bank.questionsCount} questions - ${bank.category}'),
                              onExpansionChanged: (expanded) {
                                if (expanded) {
                                  context.read<QuestionsProvider>().loadQuestions(bank.id);
                                }
                              },
                              children: [
                                Consumer<QuestionsProvider>(
                                  builder: (context, qProvider, _) {
                                    final bankQuestions = qProvider.allQuestions
                                        .where((q) => q.bankId == bank.id)
                                        .toList();

                                    if (qProvider.isLoading) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(child: CircularProgressIndicator()),
                                      );
                                    }

                                    if (bankQuestions.isEmpty) {
                                      return const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text('No questions in this bank.'),
                                      );
                                    }

                                    return Column(
                                      children: bankQuestions.map((q) {
                                        final isChecked = _selectedQuestionIds.contains(q.id);
                                        return CheckboxListTile(
                                          value: isChecked,
                                          title: Text(q.title, style: const TextStyle(fontSize: 13)),
                                          subtitle: Text(
                                            '${q.type.displayName} - ${q.difficulty.displayName} - ${q.points} pt',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                          onChanged: (val) {
                                            setModalState(() {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedQuestionIds.add(q.id);
                                                  _selectedBankIds.add(bank.id);
                                                } else {
                                                  _selectedQuestionIds.remove(q.id);
                                                }
                                              });
                                            });
                                          },
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedQuestionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 question for the assessment.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final duration = int.tryParse(_durationController.text.trim()) ?? 45;
    final passing = int.tryParse(_passingController.text.trim()) ?? 70;

    final provider = context.read<CompanyExamsProvider>();

    if (isEditing) {
      final updated = widget.existingExam!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        durationMinutes: duration,
        passingPercentage: passing,
        questionIds: _selectedQuestionIds.toList(),
        bankIds: _selectedBankIds.toList(),
        randomizeQuestions: _randomizeQuestions,
        randomizeOptions: _randomizeOptions,
        proctoringEnabled: _proctoringEnabled,
        totalQuestions: _selectedQuestionIds.length,
        updatedAt: DateTime.now(),
      );
      final ok = await provider.updateExam(updated);
      if (!mounted) return;
      if (ok) {
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to update assessment.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else {
      final id = await provider.createExam(
        companyId: user.uid,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        durationMinutes: duration,
        passingPercentage: passing,
        questionIds: _selectedQuestionIds.toList(),
        bankIds: _selectedBankIds.toList(),
        randomizeQuestions: _randomizeQuestions,
        randomizeOptions: _randomizeOptions,
        proctoringEnabled: _proctoringEnabled,
        totalQuestions: _selectedQuestionIds.length,
      );
      if (!mounted) return;
      if (id != null) {
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to create assessment.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<CompanyExamsProvider>().isSaving;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Exam Template' : 'New Exam Template'),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: AppButton(
            text: isEditing ? 'Save Assessment' : 'Create Assessment',
            isLoading: isSaving,
            onPressed: _handleSave,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppTextField(
              controller: _titleController,
              label: 'Exam Title',
              hint: 'e.g., Senior Mobile Developer Online Evaluation',
              validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _descController,
              label: 'Instructions & Guidelines for Candidates',
              hint: 'e.g., Complete in a quiet environment. Screen recording will monitor cheating.',
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Timing & Passing Score Row
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _durationController,
                    label: 'Duration (Minutes)',
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.timer_outlined),
                    validator: (val) {
                      final n = int.tryParse(val ?? '');
                      if (n == null || n < 5) return 'Min 5 mins';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _passingController,
                    label: 'Passing Score (%)',
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.verified_outlined),
                    validator: (val) {
                      final n = int.tryParse(val ?? '');
                      if (n == null || n < 1 || n > 100) return '1 - 100%';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Question Selection Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Assessment Questions',
                          style: AppTypography.headlineSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_selectedQuestionIds.length} Selected',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick questions from your categorized banks. Questions will be delivered securely to candidates.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => _openAiQuestionGeneratorModal(context),
                    icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    label: const Text('Generate Questions with AI (توليد بالذكاء الاصطناعي ✨)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _openQuestionPickerModal(context),
                    icon: const Icon(Icons.add_task),
                    label: const Text('Browse & Select from Banks'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Exam Security & Integrity Toggles
            Text('Security & Test Delivery', style: AppTypography.headlineSmall),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Randomize Question Sequence'),
              subtitle: const Text('Deliver questions in shuffled order for each candidate'),
              value: _randomizeQuestions,
              onChanged: (val) => setState(() => _randomizeQuestions = val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Randomize Answer Options'),
              subtitle: const Text('Shuffle choices for multiple-choice questions'),
              value: _randomizeOptions,
              onChanged: (val) => setState(() => _randomizeOptions = val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Proctoring & Anti-Cheat Monitor'),
              subtitle: const Text('Flag tab-switching, copy-pasting, and browser unfocus events'),
              value: _proctoringEnabled,
              onChanged: (val) => setState(() => _proctoringEnabled = val),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
