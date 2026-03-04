import 'package:hkd/features/organizations/domain/models/organization_invite_model.dart';

class OrganizationInviteDto {
  const OrganizationInviteDto({
    required this.id,
    required this.orgId,
    required this.phone,
    required this.token,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.inviteUrl,
    this.acceptedUserId,
    this.acceptedAt,
  });

  final String id;
  final String orgId;
  final String phone;
  final String token;
  final String status;
  final String expiresAt;
  final String createdAt;
  final String? inviteUrl;
  final String? acceptedUserId;
  final String? acceptedAt;

  factory OrganizationInviteDto.fromMap(Map<String, dynamic> map) {
    return OrganizationInviteDto(
      id: map['id'] as String,
      orgId: map['org_id'] as String,
      phone: map['phone'] as String,
      token: (map['token'] as String?) ?? '',
      status: map['status'] as String,
      expiresAt: map['expires_at'] as String,
      createdAt: map['created_at'] as String,
      inviteUrl: map['invite_url'] as String?,
      acceptedUserId: map['accepted_user_id'] as String?,
      acceptedAt: map['accepted_at'] as String?,
    );
  }
}

extension OrganizationInviteDtoMapper on OrganizationInviteDto {
  OrganizationInviteModel toDomain() {
    return OrganizationInviteModel(
      id: id,
      orgId: orgId,
      phone: _displayPhone(phone),
      token: token,
      status: status,
      expiresAt: DateTime.parse(expiresAt),
      createdAt: DateTime.parse(createdAt),
      inviteUrl: inviteUrl,
      acceptedUserId: acceptedUserId,
      acceptedAt: acceptedAt == null ? null : DateTime.parse(acceptedAt!),
    );
  }

  String _displayPhone(String rawPhone) {
    if (rawPhone.startsWith('+90') && rawPhone.length == 13) {
      return '0${rawPhone.substring(3)}';
    }
    return rawPhone;
  }
}
