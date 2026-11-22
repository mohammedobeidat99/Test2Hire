import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

enum AppButtonVariant { primary, secondary, outline, text, danger }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.variant = AppButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isOutlineOrText =
        variant == AppButtonVariant.outline || variant == AppButtonVariant.text;
    final isEnabled = !isLoading && onPressed != null;

    final effectiveChild = isLoading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOutlineOrText ? AppColors.primary : Colors.white,
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        color: isOutlineOrText
                            ? AppColors.primary
                            : Colors.white,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

    Widget button;

    if (variant == AppButtonVariant.primary) {
      button = Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: isEnabled ? AppColors.primaryGradient : null,
          color: isEnabled ? null : AppColors.primary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isEnabled ? AppColors.primaryGlow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onPressed : null,
            borderRadius: BorderRadius.circular(14),
            child: Center(child: effectiveChild),
          ),
        ),
      );
    } else if (variant == AppButtonVariant.secondary) {
      button = Container(
        height: 52,
        decoration: BoxDecoration(
          color: isEnabled ? AppColors.secondary : AppColors.secondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isEnabled ? AppColors.softShadow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onPressed : null,
            borderRadius: BorderRadius.circular(14),
            child: Center(child: effectiveChild),
          ),
        ),
      );
    } else if (variant == AppButtonVariant.outline) {
      button = OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(
            color: isEnabled
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: effectiveChild,
      );
    } else if (variant == AppButtonVariant.danger) {
      button = Container(
        height: 52,
        decoration: BoxDecoration(
          color: isEnabled ? AppColors.error : AppColors.error.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isEnabled
              ? [BoxShadow(color: AppColors.error.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onPressed : null,
            borderRadius: BorderRadius.circular(14),
            child: Center(child: effectiveChild),
          ),
        ),
      );
    } else {
      button = TextButton(
        onPressed: isEnabled ? onPressed : null,
        child: effectiveChild,
      );
    }

    if (isFullWidth) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth.isFinite) {
            return SizedBox(
              width: constraints.maxWidth,
              height: 52,
              child: button,
            );
          }
          return SizedBox(height: 52, child: button);
        },
      );
    }

    return SizedBox(height: 52, child: button);
  }
}
