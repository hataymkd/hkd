import 'dart:collection';

import 'package:hkd/features/events/data/dtos/community_event_dto.dart';
import 'package:hkd/features/events/data/dtos/event_rsvp_dto.dart';
import 'package:hkd/features/events/domain/models/community_event_model.dart';
import 'package:hkd/features/events/domain/repositories/event_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseEventRepository implements EventRepository {
  SupabaseEventRepository({
    required SupabaseClient client,
  }) : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<CommunityEventModel>> fetchUpcomingEvents({
    bool includeDrafts = false,
  }) async {
    final String userId = _requireCurrentUserId();

    dynamic request = _client
        .from('community_events')
        .select(
          'id, title, description, location, starts_at, ends_at, status, '
          'created_by, created_at, updated_at',
        )
        .order('starts_at', ascending: true);

    if (!includeDrafts) {
      request = request.eq('status', 'published');
    }

    final dynamic eventRaw = await request;
    final List<dynamic> eventRows = eventRaw as List<dynamic>;

    if (eventRows.isEmpty) {
      return const <CommunityEventModel>[];
    }

    final List<String> eventIds = eventRows
        .map((dynamic row) => ((row as Map)['id'] as String))
        .toList(growable: false);

    final Map<String, EventRsvpStatus> myRsvpStatusByEventId =
        await _fetchMyRsvpStatuses(userId: userId, eventIds: eventIds);
    final Map<String, int> goingCountByEventId = await _fetchGoingCounts(
      eventIds: eventIds,
    );

    final List<CommunityEventModel> items = eventRows.map((dynamic rawItem) {
      final CommunityEventDto dto = CommunityEventDto.fromMap(
        (rawItem as Map).cast<String, dynamic>(),
      );
      return dto.toDomain(
        myRsvpStatus: myRsvpStatusByEventId[dto.id],
        goingCount: goingCountByEventId[dto.id] ?? 0,
      );
    }).toList(growable: false);

    return UnmodifiableListView<CommunityEventModel>(items);
  }

  @override
  Future<void> createEvent({
    required String title,
    required String description,
    String? location,
    required DateTime startsAt,
    DateTime? endsAt,
  }) async {
    final String userId = _requireCurrentUserId();
    await _client.from('community_events').insert(
      <String, dynamic>{
        'title': title.trim(),
        'description': description.trim(),
        'location': _nullableTrim(location),
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
        'status': 'published',
        'created_by': userId,
      },
    );
  }

  @override
  Future<void> updateEventStatus({
    required String eventId,
    required CommunityEventStatus status,
  }) async {
    await _client.from('community_events').update(
      <String, dynamic>{
        'status': status.dbValue,
      },
    ).eq('id', eventId);
  }

  @override
  Future<void> upsertMyRsvp({
    required String eventId,
    required EventRsvpStatus status,
    String? note,
  }) async {
    final String userId = _requireCurrentUserId();
    await _client.from('community_event_rsvps').upsert(
      <String, dynamic>{
        'event_id': eventId,
        'user_id': userId,
        'status': status.dbValue,
        'note': _nullableTrim(note),
      },
      onConflict: 'event_id,user_id',
    );
  }

  Future<Map<String, EventRsvpStatus>> _fetchMyRsvpStatuses({
    required String userId,
    required List<String> eventIds,
  }) async {
    if (eventIds.isEmpty) {
      return const <String, EventRsvpStatus>{};
    }

    final dynamic raw = await _client
        .from('community_event_rsvps')
        .select('event_id, user_id, status')
        .eq('user_id', userId)
        .inFilter('event_id', eventIds);

    final Map<String, EventRsvpStatus> map = <String, EventRsvpStatus>{};
    for (final dynamic item in (raw as List<dynamic>)) {
      final EventRsvpDto dto = EventRsvpDto.fromMap(
        (item as Map).cast<String, dynamic>(),
      );
      map[dto.eventId] = dto.toDomainStatus();
    }
    return map;
  }

  Future<Map<String, int>> _fetchGoingCounts({
    required List<String> eventIds,
  }) async {
    if (eventIds.isEmpty) {
      return const <String, int>{};
    }

    final dynamic raw = await _client
        .from('community_event_rsvps')
        .select('event_id')
        .eq('status', 'going')
        .inFilter('event_id', eventIds);

    final Map<String, int> counts = <String, int>{};
    for (final dynamic item in (raw as List<dynamic>)) {
      final String eventId = ((item as Map)['event_id'] as String?) ?? '';
      if (eventId.trim().isEmpty) {
        continue;
      }
      counts[eventId] = (counts[eventId] ?? 0) + 1;
    }
    return counts;
  }

  String _requireCurrentUserId() {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('Oturum bulunamadi. Lutfen tekrar giris yapin.');
    }
    return userId;
  }

  String? _nullableTrim(String? value) {
    final String normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
