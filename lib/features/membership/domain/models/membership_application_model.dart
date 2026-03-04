enum MembershipApplicationStatus {
  pending,
  approved,
  rejected,
}

enum MembershipMemberType {
  courier,
  courierCompany,
  business,
}

extension MembershipMemberTypeX on MembershipMemberType {
  String get dbValue {
    switch (this) {
      case MembershipMemberType.courier:
        return 'courier';
      case MembershipMemberType.courierCompany:
        return 'courier_company';
      case MembershipMemberType.business:
        return 'business';
    }
  }

  String get label {
    switch (this) {
      case MembershipMemberType.courier:
        return 'Bireysel Kurye';
      case MembershipMemberType.courierCompany:
        return 'Kurye Sirketi / Filo';
      case MembershipMemberType.business:
        return 'Isletme';
    }
  }
}

MembershipMemberType membershipMemberTypeFromDb(String raw) {
  switch (raw) {
    case 'courier_company':
      return MembershipMemberType.courierCompany;
    case 'business':
      return MembershipMemberType.business;
    default:
      return MembershipMemberType.courier;
  }
}

extension MembershipApplicationStatusX on MembershipApplicationStatus {
  String get label {
    switch (this) {
      case MembershipApplicationStatus.pending:
        return 'Beklemede';
      case MembershipApplicationStatus.approved:
        return 'Onaylandi';
      case MembershipApplicationStatus.rejected:
        return 'Reddedildi';
    }
  }
}

class MembershipApplicationModel {
  const MembershipApplicationModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.createdAt,
    required this.status,
    this.memberType = MembershipMemberType.courier,
    this.orgName,
    this.orgPhone,
    this.orgTaxNo,
    this.requestedOrgRole,
    this.decidedAt,
    this.decidedBy,
    this.rejectReason,
  });

  final String id;
  final String name;
  final String phone;
  final DateTime createdAt;
  final MembershipApplicationStatus status;
  final MembershipMemberType memberType;
  final String? orgName;
  final String? orgPhone;
  final String? orgTaxNo;
  final String? requestedOrgRole;
  final DateTime? decidedAt;
  final String? decidedBy;
  final String? rejectReason;

  MembershipApplicationModel copyWith({
    String? id,
    String? name,
    String? phone,
    DateTime? createdAt,
    MembershipApplicationStatus? status,
    MembershipMemberType? memberType,
    String? orgName,
    String? orgPhone,
    String? orgTaxNo,
    String? requestedOrgRole,
    DateTime? decidedAt,
    String? decidedBy,
    String? rejectReason,
  }) {
    return MembershipApplicationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      memberType: memberType ?? this.memberType,
      orgName: orgName ?? this.orgName,
      orgPhone: orgPhone ?? this.orgPhone,
      orgTaxNo: orgTaxNo ?? this.orgTaxNo,
      requestedOrgRole: requestedOrgRole ?? this.requestedOrgRole,
      decidedAt: decidedAt ?? this.decidedAt,
      decidedBy: decidedBy ?? this.decidedBy,
      rejectReason: rejectReason ?? this.rejectReason,
    );
  }
}
