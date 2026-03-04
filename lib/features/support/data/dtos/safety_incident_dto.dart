import 'package:hkd/features/support/domain/models/safety_incident_model.dart';

class SafetyIncidentDto {
  const SafetyIncidentDto({
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
  final String severity;
  final String status;
  final String? contactPhone;
  final double? latitude;
  final double? longitude;
  final String? resolvedBy;
  final String? resolvedAt;
  final String createdAt;
  final String updatedAt;

  factory SafetyIncidentDto.fromMap(Map<String, dynamic> map) {
    final dynamic profileRaw = map['profiles'];
    String? reporterName;
    if (profileRaw is Map) {
      reporterName = (profileRaw['full_name'] as String?)?.trim();
    }

    return SafetyIncidentDto(
      id: map['id'] as String,
      reporterId: map['reporter_id'] as String,
      reporterName: reporterName,
      orgId: map['org_id'] as String?,
      title: (map['title'] as String?) ?? '',
      details: (map['details'] as String?) ?? '',
      severity: (map['severity'] as String?) ?? 'high',
      status: (map['status'] as String?) ?? 'open',
      contactPhone: map['contact_phone'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      resolvedBy: map['resolved_by'] as String?,
      resolvedAt: map['resolved_at'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}

extension SafetyIncidentDtoMapper on SafetyIncidentDto {
  SafetyIncidentModel toDomain() {
    return SafetyIncidentModel(
      id: id,
      reporterId: reporterId,
      reporterName: reporterName,
      orgId: orgId,
      title: title.trim(),
      details: details.trim(),
      severity: safetyIncidentSeverityFromDb(severity),
      status: safetyIncidentStatusFromDb(status),
      contactPhone: _displayPhone(contactPhone),
      latitude: latitude,
      longitude: longitude,
      resolvedBy: resolvedBy,
      resolvedAt: resolvedAt == null ? null : DateTime.parse(resolvedAt!),
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  String? _displayPhone(String? rawPhone) {
    if (rawPhone == null) {
      return null;
    }
    if (rawPhone.startsWith('+90') && rawPhone.length == 13) {
      return '0${rawPhone.substring(3)}';
    }
    return rawPhone;
  }
}
