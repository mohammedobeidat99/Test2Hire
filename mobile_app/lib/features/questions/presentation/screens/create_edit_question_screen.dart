import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/question_bank.dart';
import '../providers/questions_provider.dart';

class CreateEditQuestionScreen extends StatefulWidget {
  final String bankId;
  final Question? existingQuestion;
  final QuestionBank? bank;

  const CreateEditQuestionScreen({
    super.key,
    required this.bankId,
    this.existingQuestion,
    this.bank,
  });

  @override
  State<CreateEditQuestionScreen> createState() => _CreateEditQuestionScreenState();
}

class _CreateEditQuestionScreenState extends State<CreateEditQuestionScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _pointsController;
  late TextEditingController _explanationController;
  late TextEditingController _codeSnippetController;
  late TextEditingController _tagsController;

  late QuestionType _selectedType;
  late QuestionDifficulty _selectedDifficulty;
  List<_OptionItem> _options = [];

  bool get isEditing => widget.existingQuestion != null;

  @override
  void initState() {
    super.initState();
    final q = widget.existingQuestion;
    _titleController = TextEditingController(text: q?.title ?? '');
    _descController = TextEditingController(text: q?.description ?? '');
    _pointsController = TextEditingController(text: (q?.points ?? 1).toString());
    _explanationController = TextEditingController(text: q?.explanation ?? '');
    _codeSnippetController = TextEditingController(text: q?.sampleCodeSnippet ?? '');
    _tagsController = TextEditingController(text: q?.tags.join(', ') ?? '');

    _selectedType = q?.type ?? QuestionType.singleChoice;
    _selectedDifficulty = q?.difficulty ?? QuestionDifficulty.medium;

    if (q != null && q.options.isNotEmpty) {
      _options = q.options
          .map((opt) => _OptionItem(
                id: opt.id,
                controller: TextEditingController(text: opt.text),
                isCorrect: opt.isCorrect,
              ))
          .toList();
    } else if (_selectedType == QuestionType.trueFalse) {
      _options = [
        _OptionItem(id: 'tf_1', controller: TextEditingController(text: 'True'), isCorrect: true),
        _OptionItem(id: 'tf_2', controller: TextEditingController(text: 'False'), isCorrect: false),
      ];
    } else {
      // Default 4 options for Multiple/Single choice
      _options = [
        _OptionItem(id: '1', controller: TextEditingController(), isCorrect: true),
        _OptionItem(id: '2', controller: TextEditingController(), isCorrect: false),
        _OptionItem(id: '3', controller: TextEditingController(), isCorrect: false),
        _OptionItem(id: '4', controller: TextEditingController(), isCorrect: false),
      ];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _pointsController.dispose();
    _explanationController.dispose();
    _codeSnippetController.dispose();
    _tagsController.dispose();
    for (final opt in _options) {
      opt.controller.dispose();
    }
    super.dispose();
  }

  void _disposeOptionControllers() {
    for (final opt in _options) {
      opt.controller.dispose();
    }
  }

  void _onTypeChanged(QuestionType? type) {
    if (type == null) return;
    setState(() {
      _selectedType = type;
      if (type == QuestionType.trueFalse) {
        _disposeOptionControllers();
        _options = [
          _OptionItem(id: 'tf_1', controller: TextEditingController(text: 'True'), isCorrect: true),
          _OptionItem(id: 'tf_2', controller: TextEditingController(text: 'False'), isCorrect: false),
        ];
      } else if (type == QuestionType.singleChoice || type == QuestionType.multipleChoice) {
        if (_options.length < 2) {
          _disposeOptionControllers();
          _options = [
            _OptionItem(id: '1', controller: TextEditingController(), isCorrect: true),
            _OptionItem(id: '2', controller: TextEditingController(), isCorrect: false),
            _OptionItem(id: '3', controller: TextEditingController(), isCorrect: false),
            _OptionItem(id: '4', controller: TextEditingController(), isCorrect: false),
          ];
        }
      }
    });
  }

  void _addOption() {
    setState(() {
      _options.add(
        _OptionItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          controller: TextEditingController(),
          isCorrect: false,
        ),
      );
    });
  }

  void _removeOption(int index) {
    if (_options.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 options are required.')),
      );
      return;
    }
    setState(() {
      _options[index].controller.dispose();
      _options.removeAt(index);
    });
  }

  void _selectSingleCorrect(int index) {
    setState(() {
      for (int i = 0; i < _options.length; i++) {
        _options[i].isCorrect = (i == index);
      }
    });
  }

  void _toggleMultipleCorrect(int index) {
    setState(() {
      _options[index].isCorrect = !_options[index].isCorrect;
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final isMCQ = _selectedType == QuestionType.singleChoice ||
        _selectedType == QuestionType.multipleChoice ||
        _selectedType == QuestionType.trueFalse;

    if (isMCQ) {
      final validOptions = _options.where((o) => o.controller.text.trim().isNotEmpty).toList();
      if (validOptions.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide text for at least 2 options.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final hasCorrect = validOptions.any((o) => o.isCorrect);
      if (!hasCorrect) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please designate at least one correct answer.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    final tags = _tagsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final optionsEntities = _options
        .where((o) => o.controller.text.trim().isNotEmpty)
        .map((o) => QuestionOption(
              id: o.id,
              text: o.controller.text.trim(),
              isCorrect: o.isCorrect,
            ))
        .toList();

    final correctAnswers = optionsEntities.where((o) => o.isCorrect).map((o) => o.id).toList();

    final points = int.tryParse(_pointsController.text.trim()) ?? 1;

    final question = Question(
      id: widget.existingQuestion?.id ?? '',
      bankId: widget.bankId,
      companyId: user.uid,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      type: _selectedType,
      difficulty: _selectedDifficulty,
      points: points,
      options: optionsEntities,
      correctAnswers: correctAnswers,
      sampleCodeSnippet: _codeSnippetController.text.trim().isNotEmpty ? _codeSnippetController.text.trim() : null,
      explanation: _explanationController.text.trim().isNotEmpty ? _explanationController.text.trim() : null,
      tags: tags,
      createdAt: widget.existingQuestion?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final provider = context.read<QuestionsProvider>();
    bool success;
    if (isEditing) {
      success = await provider.updateQuestion(question);
    } else {
      final id = await provider.createQuestion(question);
      success = id != null;
    }

    if (!mounted) return;
    if (success) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to save question.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<QuestionsProvider>().isSaving;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Question' : 'New Question'),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: AppButton(
            text: isEditing ? 'Save Changes' : 'Create Question',
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
            // Question Type Selector
            const Text('Question Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<QuestionType>(
              initialValue: _selectedType,
              isExpanded: true,
              items: QuestionType.values.map((t) {
                return DropdownMenuItem(value: t, child: Text(t.displayName));
              }).toList(),
              onChanged: isEditing ? null : _onTypeChanged,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 16),

            // Difficulty & Points Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Difficulty', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<QuestionDifficulty>(
                        initialValue: _selectedDifficulty,
                        isExpanded: true,
                        items: QuestionDifficulty.values.map((d) {
                          return DropdownMenuItem(value: d, child: Text(d.displayName));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedDifficulty = val);
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    controller: _pointsController,
                    label: 'Points',
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Points req';
                      final n = int.tryParse(val.trim());
                      if (n == null || n < 1) return '>= 1';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title
            AppTextField(
              controller: _titleController,
              label: 'Question Prompt / Title',
              hint: 'e.g., What is the difference between StatelessWidget and StatefulWidget?',
              maxLines: 2,
              validator: (val) => val == null || val.trim().isEmpty ? 'Question title is required' : null,
            ),
            const SizedBox(height: 16),

            // Description / Context (Optional)
            AppTextField(
              controller: _descController,
              label: 'Additional Context or Details (Optional)',
              hint: 'Elaborate scenario, edge cases, or test conditions...',
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Code Snippet Field (if coding)
            if (_selectedType == QuestionType.coding) ...[
              AppTextField(
                controller: _codeSnippetController,
                label: 'Starter Code / Solution Template',
                hint: 'class Solution {\n  void solve() {}\n}',
                maxLines: 6,
              ),
              const SizedBox(height: 20),
            ],

            // MCQ Options Builder
            if (_selectedType != QuestionType.coding && _selectedType != QuestionType.shortAnswer) ...[
              Row(
                children: [
                  Text('Answer Options', style: AppTypography.headlineSmall),
                  const Spacer(),
                  if (_selectedType != QuestionType.trueFalse)
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Option'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _selectedType == QuestionType.singleChoice || _selectedType == QuestionType.trueFalse
                    ? 'Select the radio button next to the correct answer.'
                    : 'Check all answers that are correct.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 12),

              ..._options.asMap().entries.map((entry) {
                final idx = entry.key;
                final opt = entry.value;
                final isSingle = _selectedType == QuestionType.singleChoice || _selectedType == QuestionType.trueFalse;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      if (isSingle)
                        IconButton(
                          icon: Icon(
                            opt.isCorrect ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: opt.isCorrect ? AppColors.success : AppColors.textTertiary,
                          ),
                          onPressed: () => _selectSingleCorrect(idx),
                          tooltip: 'Mark as Correct Answer',
                        )
                      else
                        Checkbox(
                          value: opt.isCorrect,
                          onChanged: (_) => _toggleMultipleCorrect(idx),
                        ),
                      Expanded(
                        child: TextField(
                          controller: opt.controller,
                          readOnly: _selectedType == QuestionType.trueFalse,
                          decoration: InputDecoration(
                            hintText: 'Option ${idx + 1}',
                            filled: true,
                            fillColor: opt.isCorrect
                                ? AppColors.success.withValues(alpha: 0.05)
                                : AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: opt.isCorrect ? AppColors.success : AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: opt.isCorrect ? AppColors.success : AppColors.border,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_selectedType != QuestionType.trueFalse && _options.length > 2)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                          onPressed: () => _removeOption(idx),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Explanation / Scoring Rubric
            AppTextField(
              controller: _explanationController,
              label: 'Explanation / Scoring Rubric',
              hint: 'Why is this correct? Rubric guidelines for grading...',
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Tags
            AppTextField(
              controller: _tagsController,
              label: 'Tags (comma separated)',
              hint: 'Flutter, State Management, OOP',
              prefixIcon: const Icon(Icons.tag),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _OptionItem {
  final String id;
  final TextEditingController controller;
  bool isCorrect;

  _OptionItem({
    required this.id,
    required this.controller,
    required this.isCorrect,
  });
}
