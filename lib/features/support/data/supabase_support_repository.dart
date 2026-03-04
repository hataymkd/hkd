import 'dart:collection';

import 'package:hkd/features/support/data/dtos/safety_incident_dto.dart';
import 'package:hkd/features/support/data/dtos/support_ticket_message_dto.dart';
import 'package:hkd/features/support/data/dtos/support_ticket_dto.dart';
import 'package:hkd/features/support/domain/models/safety_incident_model.dart';
import 'package:hkd/features/support/domain/models/support_ticket_message_model.dart';
import 'package:hkd/features/support/domain/models/support_ticket_model.dart';
import 'package:hkd/features/support/domain/repositories/support_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSupportRepository implements SupportRepository {
  SupabaseSupportRepository({
    required SupabaseClient client,
  }) : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<SupportTicketModel>> fetchTickets({
    bool includeAll = false,
  }) async {
    final String userId = _requireCurrentUserId();

    dynamic request = _client
        .from('support_tickets')
        .select(
          'id, user_id, org_id, title, description, category, priority, '
          'status, assigned_to, resolution_note, created_at, updated_at, '
          'profiles(full_name)',
        )
        .order('created_at', ascending: false);

    if (!includeAll) {
      request = request.eq('user_id', userId);
    }

    final dynamic raw = await request;
    final List<SupportTicketModel> items = (raw as List<dynamic>)
        .map(
          (dynamic item) => SupportTicketDto.fromMap(
            (item as Map).cast<String, dynamic>(),
          ).toDomain(),
        )
        .toList(growable: false);

    return UnmodifiableListView<SupportTicketModel>(items);
  }

  @override
  Future<void> createTicket({
    required String title,
    required String description,
    SupportTicketCategory category = SupportTicketCategory.general,
    SupportTicketPriority priority = SupportTicketPriority.normal,
    String? organizationId,
  }) async {
    final String userId = _requireCurrentUserId();
    await _client.from('support_tickets').insert(
      <String, dynamic>{
        'user_id': userId,
        'org_id': _nullableTrim(organizationId),
        'title': title.trim(),
        'description': description.trim(),
        'category': category.dbValue,
        'priority': priority.dbValue,
        'status': 'open',
      },
    );
  }

  @override
  Future<void> updateTicket({
    required String ticketId,
    required SupportTicketStatus status,
    String? resolutionNote,
    String? assignedTo,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'status': status.dbValue,
      'resolution_note': _nullableTrim(resolutionNote),
    };
    if (assignedTo != null) {
      payload['assigned_to'] = _nullableTrim(assignedTo);
    }
    await _client.from('support_tickets').update(payload).eq('id', ticketId);
  }

  @override
  Future<void> addTicketMessage({
    required String ticketId,
    required String body,
    bool isInternal = false,
  }) async {
    final String userId = _requireCurrentUserId();
    await _client.from('support_ticket_messages').insert(
      <String, dynamic>{
        'ticket_id': ticketId,
        'sender_id': userId,
        'body': body.trim(),
        'is_internal': isInternal,
      },
    );
  }

  @override
  Future<List<SupportTicketMessageModel>> fetchTicketMessages({
    required String ticketId,
    int limit = 100,
  }) async {
    final dynamic raw = await _client
        .from('support_ticket_messages')
        .select(
            'id, ticket_id, sender_id, body, is_internal, created_at, profiles(full_name)')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true)
        .limit(limit);

    final List<SupportTicketMessageModel> items = (raw as List<dynamic>)
        .map(
          (dynamic item) => SupportTicketMessageDto.fromMap(
            (item as Map).cast<String, dynamic>(),
          ).toDomain(),
        )
        .toList(growable: false);

    return UnmodifiableListView<SupportTicketMessageModel>(items);
  }

  @override
  Future<List<SafetyIncidentModel>> fetchIncidents({
    bool includeAll = false,
  }) async {
    final String userId = _requireCurrentUserId();

    dynamic request = _client
        .from('safety_incidents')
        .select(
          'id, reporter_id, org_id, title, details, severity, status, '
          'contact_phone, latitude, longitude, resolved_by, resolved_at, '
          'created_at, updated_at, profiles(full_name)',
        )
        .order('created_at', ascending: false);

    if (!includeAll) {
      request = request.eq('reporter_id', userId);
    }

    final dynamic raw = await request;
    final List<SafetyIncidentModel> items = (raw as List<dynamic>)
        .map(
          (dynamic item) => SafetyIncidentDto.fromMap(
            (item as Map).cast<String, dynamic>(),
          ).toDomain(),
        )
        .toList(growable: false);
    return UnmodifiableListView<SafetyIncidentModel>(items);
  }

  @override
  Future<void> createIncident({
    required String title,
    required String details,
    SafetyIncidentSeverity severity = SafetyIncidentSeverity.high,
    String? contactPhone,
    String? organizationId,
    double? latitude,
    double? longitude,
  }) async {
    final String userId = _requireCurrentUserId();
    await _client.from('safety_incidents').insert(
      <String, dynamic>{
        'reporter_id': userId,
        'org_id': _nullableTrim(organizationId),
        'title': title.trim(),
        'details': details.trim(),
        'severity': severity.dbValue,
        'status': 'open',
        'contact_phone': _normalizePhone(contactPhone),
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  @override
  Future<void> updateIncidentStatus({
    required String incidentId,
    required SafetyIncidentStatus status,
  }) async {
    final String actorId = _requireCurrentUserId();
    await _client.from('safety_incidents').update(
      <String, dynamic>{
        'status': status.dbValue,
        'resolved_by': status == SafetyIncidentStatus.closed ? actorId : null,
        'resolved_at': status == SafetyIncidentStatus.closed
            ? DateTime.now().toUtc().toIso8601String()
            : null,
      },
    ).eq('id', incidentId);
  }

  String _requireCurrentUserId() {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('Oturum bulunamadi. Lutfen yeniden giris yapin.');
    }
    return userId;
  }

  String? _nullableTrim(String? value) {
    final String normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? _normalizePhone(String? rawPhone) {
    final String value = _nullableTrim(rawPhone) ?? '';
    if (value.isEmpty) {
      return null;
    }

    final String compact = value.replaceAll(RegExp(r'[\s()-]+'), '');
    if (compact.startsWith('+')) {
      final String digits = compact.substring(1).replaceAll(RegExp(r'\D'), '');
      return '+$digits';
    }

    final String digits = compact.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 11) {
      return '+90${digits.substring(1)}';
    }
    if (digits.startsWith('90') && digits.length == 12) {
      return '+$digits';
    }
    if (digits.length == 10) {
      return '+90$digits';
    }
    return compact;
  }
}
