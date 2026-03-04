import 'package:hkd/features/announcements/data/dtos/announcement_dto.dart';
import 'package:hkd/features/announcements/domain/models/announcement_model.dart';
import 'package:hkd/features/announcements/domain/repositories/announcement_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAnnouncementRepository implements AnnouncementRepository {
  SupabaseAnnouncementRepository({
    required SupabaseClient client,
  }) : _client = client;

  final SupabaseClient _client;
  List<AnnouncementModel> _cache = <AnnouncementModel>[];

  @override
  List<AnnouncementModel> fetchAnnouncements() {
    return List<AnnouncementModel>.unmodifiable(_cache);
  }

  @override
  Future<List<AnnouncementModel>> fetchAnnouncementsAsync({
    bool publishedOnly = true,
  }) async {
    PostgrestFilterBuilder<dynamic> query =
        _client.from('announcements').select(
              'id, title, content, created_at, created_by, status, '
              'profiles:created_by(full_name)',
            );

    if (publishedOnly) {
      query = query.eq('status', 'published');
    }

    final dynamic raw = await query.order('created_at', ascending: false);
    final List<dynamic> rows = raw as List<dynamic>;
    final List<AnnouncementModel> announcements = rows.map((dynamic item) {
      final Map<String, dynamic> map = (item as Map).cast<String, dynamic>();
      final String createdBy = _extractCreatedByName(map);
      return AnnouncementDto.fromMap(
        <String, dynamic>{
          'id': map['id'],
          'title': map['title'],
          'content': map['content'],
          'created_at': map['created_at'],
          'created_by': createdBy,
        },
      ).toDomain();
    }).toList();

    _cache = announcements;
    return List<AnnouncementModel>.unmodifiable(announcements);
  }

  @override
  Future<AnnouncementModel?> fetchAnnouncementById(String id) async {
    final dynamic raw = await _client
        .from('announcements')
        .select(
          'id, title, content, created_at, created_by, status, '
          'profiles:created_by(full_name)',
        )
        .eq('id', id)
        .maybeSingle();
    if (raw == null) {
      return null;
    }
    final Map<String, dynamic> map = (raw as Map).cast<String, dynamic>();
    return AnnouncementDto.fromMap(
      <String, dynamic>{
        'id': map['id'],
        'title': map['title'],
        'content': map['content'],
        'created_at': map['created_at'],
        'created_by': _extractCreatedByName(map),
      },
    ).toDomain();
  }

  @override
  Future<void> addAnnouncement({
    required String title,
    required String content,
    required String createdBy,
  }) async {
    final String? currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw StateError('Oturum bulunamadi. Lutfen yeniden giris yapin.');
    }
    await _client.from('announcements').insert(
      <String, dynamic>{
        'title': title.trim(),
        'content': content.trim(),
        'status': 'published',
        'created_by': currentUserId,
      },
    );
    await fetchAnnouncementsAsync();
  }

  @override
  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String content,
  }) async {
    await _client.from('announcements').update(
      <String, dynamic>{
        'title': title.trim(),
        'content': content.trim(),
      },
    ).eq('id', id);
    await fetchAnnouncementsAsync(publishedOnly: false);
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    await _client.from('announcements').delete().eq('id', id);
    await fetchAnnouncementsAsync();
  }

  String _extractCreatedByName(Map<String, dynamic> row) {
    final dynamic profileRaw = row['profiles'];
    if (profileRaw is Map && profileRaw['full_name'] is String) {
      final String fullName = profileRaw['full_name'] as String;
      if (fullName.trim().isNotEmpty) {
        return fullName.trim();
      }
    }
    return 'Sistem';
  }
}
