import 'package:flutter_test/flutter_test.dart';
import 'package:hkd/core/authorization/app_permission.dart';
import 'package:hkd/core/authorization/authorization_service.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/auth/domain/models/user_role.dart';

void main() {
  const AuthorizationService authorizationService = AuthorizationService();

  UserModel buildUser(UserRole role) {
    return UserModel(
      id: 'u1',
      name: 'Test',
      phone: '05000000000',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  test('president has all management permissions', () {
    final UserModel president = buildUser(UserRole.president);
    expect(
      authorizationService.can(
        user: president,
        permission: AppPermission.assignManager,
      ),
      isTrue,
    );
    expect(
      authorizationService.can(
        user: president,
        permission: AppPermission.setDueAmount,
      ),
      isTrue,
    );
  });

  test('manager can add announcement but cannot assign manager', () {
    final UserModel manager = buildUser(UserRole.manager);
    expect(
      authorizationService.can(
        user: manager,
        permission: AppPermission.addAnnouncement,
      ),
      isTrue,
    );
    expect(
      authorizationService.can(
        user: manager,
        permission: AppPermission.assignManager,
      ),
      isFalse,
    );
  });

  test('member cannot open management panel', () {
    final UserModel member = buildUser(UserRole.member);
    expect(
      authorizationService.can(
        user: member,
        permission: AppPermission.openManagementPanel,
      ),
      isFalse,
    );
  });
}
