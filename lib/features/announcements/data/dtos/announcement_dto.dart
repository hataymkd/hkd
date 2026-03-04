import 'package:hkd/features/announcements/domain/models/announcement_model.dart';

class AnnouncementDto {
  const AnnouncementDto({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String title;
  final String content;
  final String createdAt;
  final String createdBy;

  factory AnnouncementDto.fromMap(Map<String, dynamic> map) {
    return AnnouncementDto(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: map['created_at'] as String,
      createdBy: map['created_by'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt,
      'created_by': createdBy,
    };
  }
}

extension AnnouncementDtoMapper on AnnouncementDto {
  AnnouncementModel toDomain() {
    return AnnouncementModel(
      id: id,
      title: title,
      content: content,
      createdAt: DateTime.parse(createdAt),
      createdBy: createdBy,
    );
  }
}

extension AnnouncementModelMapper on AnnouncementModel {
  AnnouncementDto toDto() {
    return AnnouncementDto(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt.toIso8601String(),
      createdBy: createdBy,
    );
  }
}
