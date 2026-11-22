import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';

class AssessmentSandboxScreen extends StatefulWidget {
  const AssessmentSandboxScreen({super.key});

  @override
  State<AssessmentSandboxScreen> createState() =>
      _AssessmentSandboxScreenState();
}

class _AssessmentSandboxScreenState extends State<AssessmentSandboxScreen> {
  int _currentStep = 0;
  bool _cameraChecked = true;
  bool _micChecked = true;
  bool _screenChecked = true;
  int _selectedAnswerIndex = -1;
  bool _practiceSubmitted = false;

  final List<Map<String, dynamic>> _sampleQuestions = [
    {
      'question':
          'في سياق تطوير البرمجيات المعمارية، ما هو الهدف الأساسي من Clean Architecture؟',
      'options': [
        'زيادة سرعة استجابة قاعدة البيانات فقط',
        'فصل منطق الأعمال وقواعد النطاق عن أطر العمل وواجهات المستخدم الخارجية',
        'الاستغناء الكامل عن اختبارات الوحدة الآلية',
        'تقليل حجم حزمة التطبيق البرمجي إلى الصفر',
      ],
      'correct': 1,
    },
    {
      'question':
          'ما هي الخاصية المميزة لنموذج النزاهة والمراقبة الذكية (AI Proctoring) أثناء الاختبار؟',
      'options': [
        'منع تشغيل متصفح الويب نهائياً',
        'رصد انصراف النظر، تبديل التبويبات، وظهور أشخاص آخرين في الإطار',
        'تسجيل محادثات الهاتف الشخصية خارج بيئة الامتحان',
        'إغلاق اتصال الإنترنت بالكامل',
      ],
      'correct': 1,
    },
  ];

  int _currentQuestionIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('البيئة التجريبية للمرشح (Assessment Sandbox)'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sandbox Info Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined,
                      color: AppColors.secondary, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'وضع المحاكاة والتدريب التجريبي (Practice Mode)',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'هذه بيئة محاكاة تجريبية حرة لا تؤثر إطلاقاً على تقييمك أو سجلك الوظيفي. تهدف لتأكيد جاهزية عتادك والتكيف مع نظام الاختبار.',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stepper
            Stepper(
              currentStep: _currentStep,
              physics: const NeverScrollableScrollPhysics(),
              onStepTapped: (step) => setState(() => _currentStep = step),
              controlsBuilder: (context, details) => const SizedBox.shrink(),
              steps: [
                Step(
                  title: const Text('فحص توافق الكاميرا والصوت (Hardware Check)'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0
                      ? StepState.complete
                      : StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        value: _cameraChecked,
                        onChanged: (v) => setState(() => _cameraChecked = v),
                        title: const Text('الكاميرا وتغذية الفيديو المباشرة'),
                        subtitle: const Text('رصد الوجه ومحاذاة الرأس'),
                        secondary: const Icon(Icons.videocam_outlined),
                      ),
                      SwitchListTile(
                        value: _micChecked,
                        onChanged: (v) => setState(() => _micChecked = v),
                        title: const Text('الميكروفون ومستوى الصوت'),
                        subtitle: const Text('رصد الأصوات الخلفية والضجيج'),
                        secondary: const Icon(Icons.mic_none_outlined),
                      ),
                      SwitchListTile(
                        value: _screenChecked,
                        onChanged: (v) => setState(() => _screenChecked = v),
                        title: const Text('مستشعر التبويبات والشاشة'),
                        subtitle: const Text('رصد مغادرة الإطار أو فتح نوافذ أخرى'),
                        secondary: const Icon(Icons.tab_outlined),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        text: 'التالي: خوض تجربة سؤال محاكاة',
                        onPressed: () => setState(() => _currentStep = 1),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('تجربة حل أسئلة محاكاة (Interactive Exam)'),
                  isActive: _currentStep >= 1,
                  state: _practiceSubmitted
                      ? StepState.complete
                      : StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'السؤال ${_currentQuestionIndex + 1} من ${_sampleQuestions.length}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const Text(
                                  '⏱️ 02:45 تجريبي',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _sampleQuestions[_currentQuestionIndex]['question'],
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...List.generate(
                              (_sampleQuestions[_currentQuestionIndex]['options']
                                      as List)
                                  .length,
                              (idx) {
                                final opt = _sampleQuestions[
                                        _currentQuestionIndex]['options'][idx]
                                    as String;
                                final isSelected =
                                    _selectedAnswerIndex == idx;
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedAnswerIndex = idx;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                              .withValues(alpha: 0.08)
                                          : AppColors.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            opt,
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_practiceSubmitted) ...[
                        AppButton(
                          text: _currentQuestionIndex <
                                  _sampleQuestions.length - 1
                              ? 'السؤال التالي'
                              : 'إنهاء الاختبار التجريبي',
                          onPressed: () {
                            if (_selectedAnswerIndex == -1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('يرجى اختيار إجابة أولاً')),
                              );
                              return;
                            }
                            if (_currentQuestionIndex <
                                _sampleQuestions.length - 1) {
                              setState(() {
                                _currentQuestionIndex++;
                                _selectedAnswerIndex = -1;
                              });
                            } else {
                              setState(() {
                                _practiceSubmitted = true;
                                _currentStep = 2;
                              });
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                Step(
                  title: const Text('تقرير الجاهزية والنتيجة (Readiness Report)'),
                  isActive: _currentStep >= 2,
                  state: _practiceSubmitted
                      ? StepState.complete
                      : StepState.indexed,
                  content: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.success, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'أنت جاهز تماماً للاختبارات الحقيقية!',
                                style: AppTypography.titleLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'تم التحقق من سلامة البيئة التجريبية، والتوافق مع محرك الأسئلة، ومستشعرات النزاهة الذكية بنجاح دون أي مشاكل تقنية.',
                          style: AppTypography.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          text: 'العودة للرئيسية',
                          variant: AppButtonVariant.outline,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
