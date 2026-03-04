import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/auth/domain/models/user_role.dart';
import 'package:hkd/features/auth/domain/repositories/auth_repository.dart';
import 'package:hkd/features/membership/domain/models/membership_application_model.dart';

class MockAuthRepository implements AuthRepository {
  int _nextUserId = 4;
  int _nextApplicationId = 3;
  final Map<String, String> _otpByPhone = <String, String>{};

  final List<UserModel> _users = <UserModel>[
    UserModel(
      id: 'user-1',
      name: 'Ahmet Kaya',
      phone: '05001112233',
      role: UserRole.president,
      isActive: true,
      createdAt: DateTime(2025, 1, 15),
    ),
    UserModel(
      id: 'user-2',
      name: 'Ayse Demir',
      phone: '05002223344',
      role: UserRole.manager,
      isActive: true,
      createdAt: DateTime(2025, 3, 2),
    ),
    UserModel(
      id: 'user-3',
      name: 'Mehmet Yilmaz',
      phone: '05003334455',
      role: UserRole.member,
      isActive: true,
      createdAt: DateTime(2025, 6, 10),
    ),
    UserModel(
      id: 'user-4',
      name: 'Fatma Cetin',
      phone: '05004445566',
      role: UserRole.member,
      isActive: false,
      createdAt: DateTime(2026, 1, 4),
    ),
  ];

  final Map<String, String> _passwordByPhone = <String, String>{
    '05001112233': '123456',
    '05002223344': '123456',
    '05003334455': '123456',
    '05004445566': '123456',
  };

  final List<MembershipApplicationModel> _applications =
      <MembershipApplicationModel>[
    MembershipApplicationModel(
      id: 'app-1',
      name: 'Fatma Cetin',
      phone: '05004445566',
      createdAt: DateTime(2026, 1, 4, 9, 30),
      status: MembershipApplicationStatus.pending,
    ),
    MembershipApplicationModel(
      id: 'app-2',
      name: 'Kerem Arslan',
      phone: '05005556677',
      createdAt: DateTime(2026, 1, 12, 11, 45),
      status: MembershipApplicationStatus.rejected,
      decidedAt: DateTime(2026, 1, 13, 17, 20),
      decidedBy: 'Ahmet Kaya',
      rejectReason: 'Eksik evrak',
    ),
  ];

