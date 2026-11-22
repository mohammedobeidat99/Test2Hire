import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/app_routes.dart';
import 'package:mobile_app/core/constants/app_colors.dart';
import 'package:mobile_app/core/constants/app_typography.dart';
import 'package:mobile_app/core/services/url_launcher_helper.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile_app/features/notifications/domain/entities/notification_item.dart';
import 'package:mobile_app/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:provider/provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<NotificationsProvider>().listenToNotifications(uid);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('مركز الإشعارات'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (kDebugMode)
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final uid = auth.user?.uid;
                if (uid == null) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.add_alert_outlined, color: AppColors.primary),
                  tooltip: 'إرسال إشعار تجريبي',
                  onPressed: () async {
                    try {
                      await context.read<NotificationsProvider>().sendTestNotification(uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم إرسال إشعار تجريبي بنجاح!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطأ في إرسال الإشعار: $e')),
                        );
                      }
                    }
                  },
                );
              },
            ),
          Consumer<NotificationsProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () => provider.markAllAsRead(),
                icon: const Icon(Icons.done_all, size: 18, color: AppColors.primary),
                label: const Text(
                  'قراءة الكل',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
          Consumer<NotificationsProvider>(
            builder: (context, provider, _) {
              if (provider.notifications.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
                tooltip: 'حذف جميع الإشعارات',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('حذف جميع الإشعارات'),
                      content: const Text('هل أنت متأكد من رغبتك في حذف كافة الإشعارات بشكل نهائي؟'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(ctx);
                            final ok = await provider.clearAllNotifications();
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'تم حذف كافة الإشعارات بنجاح'
                                      : (provider.errorMessage ??
                                          'تعذر حذف الإشعارات'),
                                ),
                                backgroundColor:
                                    ok ? AppColors.success : AppColors.error,
                              ),
                            );
                          },
                          child: const Text('حذف الكل'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'جميع التنبيهات'),
            Tab(text: 'غير مقروءة'),
          ],
        ),
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationList(provider.notifications, provider),
              _buildNotificationList(provider.unreadNotifications, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationList(
    List<NotificationItem> items,
    NotificationsProvider provider,
  ) {
    final uid = context.read<AuthProvider>().user?.uid;

    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_off_outlined,
                size: 64,
                color: AppColors.textTertiary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد إشعارات حالياً',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'سيتم إعلامك فور وجود مستجدات أو تحديثات على حسابك.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              if (kDebugMode && uid != null) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await provider.sendTestNotification(uid);
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('إرسال إشعار تجريبي للتحقق'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        if (uid != null) {
          await provider.refreshNotifications(uid);
        }
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildNotificationCard(context, item, provider);
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationItem item,
    NotificationsProvider provider,
  ) {
    final themeColor = _getColorForType(item.type);
    final iconData = _getIconForType(item.type);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        final ok = await provider.deleteNotification(item.id);
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'تم حذف الإشعار'
                  : (provider.errorMessage ?? 'تعذر حذف الإشعار'),
            ),
            backgroundColor: ok ? null : AppColors.error,
            duration: const Duration(seconds: 2),
            action: ok
                ? SnackBarAction(
                    label: 'حسناً',
                    onPressed: () {},
                  )
                : null,
          ),
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!item.isRead) {
            provider.markAsRead(item.id);
          }
          final isCompany =
              context.read<AuthProvider>().user?.isCompany == true;
          final url = item.actionUrl?.trim();
          final parsedUri =
              (url != null && url.isNotEmpty) ? Uri.tryParse(url) : null;
          final jobId = parsedUri?.queryParameters['jobId']?.trim().isNotEmpty == true
              ? parsedUri!.queryParameters['jobId']!.trim()
              : item.data?['jobId']?.toString().trim();

          if (url != null && url.isNotEmpty) {
            final lower = url.toLowerCase();
            if (lower.startsWith('http://') || lower.startsWith('https://')) {
              UrlLauncherHelper.openUrl(context, url);
              return;
            }
            if (url.startsWith('/company/applicants')) {
              context.push(
                (jobId != null && jobId.isNotEmpty)
                    ? '/company/jobs/$jobId/applicants'
                    : AppRoutes.companyJobs,
              );
              return;
            }
            if (url.startsWith('/company/exams')) {
              context.push(AppRoutes.companyExams);
              return;
            }
            if (url.startsWith('/company/interviews')) {
              context.push(AppRoutes.companyInterviews);
              return;
            }
            if (url.startsWith('/company/offers')) {
              context.push(AppRoutes.companyOffers);
              return;
            }
            if (url.startsWith('/candidate/exams')) {
              context.push(AppRoutes.candidateExams);
              return;
            }
            if (url.startsWith('/candidate/interviews')) {
              context.push(AppRoutes.candidateInterviews);
              return;
            }
            if (url.startsWith('/candidate/offers')) {
              context.push(AppRoutes.candidateOffers);
              return;
            }
            if (url.startsWith('/candidate/applications')) {
              context.push(AppRoutes.candidateApplications);
              return;
            }
            if (url.startsWith('/')) {
              context.push(url);
              return;
            }
          }
          switch (item.type) {
            case NotificationType.exam:
              context.push(
                  isCompany ? AppRoutes.companyExams : AppRoutes.candidateExams);
              break;
            case NotificationType.interview:
              context.push(isCompany
                  ? AppRoutes.companyInterviews
                  : AppRoutes.candidateInterviews);
              break;
            case NotificationType.offer:
              context.push(isCompany
                  ? AppRoutes.companyOffers
                  : AppRoutes.candidateOffers);
              break;
            case NotificationType.application:
              context.push(isCompany
                  ? ((jobId != null && jobId.isNotEmpty)
                      ? '/company/jobs/$jobId/applicants'
                      : AppRoutes.companyJobs)
                  : AppRoutes.candidateApplications);
              break;
            case NotificationType.community:
              context.push(AppRoutes.community);
              break;
            case NotificationType.system:
              break;
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: item.isRead ? AppColors.surface : AppColors.primaryLight.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isRead
                  ? AppColors.border
                  : AppColors.primary.withValues(alpha: 0.3),
              width: item.isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: themeColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight:
                                  item.isRead ? FontWeight.w600 : FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.body,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatRelativeTime(item.createdAt),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Row(
                          children: [
                            if (item.actionUrl != null && item.actionUrl!.isNotEmpty) ...[
                              Text(
                                'عرض التفاصيل',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 10,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                            ],
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final ok = await provider.deleteNotification(item.id);
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'تم حذف الإشعار'
                                          : (provider.errorMessage ??
                                              'تعذر حذف الإشعار'),
                                    ),
                                    backgroundColor:
                                        ok ? null : AppColors.error,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorForType(NotificationType type) {
    return type.color;
  }

  IconData _getIconForType(NotificationType type) {
    return type.icon;
  }

  String _formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) {
      return 'الآن';
    } else if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} يوم';
    } else {
      return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
    }
  }
}
