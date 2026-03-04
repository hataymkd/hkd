import 'package:hkd/features/reports/domain/models/admin_report_snapshot_model.dart';
import 'package:hkd/features/reports/domain/repositories/report_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseReportRepository implements ReportRepository {
  SupabaseReportRepository({
    required SupabaseClient client,
  }) : _client = client;

  final SupabaseClient _client;

  @override
  Future<AdminReportSnapshotModel> fetchAdminSnapshot() async {
    final dynamic raw = await _client.rpc('admin_report_snapshot');
    final Map<String, dynamic>? payload = _asMap(raw);
    if (payload == null) {
      throw StateError('Rapor verisi alinamadi.');
    }

    return AdminReportSnapshotModel(
      generatedAt:
          DateTime.tryParse(payload['generated_at'] as String? ?? '') ??
              DateTime.now(),
      activeUsers: _toInt(payload['active_users']),
      pendingUsers: _toInt(payload['pending_users']),
      totalOrganizations: _toInt(payload['total_organizations']),
      pendingApplications: _toInt(payload['pending_applications']),
      openJobs: _toInt(payload['open_jobs']),
      pendingInvoices: _toInt(payload['pending_invoices']),
      overdueInvoices: _toInt(payload['overdue_invoices']),
      totalDueAmount: _toDouble(payload['total_due_amount']),
      outstandingAmount: _toDouble(payload['outstanding_amount']),
      unreadNotifications: _toInt(payload['unread_notifications']),
    );
  }

  Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map) {
      return raw.cast<String, dynamic>();
    }
    if (raw is List<dynamic> && raw.isNotEmpty && raw.first is Map) {
      return (raw.first as Map).cast<String, dynamic>();
    }
    return null;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }
}
