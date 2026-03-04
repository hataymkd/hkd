import 'package:hkd/features/jobs/domain/models/job_post_model.dart';

class CourierProfileModel {
  const CourierProfileModel({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.vehicleType,
    required this.yearsExperience,
    required this.isAvailable,
    required this.createdAt,
    required this.updatedAt,
    this.headline,
    this.bio,
    this.city,
    this.district,
  });

  final String userId;
  final String fullName;
  final String phone;
  final String? headline;
  final String? bio;
  final String? city;
  final String? district;
  final JobVehicleType vehicleType;
  final int yearsExperience;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;
}
