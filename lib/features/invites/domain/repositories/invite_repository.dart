import 'package:hkd/features/invites/domain/models/invite_accept_result_model.dart';

abstract class InviteRepository {
  Future<InviteAcceptResultModel> acceptInvite({
    required String token,
    required String fullName,
    required String phone,
    required String password,
  });
}
