import 'package:hkd/features/notifications/domain/models/app_notification_model.dart';

abstract class NotificationRepository {
  Future<List<AppNotificationModel>> fetchMyNotifications({
    int limit = 50,
  });

  Future<int> fetchUnreadCount();

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead();

  Future<void> registerPushToken({
    required String token,
    required String platform,
  });

  Future<void> sendNotification({
    required String title,
    required String body,
    AppNotificationCategory category = AppNotificationCategory.general,
    String? userId,
    Map<String, dynamic> data = const <String, dynamic>{},
  });
}
