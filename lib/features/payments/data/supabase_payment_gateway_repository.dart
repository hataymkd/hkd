import 'dart:collection';

import 'package:hkd/features/payments/domain/models/admin_payment_review_model.dart';
import 'package:hkd/features/payments/domain/models/payment_checkout_result_model.dart';
import 'package:hkd/features/payments/domain/repositories/payment_gateway_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabasePaymentGatewayRepository implements PaymentGatewayRepository {
  SupabasePaymentGatewayRepository({
    required SupabaseClient client,
  }) : _client = client;

  final SupabaseClient _client;

  @override
  Future<PaymentCheckoutResultModel> startCheckout({
    required String invoiceId,
  }) async {
    final String normalizedInvoiceId = invoiceId.trim();
    if (normalizedInvoiceId.isEmpty) {
      throw StateError('Gecerli bir fatura seciniz.');
    }

    final FunctionResponse response = await _client.functions.invoke(
      'create_payment_checkout',
      body: <String, dynamic>{'invoice_id': normalizedInvoiceId},
    );

    if (response.status >= 400) {
      throw StateError('Odeme baslatilamadi.');
    }

    final dynamic data = response.data;
    if (data is! Map) {
      throw StateError('Odeme yaniti gecersiz.');
    }
    final Map<String, dynamic> payload = data.cast<String, dynamic>();

    return PaymentCheckoutResultModel(
      paymentId: (payload['payment_id'] as String?) ?? '',
      provider: (payload['provider'] as String?) ?? 'manual',
      status: (payload['status'] as String?) ?? 'created',
      checkoutUrl: payload['checkout_url'] as String?,
      instructions: payload['instructions'] as String?,
    );
  }

  @override
  Future<List<AdminPaymentReviewModel>> fetchReviewQueue({
    int limit = 30,
  }) async {
    final dynamic paymentsRaw = await _client
        .from('payments')
        .select(
            'id, invoice_id, user_id, amount, provider, provider_ref, status, created_at')
        .order('created_at', ascending: false)
        .limit(limit);

    final List<dynamic> paymentRows = paymentsRaw as List<dynamic>;
    if (paymentRows.isEmpty) {
      return const <AdminPaymentReviewModel>[];
    }

    final Set<String> userIds = <String>{};
    final Set<String> invoiceIds = <String>{};
    for (final dynamic row in paymentRows) {
      final Map map = row as Map;
      final String? userId = map['user_id'] as String?;
      final String? invoiceId = map['invoice_id'] as String?;
      if (userId != null && userId.trim().isNotEmpty) {
        userIds.add(userId);
      }
      if (invoiceId != null && invoiceId.trim().isNotEmpty) {
        invoiceIds.add(invoiceId);
      }
    }

    final Map<String, String> userNamesById = await _fetchUserNames(
      userIds.toList(growable: false),
    );
    final Map<String, String> periodByInvoiceId =
        await _fetchPeriodKeysByInvoice(
      invoiceIds.toList(growable: false),
    );

    final List<AdminPaymentReviewModel> items = paymentRows.map(
      (dynamic raw) {
        final Map<String, dynamic> row = (raw as Map).cast<String, dynamic>();
        final String? userId = row['user_id'] as String?;
        final String? invoiceId = row['invoice_id'] as String?;
        return AdminPaymentReviewModel(
          paymentId: row['id'] as String,
          invoiceId: invoiceId,
          userId: userId,
          userName: userNamesById[userId] ?? 'Bilinmeyen Uye',
          periodKey: periodByInvoiceId[invoiceId],
          amount: (row['amount'] as num?)?.toDouble() ?? 0,
          status: (row['status'] as String?) ?? 'created',
          provider: (row['provider'] as String?) ?? 'manual',
          providerRef: row['provider_ref'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      },
    ).toList(growable: false);

    return UnmodifiableListView<AdminPaymentReviewModel>(items);
  }

  @override
  Future<List<PaymentReconciliationLogModel>> fetchReconciliationLogs({
    int limit = 30,
  }) async {
    final dynamic raw = await _client
        .from('payment_reconciliation_logs')
        .select(
            'id, payment_id, invoice_id, actor_id, previous_status, next_status, reason, provider_ref, created_at')
        .order('created_at', ascending: false)
        .limit(limit);

    final List<PaymentReconciliationLogModel> items =
        (raw as List<dynamic>).map((dynamic item) {
      final Map<String, dynamic> row = (item as Map).cast<String, dynamic>();
      return PaymentReconciliationLogModel(
        id: row['id'] as String,
        paymentId: row['payment_id'] as String?,
        invoiceId: row['invoice_id'] as String?,
        actorId: row['actor_id'] as String?,
        previousStatus: row['previous_status'] as String?,
        nextStatus: (row['next_status'] as String?) ?? 'created',
        reason: row['reason'] as String?,
        providerRef: row['provider_ref'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList(growable: false);

    return UnmodifiableListView<PaymentReconciliationLogModel>(items);
  }

  @override
  Future<void> confirmPayment({
    required String paymentId,
    required String status,
    String? providerRef,
    String? reason,
  }) async {
    final String normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus != 'succeeded' &&
        normalizedStatus != 'failed' &&
        normalizedStatus != 'refunded') {
      throw StateError('Odeme durumu gecersiz.');
    }

    final FunctionResponse response = await _client.functions.invoke(
      'confirm_payment',
      body: <String, dynamic>{
        'payment_id': paymentId.trim(),
        'status': normalizedStatus,
        if (providerRef != null && providerRef.trim().isNotEmpty)
          'provider_ref': providerRef.trim(),
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );

    if (response.status >= 400) {
      throw StateError('Odeme durumu guncellenemedi.');
    }
  }

  Future<Map<String, String>> _fetchUserNames(List<String> userIds) async {
    if (userIds.isEmpty) {
      return const <String, String>{};
    }

    final dynamic raw = await _client
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', userIds);

    final Map<String, String> map = <String, String>{};
    for (final dynamic item in (raw as List<dynamic>)) {
      final Map row = item as Map;
      final String id = row['id'] as String;
      final String name = ((row['full_name'] as String?) ?? '').trim();
      map[id] = name.isEmpty ? 'Isimsiz Uye' : name;
    }
    return map;
  }

  Future<Map<String, String>> _fetchPeriodKeysByInvoice(
    List<String> invoiceIds,
  ) async {
    if (invoiceIds.isEmpty) {
      return const <String, String>{};
    }

    final dynamic invoiceRaw = await _client
        .from('dues_invoices')
        .select('id, period_id')
        .inFilter('id', invoiceIds);
    final List<dynamic> invoiceRows = invoiceRaw as List<dynamic>;

    final Set<String> periodIds = <String>{};
    final Map<String, String> periodIdByInvoiceId = <String, String>{};
    for (final dynamic item in invoiceRows) {
      final Map row = item as Map;
      final String invoiceId = row['id'] as String;
      final String? periodId = row['period_id'] as String?;
      if (periodId == null || periodId.trim().isEmpty) {
        continue;
      }
      periodIds.add(periodId);
      periodIdByInvoiceId[invoiceId] = periodId;
    }

    final Map<String, String> periodKeyByPeriodId = <String, String>{};
    if (periodIds.isNotEmpty) {
      final dynamic periodsRaw = await _client
          .from('dues_periods')
          .select('id, period_key')
          .inFilter('id', periodIds.toList(growable: false));
      for (final dynamic item in (periodsRaw as List<dynamic>)) {
        final Map row = item as Map;
        periodKeyByPeriodId[row['id'] as String] =
            (row['period_key'] as String?) ?? '';
      }
    }

    final Map<String, String> periodKeyByInvoiceId = <String, String>{};
    periodIdByInvoiceId.forEach((String invoiceId, String periodId) {
      final String periodKey = periodKeyByPeriodId[periodId] ?? '';
      if (periodKey.trim().isNotEmpty) {
        periodKeyByInvoiceId[invoiceId] = periodKey;
      }
    });
    return periodKeyByInvoiceId;
  }
}
