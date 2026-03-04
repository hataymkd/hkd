import 'package:hkd/features/support/domain/models/support_ticket_model.dart';

class SupportTicketDto {
  const SupportTicketDto({
    required this.id,
    required this.userId,
    required this.userName,
    required this.orgId,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.assignedTo,
    required this.resolutionNote,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? userName;
  final String? orgId;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String? assignedTo;
  final String? resolutionNote;
  final String createdAt;
  final String updatedAt;

  factory SupportTicketDto.fromMap(Map<String, dynamic> map) {
    final dynamic profileRaw = map['profiles'];
    String? userName;
    if (profileRaw is Map) {
      userName = (profileRaw['full_name'] as String?)?.trim();
    }

    return SupportTicketDto(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userName: userName,
      orgId: map['org_id'] as String?,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'general',
      priority: (map['priority'] as String?) ?? 'normal',
      status: (map['status'] as String?) ?? 'open',
      assignedTo: map['assigned_to'] as String?,
      resolutionNote: map['resolution_note'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}

extension SupportTicketDtoMapper on SupportTicketDto {
  SupportTicketModel toDomain() {
    return SupportTicketModel(
      id: id,
      userId: userId,
      userName: userName,
      orgId: orgId,
      title: title.trim(),
      description: description.trim(),
      category: supportTicketCategoryFromDb(category),
      priority: supportTicketPriorityFromDb(priority),
      status: supportTicketStatusFromDb(status),
      assignedTo: assignedTo,
      resolutionNote: _nullableTrim(resolutionNote),
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  String? _nullableTrim(String? value) {
    final String cleaned = (value ?? '').trim();
    if (cleaned.isEmpty) {
      return null;
    }
    return cleaned;
  }
}
