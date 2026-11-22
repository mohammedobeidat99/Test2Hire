import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class RegisterCompanyScreen extends StatefulWidget {
  const RegisterCompanyScreen({super.key});

  @override
  State<RegisterCompanyScreen> createState() => _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends State<RegisterCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _industryController = TextEditingController(text: 'Technology');
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  final List<String> _industries = [
    'Technology',
    'Finance & Banking',
    'Healthcare & Biotech',
    'Education',
    'Engineering & Construction',
    'Retail & E-commerce',
    'Telecommunications',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _industryController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.registerCompany(
      email: _emailController.text,
      password: _passwordController.text,
      companyName: _companyNameController.text,
      industry: _industryController.text,
    );

    if (success && mounted) {
      context.go('/verify-email');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
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
                    AppColors.primaryLight.withValues(alpha: 0.15),
                    AppColors.primaryLight.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'ENTERPRISE REGISTRATION',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Register Your Company',
                      style: AppTypography.displaySmall.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Assess candidate skills through online examinations and manage interviews.',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: Color(0xFFB45309), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Company accounts undergo fast verification. You can create jobs and question banks immediately while setup completes.',
                              style: AppTypography.bodySmall.copyWith(
                                color: const Color(0xFF92400E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppCard(
                      padding: const EdgeInsets.all(22),
                      borderRadius: 22,
                      boxShadow: AppColors.elevatedShadow,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (authProvider.errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.errorSubtle,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      authProvider.errorMessage!,
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          AppTextField(
                            label: 'Company Name',
                            hint: 'Acme Corporation',
                            controller: _companyNameController,
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: const Icon(Icons.business_rounded, size: 20, color: AppColors.primaryLight),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Company name is required.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Industry Sector',
                                style: AppTypography.labelLarge.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _industryController.text,
                                items: _industries
                                    .map((industry) => DropdownMenuItem(
                                          value: industry,
                                          child: Text(industry, style: AppTypography.bodyLarge),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _industryController.text = val);
                                  }
                                },
                                decoration: InputDecoration(
                                  prefixIcon: Container(
                                    padding: const EdgeInsets.all(12),
                                    child: const Icon(Icons.category_outlined, size: 20, color: AppColors.primaryLight),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Work Email Address',
                            hint: 'hiring@company.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: const Icon(Icons.mail_outline_rounded, size: 20, color: AppColors.primaryLight),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Work email is required.';
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Please enter a valid work email.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Password',
                            hint: '••••••••',
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.primaryLight),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20,
                                color: AppColors.textTertiary,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required.';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Confirm Password',
                            hint: '••••••••',
                            controller: _confirmPasswordController,
                            obscureText: _obscurePassword,
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.primaryLight),
                            ),
                            validator: (value) {
                              if (value != _passwordController.text) {
                                return 'Passwords do not match.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          AppButton(
                            text: 'Register Company Account',
                            icon: Icons.business_center_rounded,
                            isLoading: authProvider.isLoading,
                            onPressed: _handleRegister,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(child: Divider(color: AppColors.border)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('or sign up with', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                              ),
                              const Expanded(child: Divider(color: AppColors.border)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: authProvider.isLoading
                                ? null
                                : () async {
                                    final success = await authProvider.signInWithGoogle(isCompany: true);
                                    if (!context.mounted) return;
                                    if (success) {
                                      context.go('/company/home');
                                    } else if (authProvider.errorMessage != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(authProvider.errorMessage!),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border, width: 1.2),
                                boxShadow: AppColors.softShadow,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(shape: BoxShape.circle),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/images/google_logo.jpg',
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => const Icon(
                                          Icons.g_mobiledata_rounded,
                                          size: 24,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Flexible(
                                    child: Text(
                                      'Sign up with Google',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
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
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('Already have an account? ', style: AppTypography.bodyMedium),
                            GestureDetector(
                              onTap: () => context.go('/login'),
                              child: Text(
                                'Sign In',
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
