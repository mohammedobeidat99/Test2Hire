import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import 'app_button.dart';

class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.errorSubtle,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              Localizations.localeOf(context).languageCode == 'ar' ? 'حدث خطأ ما' : 'Something went wrong',
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              AppButton(
                text: retryLabel,
                onPressed: onRetry,
                icon: Icons.refresh_rounded,
                isFullWidth: false,
                variant: AppButtonVariant.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
