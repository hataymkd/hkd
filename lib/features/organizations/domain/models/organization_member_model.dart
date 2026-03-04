import 'package:hkd/features/organizations/domain/models/organization_model.dart';

class OrganizationMemberModel {
  const OrganizationMemberModel({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.isActive,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  final String userId;
  final String fullName;
  final String? phone;
  final bool isActive;
  final OrganizationRole role;
  final OrganizationMembershipStatus status;
  final DateTime createdAt;
}
