import 'package:hkd/features/announcements/domain/models/announcement_model.dart';
import 'package:hkd/features/announcements/domain/repositories/announcement_repository.dart';

class MockAnnouncementRepository implements AnnouncementRepository {
  int _nextId = 4;

  final List<AnnouncementModel> _announcements = <AnnouncementModel>[
    AnnouncementModel(
      id: 'ann-1',
      title: 'Subat Toplantisi',
      content: 'Dernek aylik toplantisi 3 Mart 2026 tarihinde saat 20:00'
          'de dernek binasinda yapilacaktir.',
      createdAt: DateTime(2026, 2, 20, 14, 30),
      createdBy: 'Ahmet Kaya',
    ),
    AnnouncementModel(
      id: 'ann-2',
      title: 'Aidat Son Odeme Hatirlatmasi',
      content:
          'Mart ayi aidat son odeme tarihi 10 Mart 2026 olarak belirlenmistir. Gecikme yasamamasi icin odemelerinizi planlayiniz.',
      createdAt: DateTime(2026, 2, 18, 10, 0),
      createdBy: 'Ayse Demir',
    ),
    AnnouncementModel(
      id: 'ann-3',
      title: 'Yeni Uye Basvuru Sureci',
      content:
          'Yeni uye basvurulari yonetim panelinden takip edilmekte olup onaylanan uyeler SMS ile bilgilendirilmektedir.',
      createdAt: DateTime(2026, 2, 10, 9, 15),
      createdBy: 'Ahmet Kaya',
    ),
  ];

  @override
  List<AnnouncementModel> fetchAnnouncements() {
    final List<AnnouncementModel> sorted =
        List<AnnouncementModel>.from(_announcements);
    sorted.sort(
      (AnnouncementModel first, AnnouncementModel second) =>
          second.createdAt.compareTo(first.createdAt),
    );
    return sorted;
  }

  @override
  Future<List<AnnouncementModel>> fetchAnnouncementsAsync({
    bool publishedOnly = true,
  }) async {
    return fetchAnnouncements();
  }

  @override
  Future<AnnouncementModel?> fetchAnnouncementById(String id) async {
    for (final AnnouncementModel item in _announcements) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<void> addAnnouncement({
    required String title,
    required String content,
    required String createdBy,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _nextId += 1;
    _announcements.add(
      AnnouncementModel(
        id: 'ann-$_nextId',
        title: title.trim(),
        content: content.trim(),
        createdAt: DateTime.now(),
        createdBy: createdBy,
      ),
    );
  }

  @override
  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String content,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final int index = _announcements.indexWhere(
      (AnnouncementModel item) => item.id == id,
    );
    if (index == -1) {
      return;
    }

    final AnnouncementModel existing = _announcements[index];
    _announcements[index] = AnnouncementModel(
      id: existing.id,
      title: title.trim(),
      content: content.trim(),
      createdAt: existing.createdAt,
      createdBy: existing.createdBy,
    );
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _announcements.removeWhere((AnnouncementModel item) => item.id == id);
  }
}
