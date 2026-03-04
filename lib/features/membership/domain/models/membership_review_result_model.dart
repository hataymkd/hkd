class MembershipReviewResultModel {
  const MembershipReviewResultModel({
    required this.status,
    this.userId,
    this.tempPassword,
  });

  final String status;
  final String? userId;
  final String? tempPassword;
}
