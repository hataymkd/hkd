import 'package:hkd/features/jobs/domain/models/job_post_model.dart';

class JobPostDto {
  const JobPostDto({
    required this.id,
    required this.orgId,
    required this.createdBy,
    required this.title,
    required this.description,
    required this.city,
    required this.district,
    required this.employmentType,
    required this.vehicleType,
    required this.salaryMin,
    required this.salaryMax,
    required this.currency,
    required this.status,
    required this.contactPhone,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    required this.organizationName,
  });

  final String id;
  final String? orgId;
  final String createdBy;
  final String title;
  final String description;
  final String city;
  final String? district;
  final String employmentType;
  final String vehicleType;
  final double? salaryMin;
  final double? salaryMax;
  final String currency;
  final String status;
  final String? contactPhone;
  final String? expiresAt;
  final String createdAt;
  final String updatedAt;
  final String? organizationName;

  factory JobPostDto.fromMap(Map<String, dynamic> map) {
    final dynamic organizationRaw = map['organizations'];
    final String? organizationName =
        organizationRaw is Map ? (organizationRaw['name'] as String?) : null;

    return JobPostDto(
      id: map['id'] as String,
      orgId: map['org_id'] as String?,
      createdBy: map['created_by'] as String,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      city: (map['city'] as String?) ?? '',
      district: map['district'] as String?,
      employmentType: (map['employment_type'] as String?) ?? 'full_time',
      vehicleType: (map['vehicle_type'] as String?) ?? 'motorcycle',
      salaryMin: _toDouble(map['salary_min']),
      salaryMax: _toDouble(map['salary_max']),
      currency: (map['currency'] as String?) ?? 'TRY',
      status: (map['status'] as String?) ?? 'open',
      contactPhone: map['contact_phone'] as String?,
      expiresAt: map['expires_at'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      organizationName: organizationName,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}

extension JobPostDtoMapper on JobPostDto {
  JobPostModel toDomain() {
    return JobPostModel(
      id: id,
      orgId: orgId,
      createdBy: createdBy,
      title: title.trim(),
      description: description.trim(),
      city: city.trim(),
      district: district?.trim(),
      employmentType: parseJobEmploymentType(employmentType),
      vehicleType: parseJobVehicleType(vehicleType),
      salaryMin: salaryMin,
      salaryMax: salaryMax,
      currency: currency.trim().toUpperCase(),
      status: parseJobPostStatus(status),
      contactPhone: _displayPhone(contactPhone),
      expiresAt: _parseDateTime(expiresAt),
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      organizationName: organizationName?.trim(),
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

  DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.parse(raw);
  }
}
