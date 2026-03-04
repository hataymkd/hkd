import 'package:hkd/features/announcements/domain/models/announcement_model.dart';

abstract class AnnouncementRepository {
  List<AnnouncementModel> fetchAnnouncements();

  Future<List<AnnouncementModel>> fetchAnnouncementsAsync({
    bool publishedOnly = true,
  }) async {
    final List<AnnouncementModel> items = fetchAnnouncements();
    if (!publishedOnly) {
      return items;
    }
    return items;
  }

  Future<AnnouncementModel?> fetchAnnouncementById(String id) async {
    final List<AnnouncementModel> items = await fetchAnnouncementsAsync(
      publishedOnly: false,
    );
    for (final AnnouncementModel item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Future<void> addAnnouncement({
    required String title,
    required String content,
    required String createdBy,
  });

  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String content,
  });

  Future<void> deleteAnnouncement(String id);
}
