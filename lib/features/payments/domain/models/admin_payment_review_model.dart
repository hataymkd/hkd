class AdminPaymentReviewModel {
  const AdminPaymentReviewModel({
    required this.paymentId,
    required this.invoiceId,
    required this.userId,
    required this.userName,
    required this.periodKey,
    required this.amount,
    required this.status,
    required this.provider,
    required this.providerRef,
    required this.createdAt,
  });

  final String paymentId;
  final String? invoiceId;
  final String? userId;
  final String userName;
  final String? periodKey;
  final double amount;
  final String status;
  final String provider;
  final String? providerRef;
  final DateTime createdAt;
}

class PaymentReconciliationLogModel {
  const PaymentReconciliationLogModel({
    required this.id,
    required this.paymentId,
    required this.invoiceId,
    required this.actorId,
    required this.previousStatus,
    required this.nextStatus,
    required this.reason,
    required this.providerRef,
    required this.createdAt,
  });

  final String id;
  final String? paymentId;
  final String? invoiceId;
  final String? actorId;
  final String? previousStatus;
  final String nextStatus;
  final String? reason;
  final String? providerRef;
  final DateTime createdAt;
}
