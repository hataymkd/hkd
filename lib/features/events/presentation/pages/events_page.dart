import 'package:flutter/material.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/utils/date_time_formatter.dart';
import 'package:hkd/core/utils/error_message_mapper.dart';
import 'package:hkd/core/widgets/empty_state_view.dart';
import 'package:hkd/core/widgets/error_state_view.dart';
import 'package:hkd/core/widgets/loading_state_view.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/auth/domain/models/user_role.dart';
import 'package:hkd/features/events/domain/models/community_event_model.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  bool _isLoading = false;
  bool _isWorking = false;
  String? _errorMessage;
  List<CommunityEventModel> _events = <CommunityEventModel>[];

  UserModel? get _currentUser =>
      widget.dependencies.sessionController.currentUser;

  bool get _canManageEvents {
    final UserRole? role = _currentUser?.role;
    return role == UserRole.president || role == UserRole.manager;
  }

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
      final List<CommunityEventModel> items =
          await widget.dependencies.eventRepository.fetchUpcomingEvents(
        includeDrafts: _canManageEvents,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _events = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Etkinlikler yuklenemedi.',
        );
      });
    }
  }

  Future<void> _upsertRsvp({
    required CommunityEventModel event,
    required EventRsvpStatus status,
  }) async {
    if (_isWorking) {
      return;
    }
    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.eventRepository.upsertMyRsvp(
        eventId: event.id,
        status: status,
      );
      await _load();
      _showMessage('Katilim tercihiniz guncellendi.');
    } catch (error) {
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Katilim tercihi kaydedilemedi.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _changeEventStatus({
    required String eventId,
    required CommunityEventStatus status,
  }) async {
    if (!_canManageEvents || _isWorking) {
      return;
    }

    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.eventRepository.updateEventStatus(
        eventId: eventId,
        status: status,
      );
      await _load();
      _showMessage('Etkinlik durumu guncellendi.');
    } catch (error) {
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Etkinlik durumu guncellenemedi.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _createEvent() async {
    final _EventCreatePayload? payload = await _showCreateDialog();
    if (payload == null) {
      return;
    }
    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.eventRepository.createEvent(
        title: payload.title,
        description: payload.description,
        location: payload.location,
        startsAt: payload.startsAt,
        endsAt: payload.endsAt,
      );
      await _load();
      _showMessage('Etkinlik olusturuldu.');
    } catch (error) {
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Etkinlik olusturulamadi.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<_EventCreatePayload?> _showCreateDialog() async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController locationController = TextEditingController();
    DateTime startAt = DateTime.now().add(const Duration(days: 1));
    DateTime? endAt = DateTime.now().add(const Duration(days: 1, hours: 2));
    String? dialogError;

    final _EventCreatePayload? payload = await showDialog<_EventCreatePayload>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Etkinlik Ekle'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: titleController,
                        validator: (String? value) {
                          if ((value ?? '').trim().length < 3) {
                            return 'Baslik en az 3 karakter olmali.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Baslik',
                        ),
                      ),
                      TextFormField(
                        controller: descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        validator: (String? value) {
                          if ((value ?? '').trim().length < 8) {
                            return 'Aciklama en az 8 karakter olmali.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Aciklama',
                        ),
                      ),
                      TextFormField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: 'Konum (opsiyonel)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Baslangic'),
                        subtitle: Text(DateTimeFormatter.dateTime(startAt)),
                        trailing: const Icon(Icons.edit_calendar),
                        onTap: () async {
                          final DateTime? value =
                              await _pickDateTime(initial: startAt);
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            startAt = value;
                            if (endAt != null && !endAt!.isAfter(startAt)) {
                              endAt = startAt.add(const Duration(hours: 2));
                            }
                            dialogError = null;
                          });
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Bitis (opsiyonel)'),
                        subtitle: Text(
                          endAt == null
                              ? 'Belirtilmedi'
                              : DateTimeFormatter.dateTime(endAt!),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Temizle',
                              onPressed: () {
                                setDialogState(() {
                                  endAt = null;
                                });
                              },
                              icon: const Icon(Icons.clear),
                            ),
                            const Icon(Icons.edit_calendar),
                          ],
                        ),
                        onTap: () async {
                          final DateTime? value = await _pickDateTime(
                            initial:
                                endAt ?? startAt.add(const Duration(hours: 2)),
                          );
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            endAt = value;
                            dialogError = null;
                          });
                        },
                      ),
                      if (dialogError != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            dialogError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Vazgec'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    if (endAt != null && !endAt!.isAfter(startAt)) {
                      setDialogState(() {
                        dialogError =
                            'Bitis tarihi baslangic tarihinden sonra olmali.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(
                      _EventCreatePayload(
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        location: _nullableTrim(locationController.text),
                        startsAt: startAt,
                        endsAt: endAt,
                      ),
                    );
                  },
                  child: const Text('Olustur'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    return payload;
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null) {
      return null;
    }
    if (!mounted) {
      return null;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return null;
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  String? _nullableTrim(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
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
        body: LoadingStateView(message: 'Etkinlikler yukleniyor...'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Etkinlikler')),
        body: ErrorStateView(
          title: 'Hata',
          message: _errorMessage!,
          onRetry: _load,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Etkinlikler'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Yenile',
            onPressed: _isWorking ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          if (_canManageEvents)
            IconButton(
              tooltip: 'Etkinlik Ekle',
              onPressed: _isWorking ? null : _createEvent,
              icon: const Icon(Icons.add_circle_outline),
            ),
        ],
      ),
      body: _events.isEmpty
          ? const EmptyStateView(
              title: 'Etkinlik Bulunamadi',
              message: 'Yayinlanmis etkinlik kaydi yok.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final CommunityEventModel item = _events[index];
                  return Card(
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
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(item.status.label),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(item.description),
                          const SizedBox(height: 8),
                          Text(
                            'Baslangic: ${DateTimeFormatter.dateTime(item.startsAt)}',
                          ),
                          if (item.endsAt != null)
                            Text(
                              'Bitis: ${DateTimeFormatter.dateTime(item.endsAt!)}',
                            ),
                          if ((item.location ?? '').isNotEmpty)
                            Text('Konum: ${item.location}'),
                          Text('Katilim: ${item.goingCount} kisi'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: EventRsvpStatus.values
                                .map((EventRsvpStatus status) {
                              final bool selected = item.myRsvpStatus == status;
                              return ChoiceChip(
                                selected: selected,
                                label: Text(status.label),
                                onSelected: _isWorking
                                    ? null
                                    : (_) => _upsertRsvp(
                                          event: item,
                                          status: status,
                                        ),
                              );
                            }).toList(),
                          ),
                          if (_canManageEvents) ...<Widget>[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: CommunityEventStatus.values
                                  .where((CommunityEventStatus status) {
                                return status != item.status;
                              }).map((CommunityEventStatus status) {
                                return OutlinedButton(
                                  onPressed: _isWorking
                                      ? null
                                      : () => _changeEventStatus(
                                            eventId: item.id,
                                            status: status,
                                          ),
                                  child: Text(status.label),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _EventCreatePayload {
  const _EventCreatePayload({
    required this.title,
    required this.description,
    required this.location,
    required this.startsAt,
    required this.endsAt,
  });

  final String title;
  final String description;
  final String? location;
  final DateTime startsAt;
  final DateTime? endsAt;
}
