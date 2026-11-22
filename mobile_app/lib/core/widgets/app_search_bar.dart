import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onFilterTap;
  final bool showFilterButton;
  final bool isFilterActive;

  const AppSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.onFilterTap,
    this.showFilterButton = false,
    this.isFilterActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;

        return Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.softShadow,
                ),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    suffixIcon: hasText
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () {
                              controller.clear();
                              onClear?.call();
                              onChanged?.call('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            if (showFilterButton) ...[
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: isFilterActive ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFilterActive ? AppColors.primary : AppColors.border,
                  ),
                  boxShadow: AppColors.softShadow,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.tune_rounded,
                    color: isFilterActive ? Colors.white : AppColors.textPrimary,
                    size: 20,
                  ),
                  tooltip: 'Filters',
                  onPressed: onFilterTap,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
