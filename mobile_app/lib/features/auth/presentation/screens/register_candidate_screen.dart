import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';

class RegisterCandidateScreen extends StatefulWidget {
  const RegisterCandidateScreen({super.key});

  @override
  State<RegisterCandidateScreen> createState() => _RegisterCandidateScreenState();
}

class _RegisterCandidateScreenState extends State<RegisterCandidateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.registerCandidate(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
    );

    if (success && mounted) {
      context.go('/verify-email');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    FocusScope.of(context).unfocus();
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoading) return;

    try {
      final success = await authProvider.signInWithGoogle(isCompany: false);
      if (success && mounted) {
        context.go('/candidate/home');
      } else if (mounted && authProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إنشاء الحساب عبر Google: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final authProvider = context.watch<AuthProvider>();

    // Unified Theme colors: Red/Coral gradient matching Login Screen
    const themePrimaryColor = Color(0xFFE53935);
    const themeGradient = LinearGradient(
      colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // TOP ORGANIC CURVED WAVE HEADER (Identical to Login Screen)
            ClipPath(
              clipper: _HeaderWaveClipper(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 48, bottom: 52, left: 24, right: 24),
                decoration: const BoxDecoration(gradient: themeGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar: Back Button & Brand Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          onPressed: () => context.pop(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppStrings.appName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40), // Balance back button
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Portal Badge: Job Seekers
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.person_outline_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'بوابة الباحثين عن عمل',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Title & Subtitle
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isArabic ? 'سجل لاستكشاف الوظائف وخوض الاختبارات الذكية والمقابلات.' : 'Sign up to explore vacancies and take smart proctored tests.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // FORM BODY (Clean Pill inputs matching Login Screen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Error Banner if any
                    if (authProvider.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.errorSubtle,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                authProvider.errorMessage!,
                                style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Full Name Field
                    _buildPillTextField(
                      controller: _nameController,
                      hintText: 'Full Name',
                      icon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Full name is required.';
                        }
                        if (value.trim().length < 3) {
                          return 'Name must be at least 3 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Email Field
                    _buildPillTextField(
                      controller: _emailController,
                      hintText: 'Email Address',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
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
                    const SizedBox(height: 14),

                    // Password Field
                    _buildPillTextField(
                      controller: _passwordController,
                      hintText: 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                          color: Colors.grey.shade400,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                    const SizedBox(height: 14),

                    // Confirm Password Field
                    _buildPillTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleRegister(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                          color: Colors.grey.shade400,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Primary Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themePrimaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: authProvider.isLoading ? null : _handleRegister,
                        child: authProvider.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // OR DIVIDER
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // GOOGLE SIGN UP BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1E293B),
                          elevation: 0,
                          side: BorderSide(color: Colors.grey.shade300, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: authProvider.isLoading ? null : _handleGoogleSignIn,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
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
                            Flexible(
                              child: Text(
                                isArabic ? 'التسجيل بواسطة Google' : 'Sign up with Google',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // FOOTER: Sign In link
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context.go('/login'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Text(
                              isArabic ? 'تسجيل الدخول' : 'Log In',
                              style: TextStyle(
                                color: themePrimaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(28),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(icon, color: Colors.grey.shade400, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffixIcon,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

// Organic Curved Wave Clipper matching Reference Design
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);

    // First swoop down
    final firstControlPoint = Offset(size.width * 0.35, size.height + 20);
    final firstEndPoint = Offset(size.width * 0.70, size.height - 25);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    // Second swoop up to right edge
    final secondControlPoint = Offset(size.width * 0.88, size.height - 50);
    final secondEndPoint = Offset(size.width, size.height - 18);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
