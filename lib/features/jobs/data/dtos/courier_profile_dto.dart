import 'package:hkd/features/jobs/domain/models/courier_profile_model.dart';
import 'package:hkd/features/jobs/domain/models/job_post_model.dart';

class CourierProfileDto {
  const CourierProfileDto({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.headline,
    required this.bio,
    required this.city,
    required this.district,
    required this.vehicleType,
    required this.yearsExperience,
    required this.isAvailable,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final String fullName;
  final String phone;
  final String? headline;
  final String? bio;
  final String? city;
  final String? district;
  final String vehicleType;
  final int yearsExperience;
  final bool isAvailable;
  final String createdAt;
  final String updatedAt;

  factory CourierProfileDto.fromMap(Map<String, dynamic> map) {
    final dynamic profileRaw = map['profiles'];
    final Map<String, dynamic> profileMap = profileRaw is Map
        ? profileRaw.cast<String, dynamic>()
        : <String, dynamic>{};

    return CourierProfileDto(
      userId: map['user_id'] as String,
      fullName: (profileMap['full_name'] as String?) ?? 'Isimsiz Uye',
      phone: (profileMap['phone'] as String?) ?? '',
      headline: map['headline'] as String?,
      bio: map['bio'] as String?,
      city: map['city'] as String?,
      district: map['district'] as String?,
      vehicleType: (map['vehicle_type'] as String?) ?? 'motorcycle',
      yearsExperience: _toInt(map['years_experience']),
      isAvailable: (map['is_available'] as bool?) ?? true,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString()) ?? 0;
  }
}

extension CourierProfileDtoMapper on CourierProfileDto {
  CourierProfileModel toDomain() {
    return CourierProfileModel(
      userId: userId,
      fullName: fullName.trim().isEmpty ? 'Isimsiz Uye' : fullName.trim(),
      phone: _displayPhone(phone),
      headline: headline?.trim(),
      bio: bio?.trim(),
      city: city?.trim(),
      district: district?.trim(),
      vehicleType: parseJobVehicleType(vehicleType),
      yearsExperience: yearsExperience < 0 ? 0 : yearsExperience,
      isAvailable: isAvailable,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  String _displayPhone(String rawPhone) {
    if (rawPhone.startsWith('+90') && rawPhone.length == 13) {
      return '0${rawPhone.substring(3)}';
    }
    return rawPhone;
  }
}
