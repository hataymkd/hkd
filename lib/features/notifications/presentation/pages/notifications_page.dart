import 'package:flutter/material.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/utils/date_time_formatter.dart';
import 'package:hkd/core/widgets/empty_state_view.dart';
import 'package:hkd/core/widgets/error_state_view.dart';
import 'package:hkd/core/widgets/loading_state_view.dart';
import 'package:hkd/features/notifications/domain/models/app_notification_model.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoading = false;
  bool _isWorking = false;
  String? _errorMessage;
  List<AppNotificationModel> _items = const <AppNotificationModel>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final List<AppNotificationModel> items = await widget
          .dependencies.notificationRepository
          .fetchMyNotifications();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Bildirimler yuklenemedi.';
      });
    }
  }

  Future<void> _markAsRead(AppNotificationModel item) async {
    if (item.isRead || _isWorking) {
      return;
    }
    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.notificationRepository.markAsRead(item.id);
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    if (_isWorking) {
      return;
    }
    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.notificationRepository.markAllAsRead();
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _registerPushToken() async {
    final TextEditingController tokenController = TextEditingController();
    String platform = 'android';

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Push Token Kaydet'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: platform,
                    decoration: const InputDecoration(
                      labelText: 'Platform',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                          value: 'android', child: Text('Android')),
                      DropdownMenuItem(value: 'ios', child: Text('iOS')),
                      DropdownMenuItem(value: 'web', child: Text('Web')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        platform = value;
                      });
                    },
                  ),
                  TextField(
                    controller: tokenController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Push Token',
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Vazgec'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    final String token = tokenController.text.trim();
    tokenController.dispose();

    if (shouldSave != true) {
      return;
    }
    if (token.isEmpty) {
      _showMessage('Push token bos olamaz.');
      return;
    }

    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.notificationRepository.registerPushToken(
        token: token,
        platform: platform,
      );
      _showMessage('Push token kaydedildi.');
    } catch (_) {
      _showMessage('Push token kaydedilemedi.');
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingStateView(message: 'Bildirimler yukleniyor...'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bildirimler')),
        body: ErrorStateView(
          title: 'Hata',
          message: _errorMessage!,
          onRetry: _load,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Push Token Kaydet',
            onPressed: _isWorking ? null : _registerPushToken,
            icon: const Icon(Icons.phonelink_setup),
          ),
          TextButton(
            onPressed: _items.isEmpty || _isWorking ? null : _markAllRead,
            child: const Text('Tumunu Okundu Yap'),
          ),
        ],
      ),
      body: _items.isEmpty
          ? const EmptyStateView(
              title: 'Bildirim Yok',
              message: 'Size ozel yeni bir bildirim bulunmuyor.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final AppNotificationModel item = _items[index];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _markAsRead(item),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                if (!item.isRead)
                                  const Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: Colors.red,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(item.body),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: <Widget>[
                                Chip(
                                  label: Text(item.category.label),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Text(
                                  DateTimeFormatter.dateTime(item.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
