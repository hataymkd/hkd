import 'package:hkd/features/payments/domain/models/payment_model.dart';
import 'package:hkd/features/payments/domain/models/payment_summary_model.dart';

abstract class PaymentRepository {
  List<PaymentModel> fetchPayments();

  List<PaymentModel> fetchPaymentsByUserId(String userId);

  List<String> fetchPeriods();

  PaymentSummaryModel summaryFor(List<PaymentModel> payments);

  double get monthlyDueAmount;

  Future<void> setMonthlyDueAmount(double amount);

  Future<void> ensureUserPaymentPlan(String userId);
}
