import 'package:hkd/features/dues/domain/models/dues_invoice_model.dart';
import 'package:hkd/features/dues/domain/models/dues_period_model.dart';
import 'package:hkd/features/dues/domain/models/dues_summary_model.dart';

abstract class DuesRepository {
  Future<List<DuesPeriodModel>> fetchPeriods();

  Future<List<DuesInvoiceModel>> fetchInvoices({
    String? userId,
    String? periodKey,
  });

  DuesSummaryModel summarize(List<DuesInvoiceModel> invoices);

  Future<double> fetchCurrentAmount();

  Future<void> setCurrentAmount(double amount);

  Future<void> ensureUserInvoicePlan(String userId);
}
