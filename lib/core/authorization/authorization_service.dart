import 'package:hkd/core/authorization/app_permission.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/auth/domain/models/user_role.dart';

class AuthorizationService {
  const AuthorizationService();

  bool can({
    required UserModel user,
    required AppPermission permission,
  }) {
    switch (permission) {
      case AppPermission.addAnnouncement:
      case AppPermission.editAnnouncement:
      case AppPermission.deleteAnnouncement:
        return user.role == UserRole.president || user.role == UserRole.manager;
      case AppPermission.setDueAmount:
      case AppPermission.approveMembers:
      case AppPermission.assignManager:
        return user.role == UserRole.president;
      case AppPermission.viewMembers:
      case AppPermission.viewAllPayments:
      case AppPermission.openManagementPanel:
        return user.role == UserRole.president || user.role == UserRole.manager;
    }
  }
}
