import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/utils/date_time_formatter.dart';
import 'package:hkd/core/utils/error_message_mapper.dart';
import 'package:hkd/core/validation/form_validators.dart';
import 'package:hkd/core/widgets/empty_state_view.dart';
import 'package:hkd/core/widgets/error_state_view.dart';
import 'package:hkd/core/widgets/loading_state_view.dart';
import 'package:hkd/features/auth/domain/models/user_role.dart';
import 'package:hkd/features/support/domain/models/safety_incident_model.dart';
import 'package:hkd/features/support/domain/models/support_ticket_message_model.dart';
import 'package:hkd/features/support/domain/models/support_ticket_model.dart';

class SupportCenterPage extends StatefulWidget {
  const SupportCenterPage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<SupportCenterPage> createState() => _SupportCenterPageState();
}

class _SupportCenterPageState extends State<SupportCenterPage> {
  bool _isLoading = false;
  bool _isWorking = false;
  String? _errorMessage;
  bool _showAllTickets = false;
  bool _showAllIncidents = false;

  List<SupportTicketModel> _tickets = <SupportTicketModel>[];
  List<SafetyIncidentModel> _incidents = <SafetyIncidentModel>[];

  bool get _isAdmin {
    final UserRole? role =
        widget.dependencies.sessionController.currentUser?.role;
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
      final List<SupportTicketModel> tickets =
          await widget.dependencies.supportRepository.fetchTickets(
        includeAll: _isAdmin && _showAllTickets,
      );
      final List<SafetyIncidentModel> incidents =
          await widget.dependencies.supportRepository.fetchIncidents(
        includeAll: _isAdmin && _showAllIncidents,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _tickets = tickets;
        _incidents = incidents;
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
          fallback: 'Destek merkezi verileri yuklenemedi.',
        );
      });
    }
  }

  Future<void> _createTicket() async {
    final _TicketPayload? payload = await _showTicketDialog();
    if (payload == null) {
      return;
    }
    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.supportRepository.createTicket(
        title: payload.title,
        description: payload.description,
        category: payload.category,
        priority: payload.priority,
      );
      await _load();
      _showMessage('Destek talebi olusturuldu.');
    } catch (error) {
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Destek talebi olusturulamadi.',
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

  Future<void> _createIncident() async {
    final _IncidentPayload? payload = await _showIncidentDialog();
    if (payload == null) {
      return;
    }
    setState(() {
      _isWorking = true;
    });
    try {
      final Position? position = await _tryResolvePosition();
      await widget.dependencies.supportRepository.createIncident(
        title: payload.title,
        details: payload.details,
        severity: payload.severity,
        contactPhone: payload.contactPhone,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
      await _load();
      _showMessage('Acil durum kaydi acildi.');
    } catch (error) {
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Acil durum kaydi acilamadi.',
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

  Future<Position?> _tryResolvePosition() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateTicketStatus(
    String ticketId,
    SupportTicketStatus status,
  ) async {
    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.supportRepository.updateTicket(
        ticketId: ticketId,
        status: status,
      );
      await _load();
      _showMessage('Talep durumu guncellendi.');
    } catch (error) {
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Talep guncellenemedi.',
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

  Future<void> _updateIncidentStatus(
    String incidentId,
    SafetyIncidentStatus status,
  ) async {
    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.supportRepository.updateIncidentStatus(
        incidentId: incidentId,
        status: status,
      );
      await _load();
      _showMessage('Acil olay durumu guncellendi.');
    } catch (error) {
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Acil olay guncellenemedi.',
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

  Future<void> _openTicketMessages(SupportTicketModel ticket) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return _TicketMessagesDialog(
          dependencies: widget.dependencies,
          ticket: ticket,
          isAdmin: _isAdmin,
        );
      },
    );
  }

  Future<_TicketPayload?> _showTicketDialog() async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController detailsController = TextEditingController();
    SupportTicketCategory category = SupportTicketCategory.general;
    SupportTicketPriority priority = SupportTicketPriority.normal;

    final _TicketPayload? payload = await showDialog<_TicketPayload>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Destek Talebi'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: titleController,
                        validator: (String? value) {
                          if ((value ?? '').trim().length < 4) {
                            return 'Baslik en az 4 karakter olmali.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(labelText: 'Baslik'),
                      ),
                      TextFormField(
                        controller: detailsController,
                        minLines: 3,
                        maxLines: 5,
                        validator: (String? value) {
                          if ((value ?? '').trim().length < 8) {
                            return 'Aciklama en az 8 karakter olmali.';
                          }
                          return null;
                        },
                        decoration:
                            const InputDecoration(labelText: 'Aciklama'),
                      ),
                      DropdownButtonFormField<SupportTicketCategory>(
                        initialValue: category,
                        items: SupportTicketCategory.values
                            .map(
                              (SupportTicketCategory item) =>
                                  DropdownMenuItem<SupportTicketCategory>(
                                value: item,
                                child: Text(item.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (SupportTicketCategory? value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            category = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                        ),
                      ),
                      DropdownButtonFormField<SupportTicketPriority>(
                        initialValue: priority,
                        items: SupportTicketPriority.values
                            .map(
                              (SupportTicketPriority item) =>
                                  DropdownMenuItem<SupportTicketPriority>(
                                value: item,
                                child: Text(item.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (SupportTicketPriority? value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            priority = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Oncelik',
                        ),
                      ),
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
                    Navigator.of(context).pop(
                      _TicketPayload(
                        title: titleController.text.trim(),
                        description: detailsController.text.trim(),
                        category: category,
                        priority: priority,
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
    detailsController.dispose();
    return payload;
  }

  Future<_IncidentPayload?> _showIncidentDialog() async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController detailsController = TextEditingController();
    final TextEditingController phoneController = TextEditingController(
      text: widget.dependencies.sessionController.currentUser?.phone ?? '',
    );
    SafetyIncidentSeverity severity = SafetyIncidentSeverity.high;

    final _IncidentPayload? payload = await showDialog<_IncidentPayload>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('SOS Kaydi'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: titleController,
                        validator: (String? value) {
                          if ((value ?? '').trim().length < 4) {
                            return 'Baslik en az 4 karakter olmali.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Kisa Baslik',
                        ),
                      ),
                      TextFormField(
                        controller: detailsController,
                        minLines: 3,
                        maxLines: 5,
                        validator: (String? value) {
                          if ((value ?? '').trim().length < 8) {
                            return 'Detay en az 8 karakter olmali.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(labelText: 'Detay'),
                      ),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (String? value) {
                          if ((value ?? '').trim().isEmpty) {
                            return null;
                          }
                          return FormValidators.phone(value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Iletisim Telefonu',
                          hintText: '05XXXXXXXXX',
                        ),
                      ),
                      DropdownButtonFormField<SafetyIncidentSeverity>(
                        initialValue: severity,
                        items: SafetyIncidentSeverity.values
                            .map(
                              (SafetyIncidentSeverity item) =>
                                  DropdownMenuItem<SafetyIncidentSeverity>(
                                value: item,
                                child: Text(item.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (SafetyIncidentSeverity? value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            severity = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Siddet',
                        ),
                      ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    Navigator.of(context).pop(
                      _IncidentPayload(
                        title: titleController.text.trim(),
                        details: detailsController.text.trim(),
                        severity: severity,
                        contactPhone: _nullableTrim(phoneController.text),
                      ),
                    );
                  },
                  child: const Text('SOS Ac'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    detailsController.dispose();
    phoneController.dispose();
    return payload;
  }

  String? _nullableTrim(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Color _severityColor(SafetyIncidentSeverity severity) {
    switch (severity) {
      case SafetyIncidentSeverity.low:
        return Colors.green.shade700;
      case SafetyIncidentSeverity.medium:
        return Colors.orange.shade700;
      case SafetyIncidentSeverity.high:
        return Colors.deepOrange.shade700;
      case SafetyIncidentSeverity.critical:
        return Colors.red.shade700;
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
        body: LoadingStateView(message: 'Destek merkezi yukleniyor...'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Destek Merkezi')),
        body: ErrorStateView(
          title: 'Hata',
          message: _errorMessage!,
          onRetry: _load,
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Destek Merkezi'),
          bottom: const TabBar(
            tabs: <Tab>[
              Tab(icon: Icon(Icons.support_agent), text: 'Destek'),
              Tab(icon: Icon(Icons.sos), text: 'Acil'),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Yenile',
              onPressed: _isWorking ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: TabBarView(
          children: <Widget>[
            _buildTicketsTab(),
            _buildIncidentsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketsTab() {
    final Widget content = _tickets.isEmpty
        ? const EmptyStateView(
            title: 'Talep Yok',
            message: 'Destek talebi bulunmuyor.',
          )
        : Column(
            children: _tickets.map((SupportTicketModel item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(item.description),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          Chip(label: Text(item.category.label)),
                          Chip(label: Text(item.priority.label)),
                          Chip(label: Text(item.status.label)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(DateTimeFormatter.dateTime(item.createdAt)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: _isWorking
                                ? null
                                : () => _openTicketMessages(item),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Mesajlar'),
                          ),
                        ],
                      ),
                      if (_isAdmin)
                        Wrap(
                          spacing: 8,
                          children: SupportTicketStatus.values
                              .where(
                                  (SupportTicketStatus s) => s != item.status)
                              .map((SupportTicketStatus status) {
                            return OutlinedButton(
                              onPressed: _isWorking
                                  ? null
                                  : () => _updateTicketStatus(item.id, status),
                              child: Text(status.label),
                            );
                          }).toList(growable: false),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(growable: false),
          );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(child: Text('Destek talepleri')),
                      ElevatedButton.icon(
                        onPressed: _isWorking ? null : _createTicket,
                        icon: const Icon(Icons.add),
                        label: const Text('Talep Ac'),
                      ),
                    ],
                  ),
                  if (_isAdmin)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _showAllTickets,
                      onChanged: _isWorking
                          ? null
                          : (bool value) async {
                              setState(() {
                                _showAllTickets = value;
                              });
                              await _load();
                            },
                      title: const Text('Tum talepleri goster'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildIncidentsTab() {
    final Widget content = _incidents.isEmpty
        ? const EmptyStateView(
            title: 'Acil Kayit Yok',
            message: 'Acil durum kaydi bulunmuyor.',
          )
        : Column(
            children: _incidents.map((SafetyIncidentModel item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(item.details),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          Chip(
                            backgroundColor: _severityColor(item.severity)
                                .withValues(alpha: 0.15),
                            label: Text(item.severity.label),
                          ),
                          Chip(label: Text(item.status.label)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(DateTimeFormatter.dateTime(item.createdAt)),
                      if ((item.contactPhone ?? '').isNotEmpty)
                        Text('Iletisim: ${item.contactPhone}'),
                      if (_isAdmin)
                        Wrap(
                          spacing: 8,
                          children: SafetyIncidentStatus.values
                              .where(
                                  (SafetyIncidentStatus s) => s != item.status)
                              .map((SafetyIncidentStatus status) {
                            return OutlinedButton(
                              onPressed: _isWorking
                                  ? null
                                  : () =>
                                      _updateIncidentStatus(item.id, status),
                              child: Text(status.label),
                            );
                          }).toList(growable: false),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(growable: false),
          );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                          child: Text('SOS ve acil durum kayitlari')),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isWorking ? null : _createIncident,
                        icon: const Icon(Icons.warning_amber),
                        label: const Text('SOS Ac'),
                      ),
                    ],
                  ),
                  if (_isAdmin)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _showAllIncidents,
                      onChanged: _isWorking
                          ? null
                          : (bool value) async {
                              setState(() {
                                _showAllIncidents = value;
                              });
                              await _load();
                            },
                      title: const Text('Tum olaylari goster'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}

class _TicketMessagesDialog extends StatefulWidget {
  const _TicketMessagesDialog({
    required this.dependencies,
    required this.ticket,
    required this.isAdmin,
  });

  final AppDependencies dependencies;
  final SupportTicketModel ticket;
  final bool isAdmin;

  @override
  State<_TicketMessagesDialog> createState() => _TicketMessagesDialogState();
}

class _TicketMessagesDialogState extends State<_TicketMessagesDialog> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;
  bool _isSending = false;
  bool _isInternal = false;
  List<SupportTicketMessageModel> _messages = <SupportTicketMessageModel>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<SupportTicketMessageModel> items = await widget
          .dependencies.supportRepository
          .fetchTicketMessages(ticketId: widget.ticket.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Mesajlar yuklenemedi.',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });
    try {
      await widget.dependencies.supportRepository.addTicketMessage(
        ticketId: widget.ticket.id,
        body: text,
        isInternal: widget.isAdmin && _isInternal,
      );
      _messageController.clear();
      await _loadMessages();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorMessageMapper.toFriendlyTurkish(
              error,
              fallback: 'Mesaj gonderilemedi.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Talep Mesajlari - ${widget.ticket.title}'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!),
              )
            else if (_messages.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Henuz mesaj yok.'),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _messages.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final SupportTicketMessageModel item = _messages[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                (item.senderName ?? '').trim().isEmpty
                                    ? 'Kullanici'
                                    : item.senderName!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (item.isInternal)
                              const Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text('Internal'),
                              ),
                          ],
                        ),
                        Text(item.body),
                        const SizedBox(height: 4),
                        Text(
                          DateTimeFormatter.dateTime(item.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _messageController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mesaj',
              ),
            ),
            if (widget.isAdmin)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isInternal,
                onChanged: _isSending
                    ? null
                    : (bool value) {
                        setState(() {
                          _isInternal = value;
                        });
                      },
                title: const Text('Internal not'),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _sendMessage,
          child: _isSending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Gonder'),
        ),
      ],
    );
  }
}

class _TicketPayload {
  const _TicketPayload({
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
  });

  final String title;
  final String description;
  final SupportTicketCategory category;
  final SupportTicketPriority priority;
}

class _IncidentPayload {
  const _IncidentPayload({
    required this.title,
    required this.details,
    required this.severity,
    required this.contactPhone,
  });

  final String title;
  final String details;
  final SafetyIncidentSeverity severity;
  final String? contactPhone;
}
