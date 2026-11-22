import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/question_bank.dart';
import '../providers/questions_provider.dart';

class QuestionBankDetailScreen extends StatefulWidget {
  final String bankId;
  final QuestionBank? initialBank;

  const QuestionBankDetailScreen({
    super.key,
    required this.bankId,
    this.initialBank,
  });

  @override
  State<QuestionBankDetailScreen> createState() => _QuestionBankDetailScreenState();
}

class _QuestionBankDetailScreenState extends State<QuestionBankDetailScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuestionsProvider>().listenQuestions(widget.bankId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showQuestionDetails(BuildContext context, Question q) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                _buildDifficultyBadge(q.difficulty),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    q.type.displayName,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const Spacer(),
                Text(
                  '${q.points} Point${q.points > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(q.title, style: AppTypography.headlineSmall),
            if (q.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(q.description, style: AppTypography.bodyMedium),
            ],
            if (q.sampleCodeSnippet != null && q.sampleCodeSnippet!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Starter Code / Snippet:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  q.sampleCodeSnippet!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
            if (q.options.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Options & Answers:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              ...q.options.map((opt) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: opt.isCorrect
                        ? AppColors.success.withValues(alpha: 0.08)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: opt.isCorrect
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        opt.isCorrect ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18,
                        color: opt.isCorrect ? AppColors.success : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          opt.text,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: opt.isCorrect ? FontWeight.bold : FontWeight.normal,
                            color: opt.isCorrect ? AppColors.success : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (opt.isCorrect)
                        const Text(
                          'Correct',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                        ),
                    ],
                  ),
                );
              }),
            ],
            if (q.explanation != null && q.explanation!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Explanation / Rubric:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text(q.explanation!, style: AppTypography.bodySmall),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push(
                        '/company/question-banks/${widget.bankId}/questions/${q.id}/edit',
                        extra: q,
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Question'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final provider = context.read<QuestionsProvider>();
                      final messenger = ScaffoldMessenger.of(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Delete Question?'),
                          content: Text('Are you sure you want to remove "${q.title}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              child: const Text('Delete', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final ok = await provider.deleteQuestion(
                            q.id, widget.bankId);
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Question deleted.'
                                  : (provider.errorMessage ??
                                      'Failed to delete question.'),
                            ),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.error,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                    label: const Text('Delete', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openAiGeneratorDialog(BuildContext context, String bankTitle) {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final jobTitleController = TextEditingController(text: bankTitle);
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
                    label: 'Technical Domain / Role (المجال أو المهارة)',
                    hint: 'e.g. Flutter, React, Backend API, Cloud Infrastructure',
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
                        isGenerating ? 'Generating with Gemini AI...' : 'Generate & Save to Bank ✨',
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

                              try {
                                final questionsProvider = context.read<QuestionsProvider>();
                                final generated = await questionsProvider.generateQuestionsWithAI(
                                  companyId: user.uid,
                                  bankId: widget.bankId,
                                  jobTitle: role,
                                  difficulty: selectedDifficulty,
                                  questionCount: questionCount,
                                  questionType: selectedQuestionType,
                                );

                                if (generated.isNotEmpty) {
                                  if (mounted) {
                                    navigator.pop();
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text('✨ Added ${generated.length} AI-generated questions to $bankTitle!'),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuestionsProvider>();
    final bankTitle = widget.initialBank?.title ?? 'Question Pool';

    return Scaffold(
      appBar: AppBar(
        title: Text(bankTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
            tooltip: 'Generate Questions with AI (توليد بالذكاء الاصطناعي)',
            onPressed: () => _openAiGeneratorDialog(context, bankTitle),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Question',
            onPressed: () => context.push(
              '/company/question-banks/${widget.bankId}/questions/create',
              extra: widget.initialBank,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          '/company/question-banks/${widget.bankId}/questions/create',
          extra: widget.initialBank,
        ),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Question', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Stat chips
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildMetricChip('Total', '${provider.totalCount}', AppColors.primary),
                const SizedBox(width: 8),
                _buildMetricChip('Easy', '${provider.easyCount}', AppColors.success),
                const SizedBox(width: 8),
                _buildMetricChip('Medium', '${provider.mediumCount}', AppColors.warning),
                const SizedBox(width: 8),
                _buildMetricChip('Hard', '${provider.hardCount}', AppColors.error),
                const SizedBox(width: 8),
                _buildMetricChip('Points', '${provider.totalPoints}', const Color(0xFF8B5CF6)),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => provider.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Search questions or keywords...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          provider.setSearchQuery(null);
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),

          // Filter Chips (Difficulty & Type)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Levels'),
                  selected: provider.difficultyFilter == null,
                  onSelected: (_) => provider.setDifficultyFilter(null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Easy'),
                  selected: provider.difficultyFilter == QuestionDifficulty.easy,
                  onSelected: (_) => provider.setDifficultyFilter(
                    provider.difficultyFilter == QuestionDifficulty.easy ? null : QuestionDifficulty.easy,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Medium'),
                  selected: provider.difficultyFilter == QuestionDifficulty.medium,
                  onSelected: (_) => provider.setDifficultyFilter(
                    provider.difficultyFilter == QuestionDifficulty.medium ? null : QuestionDifficulty.medium,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Hard'),
                  selected: provider.difficultyFilter == QuestionDifficulty.hard,
                  onSelected: (_) => provider.setDifficultyFilter(
                    provider.difficultyFilter == QuestionDifficulty.hard ? null : QuestionDifficulty.hard,
                  ),
                ),
              ],
            ),
          ),

          // Question list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.loadQuestions(widget.bankId),
              child: provider.isLoading && provider.allQuestions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.questions.isEmpty && provider.errorMessage != null
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline,
                                          size: 48, color: AppColors.error),
                                      const SizedBox(height: 12),
                                      Text(
                                        provider.errorMessage!,
                                        style: AppTypography.bodySmall,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: () => provider
                                            .loadQuestions(widget.bankId),
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : provider.questions.isEmpty
                          ? LayoutBuilder(
                              builder: (context, constraints) =>
                                  SingleChildScrollView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.quiz_outlined,
                                              size: 64,
                                              color: AppColors.textTertiary),
                                          const SizedBox(height: 12),
                                          Text('No Questions Found',
                                              style: AppTypography
                                                  .headlineSmall),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tap "Add Question" below to add single choice, multiple choice, or coding tasks.',
                                            style: AppTypography.bodySmall,
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 88),
                              itemCount: provider.questions.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final q = provider.questions[index];
                                return Card(
                                  elevation: 0.5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(
                                        color: AppColors.border),
                                  ),
                                  child: ListTile(
                                    onTap: () =>
                                        _showQuestionDetails(context, q),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    leading: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      q.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          _buildDifficultyBadge(q.difficulty),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              q.type.displayName,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${q.points} pt',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary),
                                        ),
                                        const Icon(Icons.chevron_right,
                                            size: 16,
                                            color: AppColors.textTertiary),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(QuestionDifficulty difficulty) {
    Color bg;
    Color fg;
    switch (difficulty) {
      case QuestionDifficulty.easy:
        bg = AppColors.success.withValues(alpha: 0.1);
        fg = AppColors.success;
        break;
      case QuestionDifficulty.medium:
        bg = AppColors.warning.withValues(alpha: 0.1);
        fg = AppColors.warning;
        break;
      case QuestionDifficulty.hard:
        bg = AppColors.error.withValues(alpha: 0.1);
        fg = AppColors.error;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        difficulty.displayName,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
