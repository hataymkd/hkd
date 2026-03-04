import 'package:flutter/material.dart';
import 'package:hkd/core/authorization/app_permission.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/navigation/app_routes.dart';
import 'package:hkd/core/utils/date_time_formatter.dart';
import 'package:hkd/core/validation/form_validators.dart';
import 'package:hkd/core/widgets/empty_state_view.dart';
import 'package:hkd/core/widgets/error_state_view.dart';
import 'package:hkd/core/widgets/loading_state_view.dart';
import 'package:hkd/features/announcements/domain/models/announcement_model.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  List<AnnouncementModel> _announcements = <AnnouncementModel>[];
  bool _isWorking = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<AnnouncementModel> items = await widget
          .dependencies.announcementRepository
          .fetchAnnouncementsAsync(
        publishedOnly: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _announcements = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Duyurular yuklenirken bir hata olustu.';
      });
    }
  }

  UserModel? get _currentUser =>
      widget.dependencies.sessionController.currentUser;

  Future<void> _openAnnouncementDialog(
      {AnnouncementModel? announcement}) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController contentController = TextEditingController();

    if (announcement != null) {
      titleController.text = announcement.title;
      contentController.text = announcement.content;
    }

    final bool? shouldAdd = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(announcement == null ? 'Duyuru Ekle' : 'Duyuru Duzenle'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: titleController,
                    validator: (String? value) => FormValidators.requiredText(
                      value,
                      fieldName: 'Baslik',
                    ),
                    decoration: const InputDecoration(labelText: 'Baslik'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: contentController,
                    maxLines: 4,
                    validator: (String? value) => FormValidators.requiredText(
                      value,
                      fieldName: 'Icerik',
                    ),
                    decoration: const InputDecoration(labelText: 'Icerik'),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (shouldAdd == true) {
      setState(() {
        _isWorking = true;
      });

      if (announcement == null) {
        await widget.dependencies.announcementRepository.addAnnouncement(
          title: titleController.text,
          content: contentController.text,
          createdBy: _currentUser?.name ?? 'Sistem',
        );
      } else {
        await widget.dependencies.announcementRepository.updateAnnouncement(
          id: announcement.id,
          title: titleController.text,
          content: contentController.text,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isWorking = false;
      });
      await _loadAnnouncements();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            announcement == null ? 'Duyuru eklendi.' : 'Duyuru guncellendi.',
          ),
        ),
      );
    }

    titleController.dispose();
    contentController.dispose();
  }

  Future<void> _deleteAnnouncement(AnnouncementModel announcement) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Duyuru Sil'),
          content: const Text('Bu duyuruyu silmek istediginize emin misiniz?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgec'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _isWorking = true;
    });
    await widget.dependencies.announcementRepository.deleteAnnouncement(
      announcement.id,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isWorking = false;
    });
    await _loadAnnouncements();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Duyuru silindi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserModel? currentUser = _currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: EmptyStateView(
          title: 'Oturum Bulunamadi',
          message: 'Lutfen yeniden giris yapin.',
        ),
      );
    }

    final bool canManageAnnouncements =
        widget.dependencies.authorizationService.can(
      user: currentUser,
      permission: AppPermission.addAnnouncement,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Duyurular')),
      floatingActionButton: canManageAnnouncements
          ? FloatingActionButton.extended(
              onPressed: _isWorking ? null : _openAnnouncementDialog,
              icon: const Icon(Icons.add),
              label: const Text('Duyuru Ekle'),
            )
          : null,
      body: _isLoading
          ? const LoadingStateView(message: 'Duyurular yukleniyor...')
          : _errorMessage != null
              ? ErrorStateView(
                  title: 'Hata',
                  message: _errorMessage!,
                  onRetry: _loadAnnouncements,
                )
              : _announcements.isEmpty
                  ? const EmptyStateView(
                      title: 'Duyuru Yok',
                      message: 'Henuz yayinlanan bir duyuru bulunmuyor.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _announcements.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        final AnnouncementModel announcement =
                            _announcements[index];
                        return Card(
                          child: ListTile(
                            title: Text(announcement.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const SizedBox(height: 6),
                                Text(
                                  announcement.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${announcement.createdBy} - '
                                  '${DateTimeFormatter.dateTime(announcement.createdAt)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            trailing: canManageAnnouncements
                                ? PopupMenuButton<String>(
                                    onSelected: (String action) {
                                      if (action == 'edit') {
                                        _openAnnouncementDialog(
                                          announcement: announcement,
                                        );
                                        return;
                                      }
                                      if (action == 'delete') {
                                        _deleteAnnouncement(announcement);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) {
                                      return const <PopupMenuEntry<String>>[
                                        PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Text('Duzenle'),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Text('Sil'),
                                        ),
                                      ];
                                    },
                                  )
                                : const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.announcementDetail,
                                arguments: announcement,
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