  @override
  Future<UserModel?> login({
    required String phone,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final String normalizedPhone = phone.trim();
    final String normalizedPassword = password.trim();

    final UserModel? user = _findByPhone(normalizedPhone);
    if (user == null) {
      return null;
    }

    final String? expectedPassword = _passwordByPhone[normalizedPhone];
    if (expectedPassword != normalizedPassword) {
      return null;
    }

    if (!user.isActive) {
      return null;
    }

    return user;
  }

  @override
  Future<void> requestLoginOtp({
    required String phone,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final String normalizedPhone = phone.trim();
    final UserModel? user = _findByPhone(normalizedPhone);
    if (user == null) {
      throw StateError('OTP kodu gonderilemedi. Telefon bulunamadi.');
    }
    _otpByPhone[normalizedPhone] = '123456';
  }

  @override
  Future<UserModel?> verifyLoginOtp({
    required String phone,
    required String otpCode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final String normalizedPhone = phone.trim();
    final String normalizedOtp = otpCode.replaceAll(' ', '').trim();
    final String? expected = _otpByPhone[normalizedPhone];
    if (expected == null || expected != normalizedOtp) {
      return null;
    }
    final UserModel? user = _findByPhone(normalizedPhone);
    if (user == null || !user.isActive) {
      return null;
    }
    return user;
  }

  @override
  Future<UserModel?> restoreSession() async {
    return null;
  }

  @override
  Future<void> logout() async {}

  @override
  List<UserModel> getUsers() {
    return List<UserModel>.unmodifiable(_users);
  }

  @override
  Future<List<UserModel>> fetchUsers() async {
    return getUsers();
  }

  @override
  List<UserModel> getActiveUsers() {
    return List<UserModel>.unmodifiable(
      _users.where((UserModel user) => user.isActive),
    );
  }

  @override
  Future<List<UserModel>> fetchActiveUsers() async {
    return getActiveUsers();
  }

  @override
  List<UserModel> getPendingUsers() {
    return List<UserModel>.unmodifiable(
      _users.where((UserModel user) => !user.isActive),
    );
  }

  @override
  Future<List<UserModel>> fetchPendingUsers() async {
    return getPendingUsers();
  }

  @override
  UserModel? getById(String userId) {
    final int index = _users.indexWhere((UserModel item) => item.id == userId);
    if (index == -1) {
      return null;
    }
    return _users[index];
  }

  @override
  Future<UserModel?> fetchById(String userId) async {
    return getById(userId);
  }

  @override
  Future<List<String>> fetchUserRoleKeys(String userId) async {
    final UserModel? user = getById(userId);
    if (user == null) {
      return <String>[];
    }
    switch (user.role) {
      case UserRole.president:
        return <String>['president'];
      case UserRole.manager:
        return <String>['admin'];
      case UserRole.member:
        return <String>['member'];
    }
  }

  @override
  Future<void> approveMember(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final UserModel? target = getById(userId);
    if (target == null) {
      return;
    }

    _replaceUser(target.copyWith(isActive: true));
  }

  @override
  Future<void> assignManager(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final UserModel? target = getById(userId);
    if (target == null) {
      return;
    }

    if (!target.isActive || target.role == UserRole.president) {
      return;
    }

    _replaceUser(target.copyWith(role: UserRole.manager));
  }

  @override
  Future<void> reviewUserActivation({
    required String userId,
    required bool approve,
    String? reason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final UserModel? target = getById(userId);
    if (target == null) {
      return;
    }

    _replaceUser(target.copyWith(isActive: approve));
  }

  @override
  Future<void> claimInitialPresident() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final bool hasPresident =
        _users.any((UserModel user) => user.role == UserRole.president);
    if (hasPresident) {
      throw StateError('Baskan rolu zaten atanmis.');
    }

    int targetIndex = -1;
    for (int i = 0; i < _users.length; i++) {
      if (!_users[i].isActive) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex == -1) {
      throw StateError('Baskan atanacak bekleyen kullanici bulunamadi.');
    }

    final UserModel target = _users[targetIndex];
    _users[targetIndex] = target.copyWith(
      role: UserRole.president,
      isActive: true,
    );
  }

  @override
  Future<void> submitMembershipApplication({
    required String name,
    required String phone,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final String normalizedPhone = phone.trim();
    if (_findByPhone(normalizedPhone) != null) {
      throw StateError('Bu telefon numarasiyla kayitli bir uye bulunuyor.');
    }

    final MembershipApplicationModel? latest =
        getLatestMembershipApplicationByPhone(normalizedPhone);
    if (latest != null &&
        latest.status == MembershipApplicationStatus.pending) {
      throw StateError('Bu telefon icin zaten bekleyen bir basvuru var.');
    }

    _nextApplicationId += 1;
    _applications.add(
      MembershipApplicationModel(
        id: 'app-$_nextApplicationId',
        name: name.trim(),
        phone: normalizedPhone,
        createdAt: DateTime.now(),
        status: MembershipApplicationStatus.pending,
      ),
    );

    _passwordByPhone[normalizedPhone] = password.trim();
  }

  @override
  MembershipApplicationModel? getLatestMembershipApplicationByPhone(
    String phone,
  ) {
    final List<MembershipApplicationModel> matches = _applications
        .where((MembershipApplicationModel application) =>
            application.phone == phone)
        .toList()
      ..sort(
        (MembershipApplicationModel first, MembershipApplicationModel second) =>
            second.createdAt.compareTo(first.createdAt),
      );
    if (matches.isEmpty) {
      return null;
    }
    return matches.first;
  }

  @override
  Future<MembershipApplicationModel?> fetchLatestMembershipApplicationByPhone(
    String phone,
  ) async {
    return getLatestMembershipApplicationByPhone(phone);
  }

  @override
  List<MembershipApplicationModel> getMembershipApplications({
    MembershipApplicationStatus? status,
  }) {
    final Iterable<MembershipApplicationModel> source = status == null
        ? _applications
        : _applications.where(
            (MembershipApplicationModel application) =>
                application.status == status,
          );
    final List<MembershipApplicationModel> list =
        List<MembershipApplicationModel>.from(source);
    list.sort(
      (MembershipApplicationModel first, MembershipApplicationModel second) =>
          second.createdAt.compareTo(first.createdAt),
    );
    return list;
  }

  @override
  Future<List<MembershipApplicationModel>> fetchMembershipApplications({
    MembershipApplicationStatus? status,
  }) async {
    return getMembershipApplications(status: status);
  }

  @override
  Future<void> approveMembershipApplication({
    required String applicationId,
    required String approvedBy,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));

    final int index = _applications.indexWhere(
      (MembershipApplicationModel item) => item.id == applicationId,
    );
    if (index == -1) {
      return;
    }

    final MembershipApplicationModel current = _applications[index];
    if (current.status != MembershipApplicationStatus.pending) {
      return;
    }

    _applications[index] = current.copyWith(
      status: MembershipApplicationStatus.approved,
      decidedAt: DateTime.now(),
      decidedBy: approvedBy,
      rejectReason: null,
    );

    final UserModel? existingUser = _findByPhone(current.phone);
    if (existingUser != null) {
      _replaceUser(existingUser.copyWith(isActive: true));
      return;
    }

    _nextUserId += 1;
    _users.add(
      UserModel(
        id: 'user-$_nextUserId',
        name: current.name,
        phone: current.phone,
        role: UserRole.member,
        isActive: true,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> rejectMembershipApplication({
    required String applicationId,
    required String rejectedBy,
    required String reason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));

    final int index = _applications.indexWhere(
      (MembershipApplicationModel item) => item.id == applicationId,
    );
    if (index == -1) {
      return;
    }

    final MembershipApplicationModel current = _applications[index];
    if (current.status != MembershipApplicationStatus.pending) {
      return;
    }

    _applications[index] = current.copyWith(
      status: MembershipApplicationStatus.rejected,
      decidedAt: DateTime.now(),
      decidedBy: rejectedBy,
      rejectReason: reason.trim(),
    );
  }

  UserModel? _findByPhone(String phone) {
    final int index =
        _users.indexWhere((UserModel item) => item.phone == phone);
    if (index == -1) {
      return null;
    }
    return _users[index];
  }

  void _replaceUser(UserModel updatedUser) {
    final int index = _users.indexWhere(
      (UserModel item) => item.id == updatedUser.id,
    );
    if (index == -1) {
      return;
    }
    _users[index] = updatedUser;
  }
}
