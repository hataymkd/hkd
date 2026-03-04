enum CommunityEventStatus {
  draft,
  published,
  cancelled,
  completed,
}

enum EventRsvpStatus {
  going,
  interested,
  notGoing,
}

extension CommunityEventStatusX on CommunityEventStatus {
  String get dbValue {
    switch (this) {
      case CommunityEventStatus.draft:
        return 'draft';
      case CommunityEventStatus.published:
        return 'published';
      case CommunityEventStatus.cancelled:
        return 'cancelled';
      case CommunityEventStatus.completed:
        return 'completed';
    }
  }

  String get label {
    switch (this) {
      case CommunityEventStatus.draft:
        return 'Taslak';
      case CommunityEventStatus.published:
        return 'Yayinda';
      case CommunityEventStatus.cancelled:
        return 'Iptal';
      case CommunityEventStatus.completed:
        return 'Tamamlandi';
    }
  }
}

extension EventRsvpStatusX on EventRsvpStatus {
  String get dbValue {
    switch (this) {
      case EventRsvpStatus.going:
        return 'going';
      case EventRsvpStatus.interested:
        return 'interested';
      case EventRsvpStatus.notGoing:
        return 'not_going';
    }
  }

  String get label {
    switch (this) {
      case EventRsvpStatus.going:
        return 'Katilacagim';
      case EventRsvpStatus.interested:
        return 'Ilgileniyorum';
      case EventRsvpStatus.notGoing:
        return 'Katilmayacagim';
    }
  }
}

CommunityEventStatus communityEventStatusFromDb(String raw) {
  switch (raw) {
    case 'draft':
      return CommunityEventStatus.draft;
    case 'cancelled':
      return CommunityEventStatus.cancelled;
    case 'completed':
      return CommunityEventStatus.completed;
    default:
      return CommunityEventStatus.published;
  }
}

EventRsvpStatus eventRsvpStatusFromDb(String raw) {
  switch (raw) {
    case 'interested':
      return EventRsvpStatus.interested;
    case 'not_going':
      return EventRsvpStatus.notGoing;
    default:
      return EventRsvpStatus.going;
  }
}

class CommunityEventModel {
  const CommunityEventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.goingCount,
    this.myRsvpStatus,
  });

  final String id;
  final String title;
  final String description;
  final String? location;
  final DateTime startsAt;
  final DateTime? endsAt;
  final CommunityEventStatus status;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int goingCount;
  final EventRsvpStatus? myRsvpStatus;

  CommunityEventModel copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    DateTime? startsAt,
    DateTime? endsAt,
    CommunityEventStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? goingCount,
    EventRsvpStatus? myRsvpStatus,
    bool clearRsvpStatus = false,
  }) {
    return CommunityEventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      goingCount: goingCount ?? this.goingCount,
      myRsvpStatus:
          clearRsvpStatus ? null : (myRsvpStatus ?? this.myRsvpStatus),
    );
  }
}
