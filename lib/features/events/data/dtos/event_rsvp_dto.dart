import 'package:hkd/features/events/domain/models/community_event_model.dart';

class EventRsvpDto {
  const EventRsvpDto({
    required this.eventId,
    required this.userId,
    required this.status,
  });

  final String eventId;
  final String userId;
  final String status;

  factory EventRsvpDto.fromMap(Map<String, dynamic> map) {
    return EventRsvpDto(
      eventId: map['event_id'] as String,
      userId: map['user_id'] as String,
      status: (map['status'] as String?) ?? 'going',
    );
  }
}

extension EventRsvpDtoMapper on EventRsvpDto {
  EventRsvpStatus toDomainStatus() {
    return eventRsvpStatusFromDb(status);
  }
}
