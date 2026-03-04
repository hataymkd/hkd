import 'package:hkd/features/notifications/data/dtos/app_notification_dto.dart';
import 'package:hkd/features/notifications/domain/models/app_notification_model.dart';
import 'package:hkd/features/notifications/domain/repositories/notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository({
    required SupabaseClient client,
  }) : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<AppNotificationModel>> fetchMyNotifications({
    int limit = 50,
  }) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const <AppNotificationModel>[];
    }

    final dynamic raw = await _client
        .from('user_notifications')
        .select(
            'id, user_id, title, body, category, is_read, read_at, meta, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    final List<dynamic> rows = raw as List<dynamic>;
    return rows
        .map(
          (dynamic item) => AppNotificationDto.fromMap(
            (item as Map).cast<String, dynamic>(),
          ).toDomain(),
        )
        .toList(growable: false);
  }

  @override
  Future<int> fetchUnreadCount() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return 0;
    }

    final dynamic raw = await _client
        .from('user_notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);

    return (raw as List<dynamic>).length;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.trim().isEmpty) {
      return;
    }

    await _client.from('user_notifications').update(
      <String, dynamic>{
        'is_read': true,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      },
    ).eq('id', notificationId);
  }

  @override
  Future<void> markAllAsRead() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    await _client
        .from('user_notifications')
        .update(
          <String, dynamic>{
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          },
        )
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
  }) async {
    final String? userId = _client.auth.currentUser?.id;
    final String normalizedToken = token.trim();
    final String normalizedPlatform = platform.trim().toLowerCase();
    if (userId == null ||
        normalizedToken.isEmpty ||
        normalizedPlatform.isEmpty) {
      return;
    }

    await _client.from('device_push_tokens').upsert(
      <String, dynamic>{
        'user_id': userId,
        'token': normalizedToken,
        'platform': normalizedPlatform,
        'is_active': true,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  @override
  Future<void> sendNotification({
    required String title,
    required String body,
    AppNotificationCategory category = AppNotificationCategory.general,
    String? userId,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    final String normalizedTitle = title.trim();
    final String normalizedBody = body.trim();
    if (normalizedTitle.isEmpty || normalizedBody.isEmpty) {
      throw StateError('Bildirim basligi ve icerigi zorunludur.');
    }

    final FunctionResponse response = await _client.functions.invoke(
      'send_notification',
      body: <String, dynamic>{
        'title': normalizedTitle,
        'body': normalizedBody,
        'category': category.raw,
        if (userId != null && userId.trim().isNotEmpty)
          'user_id': userId.trim(),
        'data': data,
      },
    );

    if (response.status >= 400) {
      throw StateError('Bildirim gonderilemedi.');
    }
  }
}
