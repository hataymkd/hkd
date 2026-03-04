import 'package:hkd/features/support/domain/models/support_ticket_message_model.dart';

class SupportTicketMessageDto {
  const SupportTicketMessageDto({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.isInternal,
    required this.createdAt,
  });

  final String id;
  final String ticketId;
  final String? senderId;
  final String? senderName;
  final String body;
  final bool isInternal;
  final String createdAt;

  factory SupportTicketMessageDto.fromMap(Map<String, dynamic> map) {
    final dynamic profileRaw = map['profiles'];
    String? senderName;
    if (profileRaw is Map) {
      senderName = (profileRaw['full_name'] as String?)?.trim();
    }

    return SupportTicketMessageDto(
      id: map['id'] as String,
      ticketId: map['ticket_id'] as String,
      senderId: map['sender_id'] as String?,
      senderName: senderName,
      body: (map['body'] as String?) ?? '',
      isInternal: (map['is_internal'] as bool?) ?? false,
      createdAt: map['created_at'] as String,
    );
  }
}

extension SupportTicketMessageDtoMapper on SupportTicketMessageDto {
  SupportTicketMessageModel toDomain() {
    return SupportTicketMessageModel(
      id: id,
      ticketId: ticketId,
      senderId: senderId,
      senderName: senderName,
      body: body.trim(),
      isInternal: isInternal,
      createdAt: DateTime.parse(createdAt),
    );
  }
}
