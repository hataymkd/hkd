import 'package:hkd/features/invites/domain/models/invite_accept_result_model.dart';
import 'package:hkd/features/invites/domain/repositories/invite_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseInviteRepository implements InviteRepository {
  SupabaseInviteRepository({
    required SupabaseClient client,
  }) : _client = client;

  final SupabaseClient _client;

  @override
  Future<InviteAcceptResultModel> acceptInvite({
    required String token,
    required String fullName,
    required String phone,
    required String password,
  }) async {
    final FunctionResponse response = await _client.functions.invoke(
      'accept_invite',
      body: <String, dynamic>{
        'token': token.trim(),
        'full_name': fullName.trim(),
        'phone': _normalizePhone(phone),
        'password': password,
      },
    );

    if (response.status >= 400 || response.data is! Map) {
      throw StateError(_extractErrorMessage(response.data));
    }

    final Map<String, dynamic> payload =
        (response.data as Map).cast<String, dynamic>();
    final bool ok = payload['ok'] == true;
    if (!ok) {
      throw StateError(
        (payload['error'] as String?) ?? 'Davet kabul islemi basarisiz.',
      );
    }

    return InviteAcceptResultModel(
      ok: true,
      status: (payload['status'] as String?) ?? 'pending_approval',
      userId: payload['user_id'] as String?,
    );
  }

  String _extractErrorMessage(dynamic data) {
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return 'Davet kabul istegi basarisiz oldu.';
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
