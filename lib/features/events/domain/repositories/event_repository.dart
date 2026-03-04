import 'package:hkd/features/events/domain/models/community_event_model.dart';

abstract class EventRepository {
  Future<List<CommunityEventModel>> fetchUpcomingEvents({
    bool includeDrafts = false,
  });

  Future<void> createEvent({
    required String title,
    required String description,
    String? location,
    required DateTime startsAt,
    DateTime? endsAt,
  });

  Future<void> updateEventStatus({
    required String eventId,
    required CommunityEventStatus status,
  });

  Future<void> upsertMyRsvp({
    required String eventId,
    required EventRsvpStatus status,
    String? note,
  });
}
