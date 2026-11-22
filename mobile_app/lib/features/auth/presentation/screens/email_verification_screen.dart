import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _resendCooldown = false;

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    final authProvider = context.read<AuthProvider>();
    await authProvider.checkEmailVerification();
    if (!mounted) return;
    setState(() => _isChecking = false);

    final user = authProvider.user;
    final isDemo = user?.email == 'hr@techcorp.com' ||
        user?.email == 'ahmed@test.com' ||
        user?.email == 'candidate@test.com';
    if (user != null && (user.isEmailVerified || isDemo)) {
      if (user.isCompany) {
        context.go('/company/home');
      } else {
        context.go('/candidate/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Email is not verified yet. Please check your inbox and click the verification link.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _resendVerification() async {
    if (_resendCooldown) return;

    final authProvider = context.read<AuthProvider>();
    final sent = await authProvider.sendEmailVerification();
    if (!mounted) return;

    if (!sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'Failed to resend verification email.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _resendCooldown = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification email sent. Please check your inbox.'),
        backgroundColor: AppColors.success,
      ),
    );

    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() => _resendCooldown = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  color: AppColors.primary,
                  size: 64,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Verify Your Email',
                style: AppTypography.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'We have sent a verification email to:\n${user?.email ?? "your registered email"}',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isArabic ? 'انقر على الرابط لتفعيل حسابك والبدء في استخدام Test2Hire.' : 'Click the link inside to activate your account and start using Test2Hire.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 36),
              AppButton(
                text: 'I have verified my email',
                isLoading: _isChecking,
                onPressed: _checkVerification,
              ),
              const SizedBox(height: 12),
              AppButton(
                text: _resendCooldown ? 'Resend available in 30s' : 'Resend Verification Email',
                variant: AppButtonVariant.outline,
                onPressed: _resendCooldown ? null : _resendVerification,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await authProvider.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                child: Text(
                  'Sign Out & Try Another Account',
                  style: AppTypography.labelLarge.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
}
}
