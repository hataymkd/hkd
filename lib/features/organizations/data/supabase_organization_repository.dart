import 'package:hkd/features/organizations/data/dtos/organization_dto.dart';
import 'package:hkd/features/organizations/data/dtos/organization_invite_dto.dart';
import 'package:hkd/features/organizations/data/dtos/organization_member_dto.dart';
import 'package:hkd/features/organizations/domain/models/organization_invite_model.dart';
import 'package:hkd/features/organizations/domain/models/organization_member_model.dart';
import 'package:hkd/features/organizations/domain/models/organization_model.dart';
import 'package:hkd/features/organizations/domain/repositories/organization_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOrganizationRepository implements OrganizationRepository {
  SupabaseOrganizationRepository({
    required SupabaseClient client,
  }) : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<OrganizationModel>> fetchMyOrganizations() async {
    final String? currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw StateError('Oturum bulunamadi. Lutfen yeniden giris yapin.');
    }

    final dynamic raw = await _client
        .from('organization_members')
        .select(
          'org_id, org_role, status, '
          'organizations!inner(id, type, name, phone, tax_no, created_by, created_at)',
        )
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false);

    final List<dynamic> rows = raw as List<dynamic>;

    final List<OrganizationModel> organizations = rows
        .map((dynamic rawItem) => _mapOrganization(rawItem))
        .whereType<OrganizationModel>()
        .toList();

    organizations.sort((OrganizationModel left, OrganizationModel right) {
      final int statusCompare =
          _statusWeight(left.myStatus).compareTo(_statusWeight(right.myStatus));
      if (statusCompare != 0) {
        return statusCompare;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

    return List<OrganizationModel>.unmodifiable(organizations);
  }

  @override
  Future<List<OrganizationMemberModel>> fetchOrganizationMembers({
    required String organizationId,
  }) async {
    final dynamic raw = await _client
        .from('organization_members')
        .select(
          'user_id, org_role, status, created_at, '
          'profiles!inner(full_name, phone, is_active)',
        )
        .eq('org_id', organizationId)
        .order('created_at', ascending: true);

    final List<dynamic> rows = raw as List<dynamic>;
    final List<OrganizationMemberModel> members = rows
        .map((dynamic rawItem) => _mapOrganizationMember(rawItem))
        .whereType<OrganizationMemberModel>()
        .toList();

    members.sort((OrganizationMemberModel left, OrganizationMemberModel right) {
      final int roleCompare =
          _roleWeight(left.role).compareTo(_roleWeight(right.role));
      if (roleCompare != 0) {
        return roleCompare;
      }
      return left.fullName
          .toLowerCase()
          .compareTo(right.fullName.toLowerCase());
    });

    return List<OrganizationMemberModel>.unmodifiable(members);
  }

  @override
  Future<List<OrganizationInviteModel>> fetchOrganizationInvites({
    required String organizationId,
  }) async {
    final dynamic raw = await _client
        .from('invites')
        .select(
          'id, org_id, phone, token, status, expires_at, created_at, accepted_user_id, accepted_at',
        )
        .eq('org_id', organizationId)
        .order('created_at', ascending: false);

    final List<dynamic> rows = raw as List<dynamic>;
    final List<OrganizationInviteModel> invites = rows
        .map(
          (dynamic item) => OrganizationInviteDto.fromMap(
            (item as Map).cast<String, dynamic>(),
          ).toDomain(),
        )
        .toList();

    return List<OrganizationInviteModel>.unmodifiable(invites);
  }

  @override
  Future<OrganizationInviteModel> createInvite({
    required String organizationId,
    required String phone,
  }) async {
    final FunctionResponse response = await _client.functions.invoke(
      'create_invite',
      body: <String, dynamic>{
        'org_id': organizationId,
        'phone': _normalizePhone(phone),
      },
    );

    if (response.status >= 400 || response.data is! Map) {
      throw StateError(_extractErrorMessage(response.data));
    }

    final Map<String, dynamic> payload =
        (response.data as Map).cast<String, dynamic>();

    if (payload['ok'] != true) {
      throw StateError(
        (payload['error'] as String?) ?? 'Davet olusturulamadi.',
      );
    }

    final String token = (payload['token'] as String?) ?? '';
    if (token.trim().isEmpty) {
      throw StateError('Davet token bilgisi alinamadi.');
    }

    final dynamic inviteRaw = await _client
        .from('invites')
        .select(
          'id, org_id, phone, token, status, expires_at, created_at, accepted_user_id, accepted_at',
        )
        .eq('token', token)
        .maybeSingle();

    if (inviteRaw == null) {
      throw StateError('Olusturulan davet kaydi okunamadi.');
    }

    final Map<String, dynamic> inviteMap =
        (inviteRaw as Map).cast<String, dynamic>();
    inviteMap['invite_url'] = payload['invite_url'];

    return OrganizationInviteDto.fromMap(inviteMap).toDomain();
  }

  @override
  Future<void> cancelInvite({
    required String inviteId,
  }) async {
    await _client
        .from('invites')
        .update(
          <String, dynamic>{
            'status': 'cancelled',
            'accepted_user_id': null,
            'accepted_at': null,
          },
        )
        .eq('id', inviteId)
        .eq('status', 'pending');
  }

  @override
  Future<void> updateMemberRole({
    required String organizationId,
    required String userId,
    required OrganizationRole role,
  }) async {
    final String normalizedOrgId = organizationId.trim();
    final String normalizedUserId = userId.trim();
    if (normalizedOrgId.isEmpty || normalizedUserId.isEmpty) {
      throw StateError('Gecerli organizasyon ve uye seciniz.');
    }

    if (role == OrganizationRole.owner) {
      final dynamic ownerRaw = await _client
          .from('organization_members')
          .select('user_id')
          .eq('org_id', normalizedOrgId)
          .eq('org_role', OrganizationRole.owner.dbValue)
          .maybeSingle();
      if (ownerRaw is Map) {
        final String? currentOwnerId = ownerRaw['user_id'] as String?;
        if (currentOwnerId != null &&
            currentOwnerId.trim().isNotEmpty &&
            currentOwnerId != normalizedUserId) {
          await _client
              .from('organization_members')
              .update(
                <String, dynamic>{
                  'org_role': OrganizationRole.manager.dbValue,
                },
              )
              .eq('org_id', normalizedOrgId)
              .eq('user_id', currentOwnerId);
        }
      }
    }

    await _client
        .from('organization_members')
        .update(
          <String, dynamic>{
            'org_role': role.dbValue,
            'status': OrganizationMembershipStatus.active.dbValue,
          },
        )
        .eq('org_id', normalizedOrgId)
        .eq('user_id', normalizedUserId);
  }

  @override
  Future<void> updateMemberStatus({
    required String organizationId,
    required String userId,
    required OrganizationMembershipStatus status,
  }) async {
    await _client
        .from('organization_members')
        .update(
          <String, dynamic>{
            'status': status.dbValue,
          },
        )
        .eq('org_id', organizationId)
        .eq('user_id', userId);
  }

  OrganizationModel? _mapOrganization(dynamic rawItem) {
    if (rawItem is! Map) {
      return null;
    }

    final Map<String, dynamic> row = rawItem.cast<String, dynamic>();
    final dynamic organizationRaw = row['organizations'];
    if (organizationRaw is! Map) {
      return null;
    }

    final Map<String, dynamic> organizationMap =
        organizationRaw.cast<String, dynamic>();

    return OrganizationDto.fromMap(
      <String, dynamic>{
        ...organizationMap,
        'my_role': row['org_role'],
        'my_status': row['status'],
      },
    ).toDomain();
  }

  OrganizationMemberModel? _mapOrganizationMember(dynamic rawItem) {
    if (rawItem is! Map) {
      return null;
    }

    final Map<String, dynamic> row = rawItem.cast<String, dynamic>();
    final dynamic profileRaw = row['profiles'];
    if (profileRaw is! Map) {
      return null;
    }

    final Map<String, dynamic> profileMap = profileRaw.cast<String, dynamic>();

    return OrganizationMemberDto.fromMap(
      <String, dynamic>{
        'user_id': row['user_id'],
        'org_role': row['org_role'],
        'status': row['status'],
        'created_at': row['created_at'],
        'full_name': profileMap['full_name'],
        'phone': profileMap['phone'],
        'is_active': profileMap['is_active'],
      },
    ).toDomain();
  }

  int _statusWeight(OrganizationMembershipStatus status) {
    switch (status) {
      case OrganizationMembershipStatus.active:
        return 0;
      case OrganizationMembershipStatus.pending:
        return 1;
    }
  }

  int _roleWeight(OrganizationRole role) {
    switch (role) {
      case OrganizationRole.owner:
        return 0;
      case OrganizationRole.manager:
        return 1;
      case OrganizationRole.staff:
        return 2;
    }
  }

  String _extractErrorMessage(dynamic data) {
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return 'Islem basarisiz oldu.';
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
