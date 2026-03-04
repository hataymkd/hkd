import 'package:hkd/features/organizations/domain/models/organization_member_model.dart';
import 'package:hkd/features/organizations/domain/models/organization_model.dart';

class OrganizationMemberDto {
  const OrganizationMemberDto({
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
  final String role;
  final String status;
  final String createdAt;

  factory OrganizationMemberDto.fromMap(Map<String, dynamic> map) {
    return OrganizationMemberDto(
      userId: map['user_id'] as String,
      fullName: (map['full_name'] as String?) ?? '',
      phone: map['phone'] as String?,
      isActive: (map['is_active'] as bool?) ?? false,
      role: map['org_role'] as String,
      status: map['status'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}

extension OrganizationMemberDtoMapper on OrganizationMemberDto {
  OrganizationMemberModel toDomain() {
    return OrganizationMemberModel(
      userId: userId,
      fullName: fullName.trim().isEmpty ? 'Isimsiz Uye' : fullName.trim(),
      phone: _displayPhone(phone),
      isActive: isActive,
      role: organizationRoleFromDb(role),
      status: organizationMembershipStatusFromDb(status),
      createdAt: DateTime.parse(createdAt),
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
