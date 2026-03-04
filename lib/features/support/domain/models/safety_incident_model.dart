enum SafetyIncidentSeverity {
  low,
  medium,
  high,
  critical,
}

enum SafetyIncidentStatus {
  open,
  acknowledged,
  closed,
}

extension SafetyIncidentSeverityX on SafetyIncidentSeverity {
  String get dbValue {
    switch (this) {
      case SafetyIncidentSeverity.low:
        return 'low';
      case SafetyIncidentSeverity.medium:
        return 'medium';
      case SafetyIncidentSeverity.high:
        return 'high';
      case SafetyIncidentSeverity.critical:
        return 'critical';
    }
  }

  String get label {
    switch (this) {
      case SafetyIncidentSeverity.low:
        return 'Dusuk';
      case SafetyIncidentSeverity.medium:
        return 'Orta';
      case SafetyIncidentSeverity.high:
        return 'Yuksek';
      case SafetyIncidentSeverity.critical:
        return 'Kritik';
    }
  }
}

extension SafetyIncidentStatusX on SafetyIncidentStatus {
  String get dbValue {
    switch (this) {
      case SafetyIncidentStatus.open:
        return 'open';
      case SafetyIncidentStatus.acknowledged:
        return 'acknowledged';
      case SafetyIncidentStatus.closed:
        return 'closed';
    }
  }

  String get label {
    switch (this) {
      case SafetyIncidentStatus.open:
        return 'Acik';
      case SafetyIncidentStatus.acknowledged:
        return 'Alindi';
      case SafetyIncidentStatus.closed:
        return 'Kapatildi';
    }
  }
}

SafetyIncidentSeverity safetyIncidentSeverityFromDb(String raw) {
  switch (raw) {
    case 'low':
      return SafetyIncidentSeverity.low;
    case 'medium':
      return SafetyIncidentSeverity.medium;
    case 'critical':
      return SafetyIncidentSeverity.critical;
    default:
      return SafetyIncidentSeverity.high;
  }
}

SafetyIncidentStatus safetyIncidentStatusFromDb(String raw) {
  switch (raw) {
    case 'acknowledged':
      return SafetyIncidentStatus.acknowledged;
    case 'closed':
      return SafetyIncidentStatus.closed;
    default:
      return SafetyIncidentStatus.open;
  }
}

class SafetyIncidentModel {
  const SafetyIncidentModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.orgId,
    required this.title,
    required this.details,
    required this.severity,
    required this.status,
    required this.contactPhone,
    required this.latitude,
    required this.longitude,
    required this.resolvedBy,
    required this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String reporterId;
  final String? reporterName;
  final String? orgId;
  final String title;
  final String details;
  final SafetyIncidentSeverity severity;
  final SafetyIncidentStatus status;
  final String? contactPhone;
  final double? latitude;
  final double? longitude;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
