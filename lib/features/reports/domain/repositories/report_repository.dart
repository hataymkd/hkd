import 'package:hkd/features/reports/domain/models/admin_report_snapshot_model.dart';

abstract class ReportRepository {
  Future<AdminReportSnapshotModel> fetchAdminSnapshot();
}
