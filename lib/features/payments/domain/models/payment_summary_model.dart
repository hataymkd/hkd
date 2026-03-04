class PaymentSummaryModel {
  const PaymentSummaryModel({
    required this.totalCount,
    required this.paidCount,
    required this.pendingCount,
    required this.overdueCount,
    required this.totalAmount,
    required this.overdueAmount,
  });

  final int totalCount;
  final int paidCount;
  final int pendingCount;
  final int overdueCount;
  final double totalAmount;
  final double overdueAmount;
}
