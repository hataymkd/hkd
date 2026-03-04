import 'package:flutter/material.dart';
import 'package:hkd/core/utils/date_time_formatter.dart';
import 'package:hkd/features/announcements/domain/models/announcement_model.dart';

class AnnouncementDetailPage extends StatelessWidget {
  const AnnouncementDetailPage({
    super.key,
    required this.announcement,
  });

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Duyuru Detayi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  announcement.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    const Icon(Icons.person, size: 18),
                    const SizedBox(width: 8),
                    Text(announcement.createdBy),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 8),
                    Text(DateTimeFormatter.dateTime(announcement.createdAt)),
                  ],
                ),
                const Divider(height: 28),
                Text(
                  announcement.content,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
