enum SupportTicketCategory {
  general,
  membership,
  payment,
  job,
  technical,
  other,
}

enum SupportTicketPriority {
  low,
  normal,
  high,
  urgent,
}

enum SupportTicketStatus {
  open,
  inProgress,
  resolved,
  closed,
}

extension SupportTicketCategoryX on SupportTicketCategory {
  String get dbValue {
    switch (this) {
      case SupportTicketCategory.general:
        return 'general';
      case SupportTicketCategory.membership:
        return 'membership';
      case SupportTicketCategory.payment:
        return 'payment';
      case SupportTicketCategory.job:
        return 'job';
      case SupportTicketCategory.technical:
        return 'technical';
      case SupportTicketCategory.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case SupportTicketCategory.general:
        return 'Genel';
      case SupportTicketCategory.membership:
        return 'Uyelik';
      case SupportTicketCategory.payment:
        return 'Odeme';
      case SupportTicketCategory.job:
        return 'Is Pazari';
      case SupportTicketCategory.technical:
        return 'Teknik';
      case SupportTicketCategory.other:
        return 'Diger';
    }
  }
}

extension SupportTicketPriorityX on SupportTicketPriority {
  String get dbValue {
    switch (this) {
      case SupportTicketPriority.low:
        return 'low';
      case SupportTicketPriority.normal:
        return 'normal';
      case SupportTicketPriority.high:
        return 'high';
      case SupportTicketPriority.urgent:
        return 'urgent';
    }
  }

  String get label {
    switch (this) {
      case SupportTicketPriority.low:
        return 'Dusuk';
      case SupportTicketPriority.normal:
        return 'Normal';
      case SupportTicketPriority.high:
        return 'Yuksek';
      case SupportTicketPriority.urgent:
        return 'Acil';
    }
  }
}

extension SupportTicketStatusX on SupportTicketStatus {
  String get dbValue {
    switch (this) {
      case SupportTicketStatus.open:
        return 'open';
      case SupportTicketStatus.inProgress:
        return 'in_progress';
      case SupportTicketStatus.resolved:
        return 'resolved';
      case SupportTicketStatus.closed:
        return 'closed';
    }
  }

  String get label {
    switch (this) {
      case SupportTicketStatus.open:
        return 'Acik';
      case SupportTicketStatus.inProgress:
        return 'Islemde';
      case SupportTicketStatus.resolved:
        return 'Cozuldu';
      case SupportTicketStatus.closed:
        return 'Kapatildi';
    }
  }
}

SupportTicketCategory supportTicketCategoryFromDb(String raw) {
  switch (raw) {
    case 'membership':
      return SupportTicketCategory.membership;
    case 'payment':
      return SupportTicketCategory.payment;
    case 'job':
      return SupportTicketCategory.job;
    case 'technical':
      return SupportTicketCategory.technical;
    case 'other':
      return SupportTicketCategory.other;
    default:
      return SupportTicketCategory.general;
  }
}

SupportTicketPriority supportTicketPriorityFromDb(String raw) {
  switch (raw) {
    case 'low':
      return SupportTicketPriority.low;
    case 'high':
      return SupportTicketPriority.high;
    case 'urgent':
      return SupportTicketPriority.urgent;
    default:
      return SupportTicketPriority.normal;
  }
}

SupportTicketStatus supportTicketStatusFromDb(String raw) {
  switch (raw) {
    case 'in_progress':
      return SupportTicketStatus.inProgress;
    case 'resolved':
      return SupportTicketStatus.resolved;
    case 'closed':
      return SupportTicketStatus.closed;
    default:
      return SupportTicketStatus.open;
  }
}

class SupportTicketModel {
  const SupportTicketModel({
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
  final SupportTicketCategory category;
  final SupportTicketPriority priority;
  final SupportTicketStatus status;
  final String? assignedTo;
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime updatedAt;
}
