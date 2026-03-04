enum OrganizationType {
  business,
  courierCompany,
}

enum OrganizationRole {
  owner,
  manager,
  staff,
}

enum OrganizationMembershipStatus {
  pending,
  active,
}

extension OrganizationTypeX on OrganizationType {
  String get dbValue {
    switch (this) {
      case OrganizationType.business:
        return 'business';
      case OrganizationType.courierCompany:
        return 'courier_company';
    }
  }

  String get label {
    switch (this) {
      case OrganizationType.business:
        return 'Isletme';
      case OrganizationType.courierCompany:
        return 'Kurye Sirketi / Filo';
    }
  }
}

extension OrganizationRoleX on OrganizationRole {
  String get dbValue {
    switch (this) {
      case OrganizationRole.owner:
        return 'owner';
      case OrganizationRole.manager:
        return 'manager';
      case OrganizationRole.staff:
        return 'staff';
    }
  }

  String get label {
    switch (this) {
      case OrganizationRole.owner:
        return 'Owner';
      case OrganizationRole.manager:
        return 'Manager';
      case OrganizationRole.staff:
        return 'Staff';
    }
  }
}

extension OrganizationMembershipStatusX on OrganizationMembershipStatus {
  String get dbValue {
    switch (this) {
      case OrganizationMembershipStatus.pending:
        return 'pending';
      case OrganizationMembershipStatus.active:
        return 'active';
    }
  }

  String get label {
    switch (this) {
      case OrganizationMembershipStatus.pending:
        return 'Onay Bekliyor';
      case OrganizationMembershipStatus.active:
        return 'Aktif';
    }
  }
}

OrganizationType organizationTypeFromDb(String raw) {
  switch (raw) {
    case 'courier_company':
      return OrganizationType.courierCompany;
    default:
      return OrganizationType.business;
  }
}

OrganizationRole organizationRoleFromDb(String raw) {
  switch (raw) {
    case 'owner':
      return OrganizationRole.owner;
    case 'manager':
      return OrganizationRole.manager;
    default:
      return OrganizationRole.staff;
  }
}

OrganizationMembershipStatus organizationMembershipStatusFromDb(String raw) {
  switch (raw) {
    case 'active':
      return OrganizationMembershipStatus.active;
    default:
      return OrganizationMembershipStatus.pending;
  }
}

class OrganizationModel {
  const OrganizationModel({
    required this.id,
    required this.type,
    required this.name,
    required this.phone,
    required this.createdBy,
    required this.createdAt,
    required this.myRole,
    required this.myStatus,
    this.taxNo,
  });

  final String id;
  final OrganizationType type;
  final String name;
  final String? phone;
  final String? taxNo;
  final String? createdBy;
  final DateTime createdAt;
  final OrganizationRole myRole;
  final OrganizationMembershipStatus myStatus;
}
