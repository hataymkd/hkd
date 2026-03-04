class AnnouncementModel {
  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final String createdBy;
}
