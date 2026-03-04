enum UserRole {
  president,
  manager,
  member,
}

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.president:
        return 'Baskan';
      case UserRole.manager:
        return 'Yonetici';
      case UserRole.member:
        return 'Uye';
    }
  }
}
