import 'package:hkd/features/organizations/domain/models/organization_invite_model.dart';
import 'package:hkd/features/organizations/domain/models/organization_member_model.dart';
import 'package:hkd/features/organizations/domain/models/organization_model.dart';

abstract class OrganizationRepository {
  Future<List<OrganizationModel>> fetchMyOrganizations();

  Future<List<OrganizationMemberModel>> fetchOrganizationMembers({
    required String organizationId,
  });

  Future<List<OrganizationInviteModel>> fetchOrganizationInvites({
    required String organizationId,
  });

  Future<OrganizationInviteModel> createInvite({
    required String organizationId,
    required String phone,
  });

  Future<void> cancelInvite({
    required String inviteId,
  });

  Future<void> updateMemberRole({
    required String organizationId,
    required String userId,
    required OrganizationRole role,
  });

  Future<void> updateMemberStatus({
    required String organizationId,
    required String userId,
    required OrganizationMembershipStatus status,
  });
}
