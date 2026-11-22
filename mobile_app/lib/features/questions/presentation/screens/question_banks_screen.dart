import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/question_bank.dart';
import '../providers/question_banks_provider.dart';

class QuestionBanksScreen extends StatefulWidget {
  const QuestionBanksScreen({super.key});

  @override
  State<QuestionBanksScreen> createState() => _QuestionBanksScreenState();
}

class _QuestionBanksScreenState extends State<QuestionBanksScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<QuestionBanksProvider>().listenBanks(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateBankDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final categoryController = TextEditingController(text: 'General');
    final tagsController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dCtx) => Consumer<QuestionBanksProvider>(
        builder: (ctx, bankProvider, _) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create Question Bank'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (bankProvider.errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        bankProvider.errorMessage!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  AppTextField(
                    controller: titleController,
                    label: 'Bank Title',
                    hint: 'e.g., Mobile Engineering & Flutter',
                    prefixIcon: const Icon(Icons.title),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: descController,
                    label: 'Description',
                    hint: 'Target assessment focus...',
                    maxLines: 2,
                    prefixIcon: const Icon(Icons.description_outlined),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: categoryController,
                    label: 'Category',
                    hint: 'e.g., Mobile, Backend, QA',
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: tagsController,
                    label: 'Tags (comma separated)',
                    hint: 'Flutter, Dart, State Management',
                    prefixIcon: const Icon(Icons.tag),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: bankProvider.isSaving
                  ? null
                  : () => Navigator.pop(dCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: bankProvider.isSaving
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        final user = context.read<AuthProvider>().user;
                        if (user == null) return;

                        final tags = tagsController.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();

                        final messenger = ScaffoldMessenger.of(this.context);
                        final id = await bankProvider.createBank(
                          companyId: user.uid,
                          title: titleController.text,
                          description: descController.text,
                          category: categoryController.text,
                          tags: tags,
                        );

                        if (!mounted) return;
                        if (id != null) {
                          if (dCtx.mounted) Navigator.pop(dCtx);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Question bank created successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: bankProvider.isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      titleController.dispose();
      descController.dispose();
      categoryController.dispose();
      tagsController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuestionBanksProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Banks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'New Question Bank',
            onPressed: () => _showCreateBankDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateBankDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Bank', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Overview Metrics Header
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildMetricChip('Total Banks', '${provider.totalBanksCount}', AppColors.primary),
                const SizedBox(width: 8),
                _buildMetricChip('Total Questions', '${provider.totalQuestionsCount}', AppColors.success),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => provider.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Search banks by title, tag, or topic...',
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

          // Category Chips
          if (provider.availableCategories.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: provider.availableCategories.map((cat) {
                  final isSelected = (provider.categoryFilter ?? 'All') == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) => provider.setCategoryFilter(cat == 'All' ? null : cat),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 8),

          // List of Question Banks
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final user = context.read<AuthProvider>().user;
                if (user != null) {
                  await provider.loadBanks(user.uid);
                }
              },
              child: provider.isLoading && provider.allBanks.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.banks.isEmpty && provider.errorMessage != null
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
                                        onPressed: () {
                                          final user =
                                              context.read<AuthProvider>().user;
                                          if (user != null) {
                                            provider.loadBanks(user.uid);
                                          }
                                        },
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
                      : provider.banks.isEmpty
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
                                          const Icon(Icons.folder_open_rounded,
                                              size: 64,
                                              color: AppColors.textTertiary),
                                          const SizedBox(height: 12),
                                          Text('No Question Banks Yet',
                                              style: AppTypography
                                                  .headlineSmall),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tap "New Bank" below to group your questions into topics or skill levels.',
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
                              itemCount: provider.banks.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final bank = provider.banks[index];
                                return _buildBankCard(context, bank);
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildBankCard(BuildContext context, QuestionBank bank) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/company/question-banks/${bank.id}', extra: bank),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.quiz_outlined, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bank.title, style: AppTypography.headlineSmall),
                        if (bank.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            bank.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      bank.category,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.help_outline, size: 15, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '${bank.questionsCount} Questions',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_border_rounded, size: 15, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '${bank.totalPoints} Pts',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Manage',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
