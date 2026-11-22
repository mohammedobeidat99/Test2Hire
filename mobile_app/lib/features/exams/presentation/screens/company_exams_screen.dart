import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/exam_template.dart';
import '../providers/company_exams_provider.dart';

class CompanyExamsScreen extends StatefulWidget {
  const CompanyExamsScreen({super.key});

  @override
  State<CompanyExamsScreen> createState() => _CompanyExamsScreenState();
}

class _CompanyExamsScreenState extends State<CompanyExamsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<CompanyExamsProvider>().listenCompanyExams(user.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompanyExamsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessments & Exam Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'New Assessment',
            onPressed: () => context.push('/company/exams/create'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/company/exams/create'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Assessment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = context.read<AuthProvider>().user;
          if (user != null) await provider.loadCompanyExams(user.uid);
        },
        child: provider.isLoading && provider.exams.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.exams.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  provider.errorMessage != null
                                      ? Icons.error_outline
                                      : Icons.assignment_outlined,
                                  size: 64,
                                  color: provider.errorMessage != null
                                      ? AppColors.error
                                      : AppColors.textTertiary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  provider.errorMessage != null
                                      ? 'Failed to Load Exam Templates'
                                      : 'No Exam Templates Yet',
                                  style: AppTypography.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.errorMessage ??
                                      'Create assessment templates or let AI generate starter role assessments for your company.',
                                  style: AppTypography.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: provider.isSaving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.auto_awesome, size: 18),
                                  label: Text(
                                    provider.isSaving
                                        ? 'Generating Starter Assessment...'
                                        : '⚡ Generate Flutter Assessment (إنشاء امتحان فوري)',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: provider.isSaving
                                      ? null
                                      : () async {
                                          final user = context.read<AuthProvider>().user;
                                          if (user == null) return;
                                          final messenger = ScaffoldMessenger.of(context);
                                          final examId = await provider.quickGenerateExamForRole(
                                            companyId: user.uid,
                                            roleTitle: 'Flutter Developer',
                                          );
                                          if (!mounted) return;
                                          if (examId != null) {
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(provider.successMessage ??
                                                    'Assessment template generated successfully!'),
                                                backgroundColor: AppColors.success,
                                              ),
                                            );
                                          } else {
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(provider.errorMessage ??
                                                    'Failed to generate starter assessment.'),
                                                backgroundColor: AppColors.error,
                                              ),
                                            );
                                          }
                                        },
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    itemCount: provider.exams.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final exam = provider.exams[index];
                      return _buildExamCard(context, exam);
                    },
                  ),
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, ExamTemplate exam) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
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
                  child: const Icon(Icons.assignment_turned_in_outlined, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exam.title, style: AppTypography.headlineSmall),
                      if (exam.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          exam.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => context.push('/company/exams/${exam.id}/edit', extra: exam),
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _buildSpecItem(Icons.help_outline, '${exam.totalQuestions} Questions'),
                _buildSpecItem(Icons.timer_outlined, '${exam.durationMinutes} mins'),
                _buildSpecItem(Icons.verified_outlined, '${exam.passingPercentage}% Pass'),
                _buildSpecItem(Icons.star_border_rounded, '${exam.totalPoints} Pts'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 15),
                    label: const Text(
                      'Assign to Applicants (تعيين لمرشحين)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => context.push('/company/jobs'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}
