import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.12),
                    AppColors.primaryLight.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.10),
                    AppColors.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          isArabic ? 'اختر نوع الحساب' : 'SELECT ACCOUNT TYPE',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        isArabic ? 'انضم إلى Test2Hire اليوم' : 'Join Test2Hire Today',
                        style: AppTypography.displaySmall.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isArabic ? 'اختر الدور الذي يصف هدفك لتخصيص تجربتك في المنصة.' : 'Choose the role that best describes your objective to personalize your experience.',
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: 28),

                      // Candidate Role Card
                      _ModernRoleCard(
                        icon: Icons.person_search_rounded,
                        badgeText: isArabic ? 'باحث عن عمل' : 'JOB SEEKER',
                        badgeColor: AppColors.accent,
                        gradient: AppColors.brandGradient,
                        title: isArabic ? 'مرشح / باحث عن وظيفة' : 'Candidate / Job Seeker',
                        description: isArabic ? 'استكشف الوظائف الرائدة، خض التقييمات التقنية، واحصل على عروض عمل موثوقة.' : 'Browse premier tech vacancies, take verified technical assessments, and get hired faster.',
                        tags: isArabic ? ['⚡ اختبارات معتمدة', '🎯 مطابقة ذكية', '💼 تقديم سريع'] : const ['⚡ Verified Tests', '🎯 Auto-Match', '💼 Fast Apply'],
                        onTap: () => context.push('/register/candidate'),
                      ),
                      const SizedBox(height: 18),

                      // Company Role Card
                      _ModernRoleCard(
                        icon: Icons.business_rounded,
                        badgeText: isArabic ? 'بوابة الويب' : 'WEB PORTAL',
                        badgeColor: AppColors.primary,
                        gradient: AppColors.heroGradient,
                        title: isArabic ? 'شركة / صاحب عمل' : 'Employer / Enterprise',
                        description: isArabic ? 'انشر الوظائف، أنشئ بنوك الأسئلة، وأدر عمليات تقييم المرشحين والمقابلات بسهولة عبر الموقع.' : 'Publish jobs, craft customized coding and knowledge exams, and screen candidates seamlessly via the Web Portal.',
                        tags: isArabic ? ['🌐 بوابة الويب', '📊 استوديو الاختبارات', '👥 إدارة المتقدمين'] : const ['🌐 Web Portal', '📊 Assessment Studio', '👥 Applicant ATS'],
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('بوابة الشركات عبر الويب'),
                              content: const Text(
                                'تم تخصيص حسابات الشركات وأصحاب العمل بالكامل عبر بوابة الويب الرسمية لضمان أفضل تجربة لإدارة الوظائف والاختبارات والمقابلات.\n\nيرجى التسجيل أو الدخول عبر موقع الويب المخصص للشركات.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('حسناً'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 36),

                      // Sign in footer
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppColors.softShadow,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(isArabic ? 'لديك حساب بالفعل؟ ' : 'Already have an account? ', style: AppTypography.bodyMedium),
                              GestureDetector(
                                onTap: () => context.go('/login'),
                                child: Text(
                                  isArabic ? 'تسجيل الدخول' : 'Sign In',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernRoleCard extends StatelessWidget {
  final IconData icon;
  final String badgeText;
  final Color badgeColor;
  final Gradient gradient;
  final String title;
  final String description;
  final List<String> tags;
  final VoidCallback onTap;

  const _ModernRoleCard({
    required this.icon,
    required this.badgeText,
    required this.badgeColor,
    required this.gradient,
    required this.title,
    required this.description,
    required this.tags,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      boxShadow: AppColors.elevatedShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
