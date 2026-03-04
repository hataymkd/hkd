import 'package:hkd/features/membership/domain/models/membership_application_model.dart';
import 'package:hkd/features/membership/domain/models/membership_review_result_model.dart';

abstract class MembershipRepository {
  Future<String> apply({
    required String fullName,
    required String phone,
    required String password,
    MembershipMemberType memberType = MembershipMemberType.courier,
    String? orgName,
    String? orgPhone,
    String? orgTaxNo,
  });

  Future<MembershipApplicationModel?> getById(String applicationId);

  Future<List<MembershipApplicationModel>> list({
    MembershipApplicationStatus? status,
  });

  Future<MembershipReviewResultModel> review({
    required String applicationId,
    required bool approve,
    String? rejectReason,
    String? tempPassword,
  });
}
