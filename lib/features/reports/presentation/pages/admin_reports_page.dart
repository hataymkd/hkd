import 'package:flutter/material.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/utils/date_time_formatter.dart';
import 'package:hkd/core/widgets/error_state_view.dart';
import 'package:hkd/core/widgets/loading_state_view.dart';
import 'package:hkd/features/reports/domain/models/admin_report_snapshot_model.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  bool _isLoading = false;
  String? _errorMessage;
  AdminReportSnapshotModel _snapshot = AdminReportSnapshotModel.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final AdminReportSnapshotModel snapshot =
          await widget.dependencies.reportRepository.fetchAdminSnapshot();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Rapor verileri yuklenemedi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingStateView(message: 'Raporlar yukleniyor...'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Raporlar')),
        body: ErrorStateView(
          title: 'Hata',
          message: _errorMessage!,
          onRetry: _load,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Rapor Zamani: ${DateTimeFormatter.dateTime(_snapshot.generatedAt)}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _MetricCard(
                title: 'Aktif Uye',
                value: _snapshot.activeUsers.toString(),
              ),
              _MetricCard(
                title: 'Onay Bekleyen',
                value: _snapshot.pendingUsers.toString(),
              ),
              _MetricCard(
                title: 'Organizasyon',
                value: _snapshot.totalOrganizations.toString(),
              ),
              _MetricCard(
                title: 'Bekleyen Basvuru',
                value: _snapshot.pendingApplications.toString(),
              ),
              _MetricCard(
                title: 'Acik Is Ilani',
                value: _snapshot.openJobs.toString(),
              ),
              _MetricCard(
                title: 'Bekleyen Fatura',
                value: _snapshot.pendingInvoices.toString(),
              ),
              _MetricCard(
                title: 'Gecikmis Fatura',
                value: _snapshot.overdueInvoices.toString(),
              ),
              _MetricCard(
                title: 'Okunmamis Bildirim',
                value: _snapshot.unreadNotifications.toString(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Finans Ozeti',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Toplam Aidat Tutar: ${_snapshot.totalDueAmount.toStringAsFixed(2)} TL',
                  ),
                  Text(
                    'Toplam Bekleyen Borc: ${_snapshot.outstandingAmount.toStringAsFixed(2)} TL',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
