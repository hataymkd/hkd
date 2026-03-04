enum AppNotificationCategory {
  general,
  announcement,
  membership,
  payment,
  job,
}

extension AppNotificationCategoryX on AppNotificationCategory {
  static AppNotificationCategory fromRaw(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'announcement':
        return AppNotificationCategory.announcement;
      case 'membership':
        return AppNotificationCategory.membership;
      case 'payment':
        return AppNotificationCategory.payment;
      case 'job':
        return AppNotificationCategory.job;
      default:
        return AppNotificationCategory.general;
    }
  }

  String get raw {
    switch (this) {
      case AppNotificationCategory.announcement:
        return 'announcement';
      case AppNotificationCategory.membership:
        return 'membership';
      case AppNotificationCategory.payment:
        return 'payment';
      case AppNotificationCategory.job:
        return 'job';
      case AppNotificationCategory.general:
        return 'general';
    }
  }

  String get label {
    switch (this) {
      case AppNotificationCategory.announcement:
        return 'Duyuru';
      case AppNotificationCategory.membership:
        return 'Uyelik';
      case AppNotificationCategory.payment:
        return 'Odeme';
      case AppNotificationCategory.job:
        return 'Is Pazari';
      case AppNotificationCategory.general:
        return 'Genel';
    }
  }
}

class AppNotificationModel {
  const AppNotificationModel({
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
  final AppNotificationCategory category;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> meta;

  AppNotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    AppNotificationCategory? category,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
    Map<String, dynamic>? meta,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      meta: meta ?? this.meta,
    );
  }
}
