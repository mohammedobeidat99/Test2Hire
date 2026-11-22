import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

enum NotificationType {
  application,
  exam,
  interview,
  offer,
  system,
  community,
}

extension NotificationTypeX on NotificationType {
  String toServerString() {
    switch (this) {
      case NotificationType.application:
        return 'application';
      case NotificationType.exam:
        return 'exam';
      case NotificationType.interview:
        return 'interview';
      case NotificationType.offer:
        return 'offer';
      case NotificationType.community:
        return 'community';
      case NotificationType.system:
        return 'system';
    }
  }

  static NotificationType fromServerString(String? val) {
    if (val == null) return NotificationType.system;
    final lower = val.toLowerCase();
    if (lower.contains('community') || lower.contains('comment') || lower.contains('like') || lower.contains('post')) {
      return NotificationType.community;
    }
    if (lower.contains('exam') || lower.contains('assessment')) {
      return NotificationType.exam;
    }
    if (lower.contains('interview')) {
      return NotificationType.interview;
    }
    if (lower.contains('offer')) {
      return NotificationType.offer;
    }
    if (lower.contains('app') || lower.contains('job')) {
      return NotificationType.application;
    }
    return NotificationType.system;
  }

  String get displayName {
    switch (this) {
      case NotificationType.application:
        return 'Application';
      case NotificationType.exam:
        return 'Assessment';
      case NotificationType.interview:
        return 'Interview';
      case NotificationType.offer:
        return 'Job Offer';
      case NotificationType.community:
        return 'Community';
      case NotificationType.system:
        return 'System Alert';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.application:
        return Icons.work_outline_rounded;
      case NotificationType.exam:
        return Icons.quiz_outlined;
      case NotificationType.interview:
        return Icons.video_call_outlined;
      case NotificationType.offer:
        return Icons.verified_outlined;
      case NotificationType.community:
        return Icons.forum_rounded;
      case NotificationType.system:
        return Icons.notifications_none_rounded;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.application:
        return AppColors.primary;
      case NotificationType.exam:
        return AppColors.warning;
      case NotificationType.interview:
        return const Color(0xFF3B82F6);
      case NotificationType.offer:
        return const Color(0xFF047857);
      case NotificationType.community:
        return const Color(0xFF6366F1);
      case NotificationType.system:
        return AppColors.textSecondary;
    }
  }
}

class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final String? actionUrl;
  final String? entityId;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? readAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = NotificationType.system,
    this.actionUrl,
    this.entityId,
    this.data,
    this.isRead = false,
    this.createdAt,
    this.readAt,
  });

  NotificationItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    String? actionUrl,
    String? entityId,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      actionUrl: actionUrl ?? this.actionUrl,
      entityId: entityId ?? this.entityId,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isRead == other.isRead;

  @override
  int get hashCode => Object.hash(id, isRead);
}
