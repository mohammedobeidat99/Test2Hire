import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/session_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _introKey = GlobalKey<IntroductionScreenState>();

  Future<void> _finishOnboarding() async {
    await SessionService.setOnboardingSeen();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 26.0,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
      bodyTextStyle: TextStyle(
        fontSize: 15.0,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
      bodyPadding: EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.only(top: 40.0, bottom: 20.0),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: IntroductionScreen(
          key: _introKey,
          globalBackgroundColor: Colors.white,
          allowImplicitScrolling: true,
          pages: [
            // Slide 1: Welcome & AI-Powered Assessments
            PageViewModel(
              title: "التقييم الذكي والموثوق",
              body: "منصة ${AppStrings.appName} توفر بيئة اختبارات تقنية ذكية مدعومة بالذكاء الاصطناعي لقياس المهارات بدقة وموضوعية.",
              image: _buildIllustration(
                icon: Icons.psychology_alt_rounded,
                gradientColors: [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
                badgeIcon: Icons.auto_awesome_rounded,
              ),
              decoration: pageDecoration,
            ),

            // Slide 2: Real-time Testing & Anti-cheating
            PageViewModel(
              title: "اختبارات مباشرة ومحمية",
              body: "أداء الامتحانات التقنية والبرمجية عبر المتصفح والجهاز مع نظام مراقبة متطور وتوقيت زمني دقيق.",
              image: _buildIllustration(
                icon: Icons.laptop_chromebook_rounded,
                gradientColors: [const Color(0xFF0284C7), const Color(0xFF38BDF8)],
                badgeIcon: Icons.verified_user_rounded,
              ),
              decoration: pageDecoration,
            ),

            // Slide 3: Opportunities & Job Matching
            PageViewModel(
              title: "بوابتك للوظائف المرموقة",
              body: "ربط مباشر بين الكفاءات وأصحاب الشركات والمؤسسات لتقديم أفضل الفرص التوظيفية المعتمدة على جدارتك.",
              image: _buildIllustration(
                icon: Icons.business_center_rounded,
                gradientColors: [const Color(0xFFE53935), const Color(0xFFFF5252)],
                badgeIcon: Icons.handshake_rounded,
              ),
              decoration: pageDecoration,
            ),
          ],
          onDone: _finishOnboarding,
          onSkip: _finishOnboarding,
          showSkipButton: true,
          skipOrBackFlex: 0,
          nextFlex: 0,
          showBackButton: false,
          skip: const Text(
            'تخطي',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          next: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          done: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text(
              'ابدأ الآن',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
          curve: Curves.fastLinearToSlowEaseIn,
          controlsMargin: const EdgeInsets.all(16),
          controlsPadding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
          dotsDecorator: DotsDecorator(
            size: const Size(8.0, 8.0),
            color: Colors.grey.shade300,
            activeSize: const Size(22.0, 8.0),
            activeColor: const Color(0xFFE53935),
            activeShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25.0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration({
    required IconData icon,
    required List<Color> gradientColors,
    required IconData badgeIcon,
  }) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background soft halo
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gradientColors.first.withValues(alpha: 0.08),
            ),
          ),
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gradientColors.first.withValues(alpha: 0.12),
            ),
          ),
          // Main circle with gradient
          Container(
            width: 125,
            height: 125,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 62,
              color: Colors.white,
            ),
          ),
          // Mini floating badge
          Positioned(
            right: 18,
            top: 24,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                badgeIcon,
                size: 20,
                color: gradientColors.first,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
