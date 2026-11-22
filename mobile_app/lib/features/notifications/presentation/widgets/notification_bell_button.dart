import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/notifications_provider.dart';

class NotificationBellButton extends StatelessWidget {
  final Color? iconColor;

  const NotificationBellButton({super.key, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationsProvider>(
      builder: (context, provider, child) {
        final unreadCount = provider.unreadCount;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_outlined,
                color: iconColor ?? AppColors.textPrimary,
              ),
              tooltip: 'الإشعارات',
              onPressed: () {
                context.push(AppRoutes.notifications);
              },
            ),
            if (unreadCount > 0)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount > 99 ? '+99' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
