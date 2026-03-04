import 'package:hkd/features/notifications/domain/models/app_notification_model.dart';

class AppNotificationDto {
  const AppNotificationDto({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.category,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.meta = const <String, dynamic>{},
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String category;
  final bool isRead;
  final String createdAt;
  final String? readAt;
  final Map<String, dynamic> meta;

  factory AppNotificationDto.fromMap(Map<String, dynamic> map) {
    final dynamic metaRaw = map['meta'];
    return AppNotificationDto(
      id: (map['id'] as String?) ?? '',
      userId: (map['user_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'general',
      isRead: (map['is_read'] as bool?) ?? false,
      createdAt: (map['created_at'] as String?) ?? '',
      readAt: map['read_at'] as String?,
      meta: metaRaw is Map
          ? metaRaw.cast<String, dynamic>()
          : const <String, dynamic>{},
    );
  }

  AppNotificationModel toDomain() {
    return AppNotificationModel(
      id: id,
      userId: userId,
      title: title,
      body: body,
      category: AppNotificationCategoryX.fromRaw(category),
      isRead: isRead,
      createdAt: DateTime.parse(createdAt),
      readAt: readAt == null ? null : DateTime.parse(readAt!),
      meta: meta,
    );
  }
}
