import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hkd/features/notifications/domain/repositories/notification_repository.dart';

class PushRegistrationService {
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static Future<void> ensureInitialized({
    required NotificationRepository notificationRepository,
  }) async {
    if (kIsWeb) {
      return;
    }
    if (_initialized) {
      return;
    }

    _initialized = true;

    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}

    await syncNow(notificationRepository: notificationRepository);

    _tokenRefreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
      unawaited(
        _safeRegisterToken(
          notificationRepository: notificationRepository,
          token: token,
        ),
      );
    });
  }

  static Future<void> syncNow({
    required NotificationRepository notificationRepository,
  }) async {
    if (kIsWeb) {
      return;
    }
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) {
        return;
      }
      await _safeRegisterToken(
        notificationRepository: notificationRepository,
        token: token,
      );
    } catch (_) {}
  }

  static Future<void> _safeRegisterToken({
    required NotificationRepository notificationRepository,
    required String token,
  }) async {
    try {
      await notificationRepository.registerPushToken(
        token: token,
        platform: _resolvePlatform(),
      );
    } catch (_) {}
  }

  static String _resolvePlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'ios';
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'unknown';
    }
  }
}
