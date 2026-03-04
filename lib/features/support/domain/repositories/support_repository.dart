import 'package:hkd/features/support/domain/models/safety_incident_model.dart';
import 'package:hkd/features/support/domain/models/support_ticket_message_model.dart';
import 'package:hkd/features/support/domain/models/support_ticket_model.dart';

abstract class SupportRepository {
  Future<List<SupportTicketModel>> fetchTickets({
    bool includeAll = false,
  });

  Future<void> createTicket({
    required String title,
    required String description,
    SupportTicketCategory category = SupportTicketCategory.general,
    SupportTicketPriority priority = SupportTicketPriority.normal,
    String? organizationId,
  });

  Future<void> updateTicket({
    required String ticketId,
    required SupportTicketStatus status,
    String? resolutionNote,
    String? assignedTo,
  });

  Future<void> addTicketMessage({
    required String ticketId,
    required String body,
    bool isInternal = false,
  });

  Future<List<SupportTicketMessageModel>> fetchTicketMessages({
    required String ticketId,
    int limit = 100,
  });

  Future<List<SafetyIncidentModel>> fetchIncidents({
    bool includeAll = false,
  });

  Future<void> createIncident({
    required String title,
    required String details,
    SafetyIncidentSeverity severity = SafetyIncidentSeverity.high,
    String? contactPhone,
    String? organizationId,
    double? latitude,
    double? longitude,
  });

  Future<void> updateIncidentStatus({
    required String incidentId,
    required SafetyIncidentStatus status,
  });
}
