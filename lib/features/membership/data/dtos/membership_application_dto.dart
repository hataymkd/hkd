import 'package:hkd/features/membership/domain/models/membership_application_model.dart';

class MembershipApplicationDto {
  const MembershipApplicationDto({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.createdAt,
    required this.status,
    required this.memberType,
    this.orgName,
    this.orgPhone,
    this.orgTaxNo,
    this.requestedOrgRole,
    this.decidedAt,
    this.decidedBy,
    this.rejectReason,
  });

  final String id;
  final String fullName;
  final String phone;
  final String createdAt;
  final String status;
  final String memberType;
  final String? orgName;
  final String? orgPhone;
  final String? orgTaxNo;
  final String? requestedOrgRole;
  final String? decidedAt;
  final String? decidedBy;
  final String? rejectReason;

  factory MembershipApplicationDto.fromMap(Map<String, dynamic> map) {
    return MembershipApplicationDto(
      id: map['id'] as String,
      fullName: (map['full_name'] as String?) ?? '',
      phone: map['phone'] as String,
      createdAt: map['created_at'] as String,
      status: map['status'] as String,
      memberType: (map['member_type'] as String?) ?? 'courier',
      orgName: map['org_name'] as String?,
      orgPhone: map['org_phone'] as String?,
      orgTaxNo: map['org_tax_no'] as String?,
      requestedOrgRole: map['requested_org_role'] as String?,
      decidedAt: (map['decided_at'] ?? map['reviewed_at']) as String?,
      decidedBy: (map['decided_by'] ?? map['reviewed_by']) as String?,
      rejectReason: map['reject_reason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'created_at': createdAt,
      'status': status,
      'member_type': memberType,
      'org_name': orgName,
      'org_phone': orgPhone,
      'org_tax_no': orgTaxNo,
      'requested_org_role': requestedOrgRole,
      'decided_at': decidedAt,
      'decided_by': decidedBy,
      'reject_reason': rejectReason,
    };
  }
}

extension MembershipApplicationDtoMapper on MembershipApplicationDto {
  MembershipApplicationModel toDomain() {
    return MembershipApplicationModel(
      id: id,
      name: fullName,
      phone: _displayPhone(phone),
      createdAt: DateTime.parse(createdAt),
      status: _statusFrom(status),
      memberType: membershipMemberTypeFromDb(memberType),
      orgName: orgName,
      orgPhone: orgPhone == null ? null : _displayPhone(orgPhone!),
      orgTaxNo: orgTaxNo,
      requestedOrgRole: requestedOrgRole,
      decidedAt: decidedAt == null ? null : DateTime.parse(decidedAt!),
      decidedBy: decidedBy,
      rejectReason: rejectReason,
    );
  }

  MembershipApplicationStatus _statusFrom(String raw) {
    switch (raw) {
      case 'approved':
        return MembershipApplicationStatus.approved;
      case 'rejected':
        return MembershipApplicationStatus.rejected;
      default:
        return MembershipApplicationStatus.pending;
    }
  }
}

extension MembershipApplicationModelMapper on MembershipApplicationModel {
  MembershipApplicationDto toDto() {
    return MembershipApplicationDto(
      id: id,
      fullName: name,
      phone: _normalizePhone(phone),
      createdAt: createdAt.toIso8601String(),
      status: status.name,
      memberType: memberType.dbValue,
      orgName: orgName,
      orgPhone: orgPhone == null ? null : _normalizePhone(orgPhone!),
      orgTaxNo: orgTaxNo,
      requestedOrgRole: requestedOrgRole,
      decidedAt: decidedAt?.toIso8601String(),
      decidedBy: decidedBy,
      rejectReason: rejectReason,
    );
  }

  String _normalizePhone(String rawPhone) {
    final String value = rawPhone.replaceAll(RegExp(r'\s+'), '');
    if (value.startsWith('+')) {
      return value;
    }
    if (value.startsWith('0') && value.length == 11) {
      return '+90${value.substring(1)}';
    }
    return value;
  }
}

String _displayPhone(String phone) {
  if (phone.startsWith('+90') && phone.length == 13) {
    return '0${phone.substring(3)}';
  }
  return phone;
}
