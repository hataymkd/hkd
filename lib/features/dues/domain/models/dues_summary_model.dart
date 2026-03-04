class DuesSummaryModel {
  const DuesSummaryModel({
    required this.totalCount,
    required this.paidCount,
    required this.unpaidCount,
    required this.overdueCount,
    required this.totalAmount,
    required this.outstandingAmount,
  });

  final int totalCount;
  final int paidCount;
  final int unpaidCount;
  final int overdueCount;
  final double totalAmount;
  final double outstandingAmount;
}
