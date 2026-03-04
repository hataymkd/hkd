import 'package:hkd/features/membership/data/dtos/membership_application_dto.dart';
import 'package:hkd/features/membership/domain/models/membership_application_model.dart';
import 'package:hkd/features/membership/domain/models/membership_review_result_model.dart';
import 'package:hkd/features/membership/domain/repositories/membership_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseMembershipRepository implements MembershipRepository {
  SupabaseMembershipRepository({
    required SupabaseClient client,
  }) : _client = client;

  final SupabaseClient _client;

  @override
  Future<String> apply({
    required String fullName,
    required String phone,
    required String password,
    MembershipMemberType memberType = MembershipMemberType.courier,
    String? orgName,
    String? orgPhone,
    String? orgTaxNo,
  }) async {
    final dynamic raw = await _client
        .from('membership_applications')
        .insert(
          <String, dynamic>{
            'full_name': fullName.trim(),
            'phone': _normalizePhone(phone),
            'member_type': memberType.dbValue,
            if (memberType != MembershipMemberType.courier)
              'org_name': orgName?.trim(),
            if (memberType != MembershipMemberType.courier &&
                orgPhone != null &&
                orgPhone.trim().isNotEmpty)
              'org_phone': _normalizePhone(orgPhone),
            if (memberType != MembershipMemberType.courier &&
                orgTaxNo != null &&
                orgTaxNo.trim().isNotEmpty)
              'org_tax_no': orgTaxNo.trim(),
            if (memberType != MembershipMemberType.courier)
              'requested_org_role': 'owner',
          },
        )
        .select('id')
        .single();

    final Map<String, dynamic> row = (raw as Map).cast<String, dynamic>();
    return row['id'] as String;
  }

  @override
  Future<MembershipApplicationModel?> getById(String applicationId) async {
    final dynamic raw = await _client.rpc(
      'get_membership_application_status',
      params: <String, dynamic>{
        'p_application_id': applicationId,
      },
    );

    if (raw == null) {
      return null;
    }

    Map<String, dynamic>? row;
    if (raw is Map) {
      row = raw.cast<String, dynamic>();
    } else if (raw is List<dynamic> && raw.isNotEmpty && raw.first is Map) {
      row = (raw.first as Map).cast<String, dynamic>();
    }

    if (row == null) {
      return null;
    }

    final MembershipApplicationDto dto = MembershipApplicationDto.fromMap(
      row,
    );
    return dto.toDomain();
  }

  @override
  Future<List<MembershipApplicationModel>> list({
    MembershipApplicationStatus? status,
  }) async {
    PostgrestFilterBuilder<dynamic> query =
        _client.from('membership_applications').select(
              'id, full_name, phone, member_type, org_name, org_phone, org_tax_no, requested_org_role, status, reject_reason, reviewed_by, reviewed_at, created_at',
            );

    if (status != null) {
      query = query.eq('status', status.name);
    }

    final dynamic raw = await query.order('created_at', ascending: false);
    final List<dynamic> rows = raw as List<dynamic>;
    return rows
        .map(
          (dynamic item) => MembershipApplicationDto.fromMap(
            (item as Map).cast<String, dynamic>(),
          ).toDomain(),
        )
        .toList();
  }

  @override
  Future<MembershipReviewResultModel> review({
    required String applicationId,
    required bool approve,
    String? rejectReason,
    String? tempPassword,
  }) async {
    final FunctionResponse response = await _client.functions.invoke(
      'approve_membership',
      body: <String, dynamic>{
        'application_id': applicationId,
        'approve': approve,
        if (!approve && rejectReason != null) 'reject_reason': rejectReason,
        if (approve && tempPassword != null) 'temp_password': tempPassword,
      },
    );

    if (response.status >= 400) {
      final String message = _extractErrorMessage(response.data);
      throw StateError(message);
    }

    if (response.data is! Map) {
      throw StateError('Sunucu yaniti gecersiz.');
    }

    final Map<String, dynamic> payload =
        (response.data as Map).cast<String, dynamic>();
    final bool ok = payload['ok'] == true;
    if (!ok) {
      throw StateError(
        (payload['error'] as String?) ??
            'Basvuru degerlendirme islemi basarisiz.',
      );
    }

    return MembershipReviewResultModel(
      status:
          (payload['status'] as String?) ?? (approve ? 'approved' : 'rejected'),
      userId: payload['user_id'] as String?,
      tempPassword: payload['temp_password'] as String?,
    );
  }

  String _extractErrorMessage(dynamic responseData) {
    if (responseData is Map && responseData['error'] is String) {
      return responseData['error'] as String;
    }
    return 'Basvuru degerlendirme istegi basarisiz.';
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
