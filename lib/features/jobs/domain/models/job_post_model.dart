enum JobEmploymentType {
  fullTime,
  partTime,
  freelance,
  shift,
}

extension JobEmploymentTypeX on JobEmploymentType {
  String get dbKey {
    switch (this) {
      case JobEmploymentType.fullTime:
        return 'full_time';
      case JobEmploymentType.partTime:
        return 'part_time';
      case JobEmploymentType.freelance:
        return 'freelance';
      case JobEmploymentType.shift:
        return 'shift';
    }
  }

  String get label {
    switch (this) {
      case JobEmploymentType.fullTime:
        return 'Tam Zamanli';
      case JobEmploymentType.partTime:
        return 'Yari Zamanli';
      case JobEmploymentType.freelance:
        return 'Serbest';
      case JobEmploymentType.shift:
        return 'Vardiyali';
    }
  }
}

JobEmploymentType parseJobEmploymentType(String? raw) {
  switch (raw) {
    case 'part_time':
      return JobEmploymentType.partTime;
    case 'freelance':
      return JobEmploymentType.freelance;
    case 'shift':
      return JobEmploymentType.shift;
    default:
      return JobEmploymentType.fullTime;
  }
}

enum JobVehicleType {
  motorcycle,
  scooter,
  car,
  van,
  bicycle,
  any,
}

extension JobVehicleTypeX on JobVehicleType {
  String get dbKey {
    switch (this) {
      case JobVehicleType.motorcycle:
        return 'motorcycle';
      case JobVehicleType.scooter:
        return 'scooter';
      case JobVehicleType.car:
        return 'car';
      case JobVehicleType.van:
        return 'van';
      case JobVehicleType.bicycle:
        return 'bicycle';
      case JobVehicleType.any:
        return 'any';
    }
  }

  String get label {
    switch (this) {
      case JobVehicleType.motorcycle:
        return 'Motosiklet';
      case JobVehicleType.scooter:
        return 'Scooter';
      case JobVehicleType.car:
        return 'Araba';
      case JobVehicleType.van:
        return 'Van';
      case JobVehicleType.bicycle:
        return 'Bisiklet';
      case JobVehicleType.any:
        return 'Fark Etmez';
    }
  }
}

JobVehicleType parseJobVehicleType(String? raw) {
  switch (raw) {
    case 'scooter':
      return JobVehicleType.scooter;
    case 'car':
      return JobVehicleType.car;
    case 'van':
      return JobVehicleType.van;
    case 'bicycle':
      return JobVehicleType.bicycle;
    case 'any':
      return JobVehicleType.any;
    default:
      return JobVehicleType.motorcycle;
  }
}

enum JobPostStatus {
  open,
  paused,
  closed,
}

extension JobPostStatusX on JobPostStatus {
  String get dbKey {
    switch (this) {
      case JobPostStatus.open:
        return 'open';
      case JobPostStatus.paused:
        return 'paused';
      case JobPostStatus.closed:
        return 'closed';
    }
  }

  String get label {
    switch (this) {
      case JobPostStatus.open:
        return 'Acik';
      case JobPostStatus.paused:
        return 'Duraklatildi';
      case JobPostStatus.closed:
        return 'Kapandi';
    }
  }
}

JobPostStatus parseJobPostStatus(String? raw) {
  switch (raw) {
    case 'paused':
      return JobPostStatus.paused;
    case 'closed':
      return JobPostStatus.closed;
    default:
      return JobPostStatus.open;
  }
}

class JobPostModel {
  const JobPostModel({
    required this.id,
    required this.createdBy,
    required this.title,
    required this.description,
    required this.city,
    required this.employmentType,
    required this.vehicleType,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.orgId,
    this.organizationName,
    this.district,
    this.salaryMin,
    this.salaryMax,
    this.contactPhone,
    this.expiresAt,
  });

  final String id;
  final String? orgId;
  final String createdBy;
  final String title;
  final String description;
  final String city;
  final String? district;
  final JobEmploymentType employmentType;
  final JobVehicleType vehicleType;
  final double? salaryMin;
  final double? salaryMax;
  final String currency;
  final JobPostStatus status;
  final String? contactPhone;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? organizationName;

  bool get hasSalaryInfo => salaryMin != null || salaryMax != null;

  String get salaryLabel {
    if (!hasSalaryInfo) {
      return 'Belirtilmedi';
    }
    final String prefix = currency.toUpperCase();
    if (salaryMin != null && salaryMax != null) {
      return '${salaryMin!.toStringAsFixed(0)}-${salaryMax!.toStringAsFixed(0)} $prefix';
    }
    if (salaryMin != null) {
      return '${salaryMin!.toStringAsFixed(0)}+ $prefix';
    }
    return '0-${salaryMax!.toStringAsFixed(0)} $prefix';
  }
}
