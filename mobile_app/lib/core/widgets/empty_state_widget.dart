import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import 'app_button.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final Widget? customContent;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.customContent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 96 ? constraints.maxHeight - 96 : 0,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (customContent != null) ...[
              const SizedBox(height: 20),
              customContent!,
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              AppButton(
                text: actionLabel!,
                onPressed: onAction,
                icon: actionIcon,
                isFullWidth: false,
                variant: AppButtonVariant.primary,
              ),
            ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
