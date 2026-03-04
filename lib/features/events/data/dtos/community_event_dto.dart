import 'package:hkd/features/events/domain/models/community_event_model.dart';

class CommunityEventDto {
  const CommunityEventDto({
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
  });

  final String id;
  final String title;
  final String description;
  final String? location;
  final String startsAt;
  final String? endsAt;
  final String status;
  final String? createdBy;
  final String createdAt;
  final String updatedAt;

  factory CommunityEventDto.fromMap(Map<String, dynamic> map) {
    return CommunityEventDto(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      location: map['location'] as String?,
      startsAt: map['starts_at'] as String,
      endsAt: map['ends_at'] as String?,
      status: (map['status'] as String?) ?? 'published',
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}

extension CommunityEventDtoMapper on CommunityEventDto {
  CommunityEventModel toDomain({
    EventRsvpStatus? myRsvpStatus,
    int goingCount = 0,
  }) {
    return CommunityEventModel(
      id: id,
      title: title.trim(),
      description: description.trim(),
      location: _nullableTrim(location),
      startsAt: DateTime.parse(startsAt),
      endsAt: endsAt == null ? null : DateTime.parse(endsAt!),
      status: communityEventStatusFromDb(status),
      createdBy: createdBy,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      myRsvpStatus: myRsvpStatus,
      goingCount: goingCount,
    );
  }

  String? _nullableTrim(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    return raw;
  }
}
