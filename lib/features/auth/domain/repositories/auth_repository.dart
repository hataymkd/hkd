import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/membership/domain/models/membership_application_model.dart';

abstract class AuthRepository {
  Future<UserModel?> login({
    required String phone,
    required String password,
  });

  Future<void> requestLoginOtp({
    required String phone,
  }) async {}

  Future<UserModel?> verifyLoginOtp({
    required String phone,
    required String otpCode,
  }) async {
    return null;
  }

  Future<UserModel?> restoreSession() async {
    return null;
  }

  Future<void> logout() async {}

  List<UserModel> getUsers();

  Future<List<UserModel>> fetchUsers() async {
    return getUsers();
  }

  List<UserModel> getActiveUsers();

  Future<List<UserModel>> fetchActiveUsers() async {
    return getActiveUsers();
  }

  List<UserModel> getPendingUsers();

  Future<List<UserModel>> fetchPendingUsers() async {
    return getPendingUsers();
  }

  UserModel? getById(String userId);

  Future<UserModel?> fetchById(String userId) async {
    return getById(userId);
  }

  Future<List<String>> fetchUserRoleKeys(String userId) async {
    final UserModel? user = getById(userId);
    if (user == null) {
      return <String>[];
    }
    switch (user.role.name) {
      case 'president':
        return <String>['president'];
      case 'manager':
        return <String>['admin'];
      default:
        return <String>['member'];
    }
  }

  Future<void> approveMember(String userId);

  Future<void> assignManager(String userId);

  Future<void> reviewUserActivation({
    required String userId,
    required bool approve,
    String? reason,
  }) async {
    if (approve) {
      await approveMember(userId);
    }
  }

  Future<void> claimInitialPresident() async {
    throw UnsupportedError('President bootstrap is not supported.');
  }

  Future<void> submitMembershipApplication({
    required String name,
    required String phone,
    required String password,
  });

  MembershipApplicationModel? getLatestMembershipApplicationByPhone(
    String phone,
  );

  Future<MembershipApplicationModel?> fetchLatestMembershipApplicationByPhone(
    String phone,
  ) async {
    return getLatestMembershipApplicationByPhone(phone);
  }

  List<MembershipApplicationModel> getMembershipApplications({
    MembershipApplicationStatus? status,
  });

  Future<List<MembershipApplicationModel>> fetchMembershipApplications({
    MembershipApplicationStatus? status,
  }) async {
    return getMembershipApplications(status: status);
  }

  Future<void> approveMembershipApplication({
    required String applicationId,
    required String approvedBy,
  });

  Future<void> rejectMembershipApplication({
    required String applicationId,
    required String rejectedBy,
    required String reason,
  });
}
