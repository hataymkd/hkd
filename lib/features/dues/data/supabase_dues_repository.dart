import 'package:hkd/features/dues/data/dtos/dues_invoice_dto.dart';
import 'package:hkd/features/dues/data/dtos/dues_period_dto.dart';
import 'package:hkd/features/dues/domain/models/dues_invoice_model.dart';
import 'package:hkd/features/dues/domain/models/dues_period_model.dart';
import 'package:hkd/features/dues/domain/models/dues_summary_model.dart';
import 'package:hkd/features/dues/domain/repositories/dues_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDuesRepository implements DuesRepository {
  SupabaseDuesRepository({
    required SupabaseClient client,
  }) : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<DuesPeriodModel>> fetchPeriods() async {
    final dynamic raw = await _client
        .from('dues_periods')
        .select('id, year, month, period_key, amount, due_date, created_at')
        .order('year', ascending: false)
        .order('month', ascending: false);

    final List<dynamic> rows = raw as List<dynamic>;
    return rows
        .map(
          (dynamic item) =>
              DuesPeriodDto.fromMap((item as Map).cast<String, dynamic>())
                  .toDomain(),
        )
        .toList();
  }

  @override
  Future<List<DuesInvoiceModel>> fetchInvoices({
    String? userId,
    String? periodKey,
  }) async {
    PostgrestFilterBuilder<dynamic> query =
        _client.from('dues_invoices').select(
              'id, user_id, period_id, amount, status, paid_at, created_at, '
              'dues_periods(period_key, due_date)',
            );

    if (userId != null) {
      query = query.eq('user_id', userId);
    }
    if (periodKey != null && periodKey.trim().isNotEmpty) {
      query = query.eq('dues_periods.period_key', periodKey.trim());
    }

    final dynamic raw = await query.order('created_at', ascending: false);
    final List<dynamic> rows = raw as List<dynamic>;
    return rows
        .map(
          (dynamic item) =>
              DuesInvoiceDto.fromMap((item as Map).cast<String, dynamic>())
                  .toDomain(),
        )
        .toList();
  }

  @override
  DuesSummaryModel summarize(List<DuesInvoiceModel> invoices) {
    final int paidCount = invoices
        .where((DuesInvoiceModel item) => item.status == DuesInvoiceStatus.paid)
        .length;
    final int unpaidCount = invoices
        .where(
            (DuesInvoiceModel item) => item.status == DuesInvoiceStatus.unpaid)
        .length;
    final int overdueCount = invoices
        .where(
            (DuesInvoiceModel item) => item.status == DuesInvoiceStatus.overdue)
        .length;

    final double totalAmount = invoices.fold(
      0,
      (double total, DuesInvoiceModel item) => total + item.amount,
    );

    final double outstandingAmount = invoices
        .where(
          (DuesInvoiceModel item) =>
              item.status == DuesInvoiceStatus.unpaid ||
              item.status == DuesInvoiceStatus.overdue,
        )
        .fold(0, (double total, DuesInvoiceModel item) => total + item.amount);

    return DuesSummaryModel(
      totalCount: invoices.length,
      paidCount: paidCount,
      unpaidCount: unpaidCount,
      overdueCount: overdueCount,
      totalAmount: totalAmount,
      outstandingAmount: outstandingAmount,
    );
  }

  @override
  Future<double> fetchCurrentAmount() async {
    final List<DuesPeriodModel> periods = await fetchPeriods();
    if (periods.isEmpty) {
      return 0;
    }
    return periods.first.amount;
  }

  @override
  Future<void> setCurrentAmount(double amount) async {
    if (amount <= 0) {
      throw StateError('Aidat tutari sifirdan buyuk olmali.');
    }

    final DateTime now = DateTime.now();
    final String periodKey = _periodKey(now.year, now.month);
    final String dueDate =
        DateTime(now.year, now.month, 10).toIso8601String().split('T').first;

    final dynamic existing = await _client
        .from('dues_periods')
        .select('id')
        .eq('period_key', periodKey)
        .maybeSingle();

    if (existing == null) {
      await _client.from('dues_periods').insert(
        <String, dynamic>{
          'year': now.year,
          'month': now.month,
          'period_key': periodKey,
          'amount': amount,
          'due_date': dueDate,
        },
      );
      return;
    }

    await _client
        .from('dues_periods')
        .update(<String, dynamic>{'amount': amount, 'due_date': dueDate}).eq(
            'id', (existing as Map)['id'] as String);
  }

  @override
  Future<void> ensureUserInvoicePlan(String userId) async {
    final List<DuesPeriodModel> periods = await fetchPeriods();
    if (periods.isEmpty) {
      return;
    }

    final List<DuesPeriodModel> seed = periods.take(3).toList();
    for (final DuesPeriodModel period in seed) {
      final dynamic existing = await _client
          .from('dues_invoices')
          .select('id')
          .eq('user_id', userId)
          .eq('period_id', period.id)
          .maybeSingle();
      if (existing != null) {
        continue;
      }

      await _client.from('dues_invoices').insert(
        <String, dynamic>{
          'user_id': userId,
          'period_id': period.id,
          'amount': period.amount,
          'status': 'unpaid',
        },
      );
    }
  }

  String _periodKey(int year, int month) {
    final String monthRaw = month.toString().padLeft(2, '0');
    return '$year-$monthRaw';
  }
}
