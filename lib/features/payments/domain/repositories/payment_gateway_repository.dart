import 'package:hkd/features/payments/domain/models/payment_checkout_result_model.dart';
import 'package:hkd/features/payments/domain/models/admin_payment_review_model.dart';

abstract class PaymentGatewayRepository {
  Future<PaymentCheckoutResultModel> startCheckout({
    required String invoiceId,
  });

  Future<List<AdminPaymentReviewModel>> fetchReviewQueue({
    int limit = 30,
  });

  Future<List<PaymentReconciliationLogModel>> fetchReconciliationLogs({
    int limit = 30,
  });

  Future<void> confirmPayment({
    required String paymentId,
    required String status,
    String? providerRef,
    String? reason,
  });
}
