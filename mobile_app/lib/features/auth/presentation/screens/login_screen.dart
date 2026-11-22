import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterSuccess(AuthProvider authProvider) async {
    if (!mounted) return;
    final user = authProvider.user;
    if (user != null) {
      if (user.isCompany) {
        await authProvider.signOut();
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.business_center, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'بوابة الشركات على الويب',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'هذا الحساب مسجل كشركة / صاحب عمل.\n\nتم تخصيص منصة أصحاب الشركات بالكامل على الويب عبر أجهزة الكمبيوتر للحصول على أفضل تجربة لإدارة الوظائف، استعراض السير الذاتية (CVs)، ومتابعة المرشحين والاختبارات.\n\nيرجى تسجيل الدخول من خلال متصفح الويب على الحاسوب.',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        );
        return;
      }

      if (!user.isEmailVerified) {
        context.go('/verify-email');
      } else {
        context.go('/candidate/home');
      }
    }
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await authProvider.signIn(
      email: email,
      password: password,
      expectedIsCompany: false,
    );

    if (success && mounted) {
      await _navigateAfterSuccess(authProvider);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    FocusScope.of(context).unfocus();
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoading) return;

    try {
      final success = await authProvider.signInWithGoogle(isCompany: false);
      if (success && mounted) {
        await _navigateAfterSuccess(authProvider);
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
            content: Text('Failed to sign in with Google: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();

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
            // TOP ORGANIC CURVED WAVE HEADER
            ClipPath(
              clipper: HeaderWaveClipper(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 48, bottom: 56, left: 24, right: 24),
                decoration: const BoxDecoration(gradient: themeGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Language switcher button
                    Align(
                      alignment: Alignment.centerRight,
                      child: Consumer<LocaleProvider>(
                        builder: (context, localeProv, _) {
                          return TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => localeProv.toggleLocale(),
                            icon: const Icon(Icons.language_rounded, size: 15, color: Colors.white),
                            label: Text(
                              localeProv.isArabic ? 'English' : 'عربي',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Brand Badge / Logo Row
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppStrings.appName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Portal Badge: Job Seekers
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline_rounded, color: Colors.white, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              l10n?.candidatePortal ?? 'Candidate Portal',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title & Subtitle
                    Text(
                      l10n?.loginTitle ?? 'Welcome Back!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n?.loginSubtitle ?? 'Sign In To Your Candidate Account',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // MAIN CONTENT FORM
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Error Banner if present
                    if (authProvider.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authProvider.errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // EMAIL INPUT FIELD
                    _buildPillTextField(
                      controller: _emailController,
                      hintText: l10n?.emailHint ?? 'Email',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n?.emailRequired ?? 'Please enter your email';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return l10n?.emailRequired ?? 'Invalid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // PASSWORD INPUT FIELD
                    _buildPillTextField(
                      controller: _passwordController,
                      hintText: l10n?.passwordHint ?? 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n?.passwordRequired ?? 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return l10n?.passwordRequired ?? 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // PRIMARY LOG IN BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themePrimaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l10n?.loginButton ?? 'LOG IN',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // FORGOT PASSWORD
                    GestureDetector(
                      onTap: () => context.push('/forgot-password'),
                      child: Text(
                        l10n?.forgotPassword ?? 'Forgot Password?',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // DIVIDER: or continue with
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.grey.shade300,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            l10n?.orContinueWith ?? 'or continue with',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // GOOGLE SIGN IN BUTTON
                    GestureDetector(
                      onTap: authProvider.isLoading ? null : _handleGoogleSignIn,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.grey.shade300, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(shape: BoxShape.circle),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/google_logo.jpg',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.g_mobiledata_rounded,
                                    size: 26,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                l10n?.signInWithGoogle ?? 'Sign in with Google',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade800,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // REGISTER FOOTER
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l10n?.noAccountPrompt != null ? "${l10n!.noAccountPrompt} " : "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            context.push('/register/candidate');
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Text(
                              l10n?.signUpAction ?? 'Sign Up',
                              style: const TextStyle(
                                color: themePrimaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
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
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
class HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);

    // First swoop down
    final firstControlPoint = Offset(size.width * 0.35, size.height + 25);
    final firstEndPoint = Offset(size.width * 0.70, size.height - 25);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    // Second swoop up to right edge
    final secondControlPoint = Offset(size.width * 0.88, size.height - 55);
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
