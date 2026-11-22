import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendPasswordReset(_emailController.text);

    if (success && mounted) {
      setState(() => _emailSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(isArabic ? 'إعادة تعيين كلمة المرور' : 'Reset Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: _emailSent ? _buildSuccessView() : _buildFormView(authProvider),
        ),
      ),
    );
  }

  Widget _buildFormView(AuthProvider authProvider) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forgot Your Password?',
            style: AppTypography.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            isArabic ? 'أدخل عنوان بريدك الإلكتروني المسجل وسنرسل لك رابطاً لإعادة تعيين كلمة المرور.' : 'Enter your registered email address and we will send you instructions to reset your password.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 32),
          if (authProvider.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                authProvider.errorMessage!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
            const SizedBox(height: 16),
          ],
          AppTextField(
            label: 'Email Address',
            hint: 'name@example.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required.';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Please enter a valid email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          AppButton(
            text: isArabic ? 'إرسال رابط التعيين' : 'Send Reset Link',
            isLoading: authProvider.isLoading,
            onPressed: _handleResetPassword,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.success,
            size: 64,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Check Your Inbox',
          style: AppTypography.headlineLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'We have dispatched password reset instructions to:\n${_emailController.text}',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: 36),
        AppButton(
          text: 'Back to Sign In',
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}
