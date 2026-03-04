import 'dart:convert';

import 'package:hkd/core/env.dart';
import 'package:hkd/features/auth/data/dtos/user_dto.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/auth/domain/models/user_role.dart';
import 'package:hkd/features/auth/domain/repositories/auth_repository.dart';
import 'package:hkd/features/membership/domain/models/membership_application_model.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required SupabaseClient client,
  }) : _client = client;

  final SupabaseClient _client;
  List<UserModel> _userCache = <UserModel>[];

  @override
  Future<UserModel?> login({
    required String phone,
    required String password,
  }) async {
    final String normalizedPassword = password.trim();
    final List<String> phoneCandidates = _buildPhoneCandidates(phone);
    AuthException? lastAuthError;

    for (final String candidate in phoneCandidates) {
      try {
        final AuthResponse response = await _client.auth.signInWithPassword(
          phone: candidate,
          password: normalizedPassword,
        );
        final String? userId =
            response.user?.id ?? _client.auth.currentUser?.id;
        if (userId == null) {
          continue;
        }

        final UserModel? user = await fetchById(userId);
        if (user != null) {
          _upsertCache(user);
        }
        return user;
      } on AuthException catch (error) {
        lastAuthError = error;
      }
    }

    final UserModel? restUser = await _loginViaRestFallback(
      phoneCandidates: phoneCandidates,
      password: normalizedPassword,
    );
    if (restUser != null) {
      _upsertCache(restUser);
      return restUser;
    }

    if (lastAuthError != null) {
      throw StateError(
        'Giris dogrulanamadi. Telefon veya sifre bilgisini kontrol edin.',
      );
    }

    return null;
  }

  @override
  Future<void> requestLoginOtp({
    required String phone,
  }) async {
    final List<String> phoneCandidates = _buildPhoneCandidates(phone);
    if (phoneCandidates.isEmpty) {
      throw StateError('Gecerli telefon numarasi giriniz.');
    }

    AuthException? lastError;
    for (final String candidate in phoneCandidates) {
      try {
        await _client.auth.signInWithOtp(
          phone: candidate,
          shouldCreateUser: false,
        );
        return;
      } on AuthException catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw StateError(
        'OTP kodu gonderilemedi. Telefon numarasini kontrol edin.',
      );
    }
    throw StateError('OTP kodu gonderilemedi.');
  }

  @override
  Future<UserModel?> verifyLoginOtp({
    required String phone,
    required String otpCode,
  }) async {
    final String normalizedOtp = otpCode.replaceAll(' ', '').trim();
    if (normalizedOtp.length < 4) {
      throw StateError('OTP kodu gecersiz.');
    }

    final List<String> phoneCandidates = _buildPhoneCandidates(phone);
    if (phoneCandidates.isEmpty) {
      throw StateError('Gecerli telefon numarasi giriniz.');
    }

    AuthException? lastAuthError;
    for (final String candidate in phoneCandidates) {
      try {
        final AuthResponse response = await _client.auth.verifyOTP(
          phone: candidate,
          token: normalizedOtp,
          type: OtpType.sms,
        );
        final String? userId =
            response.user?.id ?? _client.auth.currentUser?.id;
        if (userId == null || userId.trim().isEmpty) {
          continue;
        }
        final UserModel? user = await fetchById(userId);
        if (user != null) {
          _upsertCache(user);
        }
        return user;
      } on AuthException catch (error) {
        lastAuthError = error;
      }
    }

    if (lastAuthError != null) {
      throw StateError(
        'OTP dogrulamasi basarisiz. Kodu kontrol edip tekrar deneyin.',
      );
    }
    return null;
  }

  @override
  Future<UserModel?> restoreSession() async {
    final Session? session = _client.auth.currentSession;
    if (session == null) {
      return null;
    }
    final UserModel? user = await fetchById(session.user.id);
    if (user != null) {
      _upsertCache(user);
    }
    return user;
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
    _userCache = <UserModel>[];
  }

  @override
  List<UserModel> getUsers() {
    return List<UserModel>.unmodifiable(_userCache);
  }

  @override
  Future<List<UserModel>> fetchUsers() async {
    return _fetchUsers();
  }

  @override
  List<UserModel> getActiveUsers() {
    return List<UserModel>.unmodifiable(
      _userCache.where((UserModel user) => user.isActive),
    );
  }

  @override
  Future<List<UserModel>> fetchActiveUsers() async {
    return _fetchUsers(isActiveFilter: true);
  }

  @override
  List<UserModel> getPendingUsers() {
    return List<UserModel>.unmodifiable(
      _userCache.where((UserModel user) => !user.isActive),
    );
  }

  @override
  Future<List<UserModel>> fetchPendingUsers() async {
    return _fetchUsers(isActiveFilter: false);
  }

  @override
  UserModel? getById(String userId) {
    for (final UserModel user in _userCache) {
      if (user.id == userId) {
        return user;
      }
    }
    return null;
  }

  @override
  Future<UserModel?> fetchById(String userId) async {
    final dynamic profileRaw = await _client
        .from('profiles')
        .select('id, full_name, phone, is_active, created_at')
        .eq('id', userId)
        .maybeSingle();
    if (profileRaw == null) {
      return null;
    }

    final Map<String, dynamic> profileRow =
        (profileRaw as Map).cast<String, dynamic>();
    final List<String> roleKeys = await fetchUserRoleKeys(userId);
    final UserModel user = UserDto.fromMap(
      profileRow,
      roleKeys: roleKeys,
    ).toDomain();
    _upsertCache(user);
    return user;
  }

  @override
  Future<List<String>> fetchUserRoleKeys(String userId) async {
    try {
      final dynamic roleRaw = await _client
          .from('user_roles')
          .select('role_key')
          .eq('user_id', userId);
      final List<dynamic> rows = roleRaw as List<dynamic>;
      if (rows.isEmpty) {
        return <String>['member'];
      }
      return rows
          .map((dynamic raw) =>
              ((raw as Map)['role_key'] as String).toLowerCase())
          .toList();
    } catch (_) {
      return <String>['member'];
    }
  }

  @override
  Future<void> approveMember(String userId) async {
    await reviewUserActivation(
      userId: userId,
      approve: true,
    );
  }

  @override
  Future<void> reviewUserActivation({
    required String userId,
    required bool approve,
    String? reason,
  }) async {
    final FunctionResponse response = await _client.functions.invoke(
      'admin_approve_user',
      body: <String, dynamic>{
        'user_id': userId,
        'approve': approve,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );

    if (response.status >= 400) {
      throw StateError('Kullanici onay islemi basarisiz.');
    }

    final UserModel? updated = await fetchById(userId);
    if (updated != null) {
      _upsertCache(updated);
    }
  }

  @override
  Future<void> claimInitialPresident() async {
    final dynamic raw = await _client.rpc('claim_initial_president');
    final Map<String, dynamic>? payload = _asSingleRow(raw);

    if (payload == null) {
      throw StateError('Baskan atama yaniti gecersiz.');
    }

    final bool ok = payload['ok'] == true;
    final String message = (payload['message'] as String?)?.trim() ?? '';
    if (!ok) {
      if (message.isNotEmpty) {
        throw StateError(message);
      }
      throw StateError('Baskan atama islemi basarisiz.');
    }

    final String? userId = payload['user_id'] as String?;
    if (userId != null && userId.trim().isNotEmpty) {
      final UserModel? updated = await fetchById(userId);
      if (updated != null) {
        _upsertCache(updated);
      }
    }
  }

  @override
  Future<void> assignManager(String userId) async {
    await _client.from('user_roles').upsert(
      <String, dynamic>{
        'user_id': userId,
        'role_key': 'admin',
      },
      onConflict: 'user_id,role_key',
    );

    await _client
        .from('user_roles')
        .delete()
        .eq('user_id', userId)
        .eq('role_key', 'member');

    final UserModel? user = await fetchById(userId);
    if (user != null) {
      _upsertCache(user.copyWith(role: UserRole.manager));
    }
  }

  @override
  Future<void> submitMembershipApplication({
    required String name,
    required String phone,
    required String password,
  }) async {
    await _client.from('membership_applications').insert(
      <String, dynamic>{
        'full_name': name.trim(),
        'phone': _normalizePhone(phone),
      },
    );
  }

  @override
  MembershipApplicationModel? getLatestMembershipApplicationByPhone(
    String phone,
  ) {
    return null;
  }

  @override
  Future<MembershipApplicationModel?> fetchLatestMembershipApplicationByPhone(
    String phone,
  ) async {
    final dynamic raw = await _client
        .from('membership_applications')
        .select(
          'id, full_name, phone, status, reject_reason, reviewed_at, created_at',
        )
        .eq('phone', _normalizePhone(phone))
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (raw == null) {
      return null;
    }
    return _applicationFromMap((raw as Map).cast<String, dynamic>());
  }

  @override
  List<MembershipApplicationModel> getMembershipApplications({
    MembershipApplicationStatus? status,
  }) {
    return const <MembershipApplicationModel>[];
  }

  @override
  Future<List<MembershipApplicationModel>> fetchMembershipApplications({
    MembershipApplicationStatus? status,
  }) async {
    PostgrestFilterBuilder<dynamic> query = _client
        .from(
          'membership_applications',
        )
        .select(
          'id, full_name, phone, status, reject_reason, reviewed_at, reviewed_by, created_at',
        );
    if (status != null) {
      query = query.eq('status', status.name);
    }

    final dynamic raw = await query.order('created_at', ascending: false);
    final List<dynamic> rows = raw as List<dynamic>;
    return rows
        .map(
          (dynamic item) =>
              _applicationFromMap((item as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  @override
  Future<void> approveMembershipApplication({
    required String applicationId,
    required String approvedBy,
  }) async {
    await _client.functions.invoke(
      'approve_membership',
      body: <String, dynamic>{
        'application_id': applicationId,
        'approve': true,
      },
    );
  }

  @override
  Future<void> rejectMembershipApplication({
    required String applicationId,
    required String rejectedBy,
    required String reason,
  }) async {
    await _client.functions.invoke(
      'approve_membership',
      body: <String, dynamic>{
        'application_id': applicationId,
        'approve': false,
        'reject_reason': reason,
      },
    );
  }

  MembershipApplicationModel _applicationFromMap(Map<String, dynamic> row) {
    return MembershipApplicationModel(
      id: row['id'] as String,
      name: (row['full_name'] as String?) ?? '',
      phone: _displayPhone((row['phone'] as String?) ?? ''),
      createdAt: DateTime.parse(row['created_at'] as String),
      status: _mapApplicationStatus((row['status'] as String?) ?? 'pending'),
      decidedAt: row['reviewed_at'] == null
          ? null
          : DateTime.parse(row['reviewed_at'] as String),
      decidedBy: row['reviewed_by'] as String?,
      rejectReason: row['reject_reason'] as String?,
    );
  }

  MembershipApplicationStatus _mapApplicationStatus(String raw) {
    switch (raw) {
      case 'approved':
        return MembershipApplicationStatus.approved;
      case 'rejected':
        return MembershipApplicationStatus.rejected;
      default:
        return MembershipApplicationStatus.pending;
    }
  }

  void _upsertCache(UserModel user) {
    final int index =
        _userCache.indexWhere((UserModel item) => item.id == user.id);
    if (index == -1) {
      _userCache.add(user);
      return;
    }
    _userCache[index] = user;
  }

  String _normalizePhone(String rawPhone) {
    final String compact = rawPhone.replaceAll(RegExp(r'[\s()-]+'), '').trim();
    if (compact.isEmpty) {
      return compact;
    }

    if (compact.startsWith('+')) {
      final String digits = compact.substring(1).replaceAll(RegExp(r'\D'), '');
      return '+$digits';
    }

    final String digits = compact.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 11) {
      return '+90${digits.substring(1)}';
    }
    if (digits.startsWith('90') && digits.length == 12) {
      return '+$digits';
    }
    if (digits.length == 10) {
      return '+90$digits';
    }

    return compact;
  }

  List<String> _buildPhoneCandidates(String rawPhone) {
    final String compact = rawPhone.replaceAll(RegExp(r'[\s()-]+'), '').trim();
    if (compact.isEmpty) {
      return const <String>[];
    }

    final String digits = compact.replaceAll(RegExp(r'\D'), '');
    final Set<String> values = <String>{};

    if (compact.startsWith('+') && digits.isNotEmpty) {
      values.add('+$digits');
    }

    if (digits.startsWith('0') && digits.length == 11) {
      final String plus = '+90${digits.substring(1)}';
      values.add(plus);
      values.add(plus.substring(1));
      values.add(digits);
    } else if (digits.startsWith('90') && digits.length == 12) {
      values.add('+$digits');
      values.add(digits);
      values.add('0${digits.substring(2)}');
    } else if (digits.length == 10) {
      values.add('+90$digits');
      values.add('90$digits');
      values.add('0$digits');
    }

    values.add(compact);
    if (compact.startsWith('+') && compact.length > 1) {
      values.add(compact.substring(1));
    }

    return values.toList(growable: false);
  }

  String _displayPhone(String phone) {
    if (phone.startsWith('+90') && phone.length == 13) {
      return '0${phone.substring(3)}';
    }
    return phone;
  }

  Future<UserModel?> _loginViaRestFallback({
    required List<String> phoneCandidates,
    required String password,
  }) async {
    final Uri uri = Uri.parse('${Env.supabaseUrl}/auth/v1/token').replace(
      queryParameters: <String, String>{'grant_type': 'password'},
    );

    for (final String candidate in phoneCandidates) {
      final http.Response response;
      try {
        response = await http
            .post(
              uri,
              headers: <String, String>{
                'apikey': Env.supabaseAnonKey,
                'Authorization': 'Bearer ${Env.supabaseAnonKey}',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(<String, dynamic>{
                'phone': candidate,
                'password': password,
              }),
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        continue;
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> payload =
            jsonDecode(response.body) as Map<String, dynamic>;
        await _client.auth.recoverSession(jsonEncode(payload));
        final String? userId =
            (payload['user'] as Map<String, dynamic>?)?['id'] as String? ??
                _client.auth.currentUser?.id;
        if (userId == null || userId.trim().isEmpty) {
          return null;
        }
        return fetchById(userId);
      }

      if (response.statusCode == 400) {
        final Map<String, dynamic>? payload = _tryDecodeBody(response.body);
        final String code =
            (payload?['error_code'] as String?)?.toLowerCase() ?? '';
        if (code == 'invalid_credentials') {
          continue;
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? _tryDecodeBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<UserModel>> _fetchUsers({
    bool? isActiveFilter,
  }) async {
    PostgrestFilterBuilder<dynamic> query = _client
        .from('profiles')
        .select('id, full_name, phone, is_active, created_at');
    if (isActiveFilter != null) {
      query = query.eq('is_active', isActiveFilter);
    }

    final dynamic profileRaw = await query;
    final List<dynamic> profileRows = profileRaw as List<dynamic>;

    final dynamic roleRaw =
        await _client.from('user_roles').select('user_id, role_key');
    final List<dynamic> roleRows = roleRaw as List<dynamic>;

    final Map<String, List<String>> roleMap = <String, List<String>>{};
    for (final dynamic raw in roleRows) {
      final Map<String, dynamic> row = (raw as Map).cast<String, dynamic>();
      final String roleUserId = row['user_id'] as String;
      final String roleKey = (row['role_key'] as String).toLowerCase();
      roleMap.putIfAbsent(roleUserId, () => <String>[]).add(roleKey);
    }

    final List<UserModel> users = profileRows.map((dynamic raw) {
      final Map<String, dynamic> row = (raw as Map).cast<String, dynamic>();
      final String id = row['id'] as String;
      final List<String> roleKeys = roleMap[id] ?? <String>['member'];
      return UserDto.fromMap(row, roleKeys: roleKeys).toDomain();
    }).toList();

    if (isActiveFilter == null) {
      _userCache = users;
    }
    return List<UserModel>.unmodifiable(users);
  }

  Map<String, dynamic>? _asSingleRow(dynamic raw) {
    if (raw is Map) {
      return raw.cast<String, dynamic>();
    }
    if (raw is List<dynamic> && raw.isNotEmpty && raw.first is Map) {
      return (raw.first as Map).cast<String, dynamic>();
    }
    return null;
  }
}
