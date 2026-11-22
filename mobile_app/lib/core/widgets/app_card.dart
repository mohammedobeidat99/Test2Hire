import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final BorderSide? border;
  final double borderRadius;
  final List<BoxShadow>? boxShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.color,
    this.border,
    this.borderRadius = 14,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = border ?? const BorderSide(color: AppColors.border, width: 1);
    final effectiveRadius = BorderRadius.circular(borderRadius);

    Widget cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: effectiveBorder.color,
          width: effectiveBorder.width,
        ),
        boxShadow: boxShadow ?? AppColors.softShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          borderRadius: effectiveRadius,
          child: InkWell(
            onTap: onTap,
            borderRadius: effectiveRadius,
            splashColor: AppColors.primarySubtle,
            child: cardContent,
          ),
        ),
      );
    }

    if (margin != null) {
      return Padding(
        padding: margin!,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
