import 'package:hkd/features/organizations/domain/models/organization_model.dart';

class OrganizationDto {
  const OrganizationDto({
    required this.id,
    required this.type,
    required this.name,
    required this.phone,
    required this.taxNo,
    required this.createdBy,
    required this.createdAt,
    required this.myRole,
    required this.myStatus,
  });

  final String id;
  final String type;
  final String name;
  final String? phone;
  final String? taxNo;
  final String? createdBy;
  final String createdAt;
  final String myRole;
  final String myStatus;

  factory OrganizationDto.fromMap(Map<String, dynamic> map) {
    return OrganizationDto(
      id: map['id'] as String,
      type: map['type'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      taxNo: map['tax_no'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as String,
      myRole: map['my_role'] as String,
      myStatus: map['my_status'] as String,
    );
  }
}

extension OrganizationDtoMapper on OrganizationDto {
  OrganizationModel toDomain() {
    return OrganizationModel(
      id: id,
      type: organizationTypeFromDb(type),
      name: name.trim().isEmpty ? 'Isimsiz Organizasyon' : name.trim(),
      phone: _displayPhone(phone),
      taxNo: taxNo,
      createdBy: createdBy,
      createdAt: DateTime.parse(createdAt),
      myRole: organizationRoleFromDb(myRole),
      myStatus: organizationMembershipStatusFromDb(myStatus),
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
