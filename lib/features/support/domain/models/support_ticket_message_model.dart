class SupportTicketMessageModel {
  const SupportTicketMessageModel({
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
  final DateTime createdAt;
}
