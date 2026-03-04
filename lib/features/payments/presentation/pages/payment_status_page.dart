import 'package:flutter/material.dart';
import 'package:hkd/core/authorization/app_permission.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/utils/date_time_formatter.dart';
import 'package:hkd/core/widgets/empty_state_view.dart';
import 'package:hkd/core/widgets/error_state_view.dart';
import 'package:hkd/core/widgets/loading_state_view.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/dues/domain/models/dues_invoice_model.dart';
import 'package:hkd/features/dues/domain/models/dues_period_model.dart';
import 'package:hkd/features/dues/domain/models/dues_summary_model.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentStatusPage extends StatefulWidget {
  const PaymentStatusPage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends State<PaymentStatusPage> {
  bool _isLoading = false;
  bool _isCheckoutWorking = false;
  String? _errorMessage;
  String? _selectedPeriodKey;
  double _currentAmount = 0;

  List<DuesPeriodModel> _periods = <DuesPeriodModel>[];
  List<DuesInvoiceModel> _invoices = <DuesInvoiceModel>[];
  Map<String, UserModel> _usersById = <String, UserModel>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final UserModel? currentUser =
        widget.dependencies.sessionController.currentUser;
    if (currentUser == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bool canViewAll = widget.dependencies.authorizationService.can(
        user: currentUser,
        permission: AppPermission.viewAllPayments,
      );

      final List<DuesPeriodModel> periods =
          await widget.dependencies.duesRepository.fetchPeriods();
      final List<DuesInvoiceModel> invoices =
          await widget.dependencies.duesRepository.fetchInvoices(
        userId: canViewAll ? null : currentUser.id,
      );
      final double amount =
          await widget.dependencies.duesRepository.fetchCurrentAmount();

      Map<String, UserModel> usersById = <String, UserModel>{};
      if (canViewAll) {
        final List<UserModel> users =
            await widget.dependencies.authRepository.fetchUsers();
        usersById = <String, UserModel>{
          for (final UserModel user in users) user.id: user,
        };
      } else {
        usersById = <String, UserModel>{currentUser.id: currentUser};
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _periods = periods;
        _invoices = invoices;
        _usersById = usersById;
        _currentAmount = amount;
        _selectedPeriodKey = _resolvePeriodSelection(
          previous: _selectedPeriodKey,
          periods: periods,
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Aidat verileri yuklenemedi.';
        _isLoading = false;
      });
    }
  }

  String? _resolvePeriodSelection({
    required String? previous,
    required List<DuesPeriodModel> periods,
  }) {
    if (periods.isEmpty) {
      return null;
    }
    final Set<String> periodKeys =
        periods.map((DuesPeriodModel item) => item.periodKey).toSet();
    if (previous != null && periodKeys.contains(previous)) {
      return previous;
    }
    return periods.first.periodKey;
  }

  @override
  Widget build(BuildContext context) {
    final UserModel? currentUser =
        widget.dependencies.sessionController.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: EmptyStateView(
          title: 'Oturum Bulunamadi',
          message: 'Lutfen tekrar giris yapin.',
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: LoadingStateView(message: 'Aidat verileri yukleniyor...'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aidat Durumu')),
        body: ErrorStateView(
          title: 'Hata',
          message: _errorMessage!,
          onRetry: _loadData,
        ),
      );
    }

    final bool canViewAll = widget.dependencies.authorizationService.can(
      user: currentUser,
      permission: AppPermission.viewAllPayments,
    );

    final List<String> periodKeys =
        _periods.map((DuesPeriodModel item) => item.periodKey).toList();
    final List<DuesInvoiceModel> filteredInvoices = _selectedPeriodKey == null
        ? _invoices
        : _invoices
            .where(
                (DuesInvoiceModel item) => item.periodKey == _selectedPeriodKey)
            .toList();

    final DuesSummaryModel summary =
        widget.dependencies.duesRepository.summarize(filteredInvoices);

    return Scaffold(
      appBar: AppBar(title: const Text('Aidat Durumu')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.payments),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Guncel Aidat Tutari: ${_currentAmount.toStringAsFixed(2)} TL',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (periodKeys.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedPeriodKey,
                decoration: const InputDecoration(labelText: 'Donem'),
                items: periodKeys.map((String period) {
                  return DropdownMenuItem<String>(
                    value: period,
                    child: Text(period),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedPeriodKey = value;
                  });
                },
              ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: <Widget>[
                    Text('Toplam Kayit: ${summary.totalCount}'),
                    Text('Odendi: ${summary.paidCount}'),
                    Text('Odenmedi: ${summary.unpaidCount}'),
                    Text('Gecikmis: ${summary.overdueCount}'),
                    Text(
                        'Toplam Tutar: ${summary.totalAmount.toStringAsFixed(2)} TL'),
                    Text(
                      'Bekleyen Borc: ${summary.outstandingAmount.toStringAsFixed(2)} TL',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredInvoices.isEmpty
                  ? const EmptyStateView(
                      title: 'Kayit Bulunamadi',
                      message: 'Secili donemde aidat kaydi bulunmuyor.',
                    )
                  : ListView.separated(
                      itemCount: filteredInvoices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        final DuesInvoiceModel invoice =
                            filteredInvoices[index];
                        final UserModel? owner = _usersById[invoice.userId];

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  owner?.name ?? 'Bilinmeyen Uye',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    'Tutar: ${invoice.amount.toStringAsFixed(2)} TL'),
                                Text('Donem: ${invoice.periodKey}'),
                                Text(
                                  'Son Odeme Tarihi: ${DateTimeFormatter.date(invoice.dueDate)}',
                                ),
                                if (invoice.paidAt != null)
                                  Text(
                                    'Odeme Tarihi: ${DateTimeFormatter.date(invoice.paidAt!)}',
                                  ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(invoice.status)
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    invoice.status.label,
                                    style: TextStyle(
                                      color: _statusColor(invoice.status),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (!canViewAll &&
                                    invoice.userId == currentUser.id &&
                                    invoice.status != DuesInvoiceStatus.paid)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: ElevatedButton.icon(
                                      onPressed: _isCheckoutWorking
                                          ? null
                                          : () => _startCheckout(invoice),
                                      icon: const Icon(Icons.open_in_browser),
                                      label: const Text('Odeme Baslat'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(DuesInvoiceStatus status) {
    switch (status) {
      case DuesInvoiceStatus.paid:
        return Colors.green.shade700;
      case DuesInvoiceStatus.unpaid:
        return Colors.orange.shade800;
      case DuesInvoiceStatus.overdue:
        return Colors.red.shade700;
    }
  }

  Future<void> _startCheckout(DuesInvoiceModel invoice) async {
    setState(() {
      _isCheckoutWorking = true;
    });
    try {
      final result = await widget.dependencies.paymentGatewayRepository
          .startCheckout(invoiceId: invoice.id);

      if (!mounted) {
        return;
      }

      final String? checkoutUrl = result.checkoutUrl?.trim();
      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        final Uri uri = Uri.parse(checkoutUrl);
        final bool launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Odeme sayfasi acilamadi.'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.instructions?.trim().isNotEmpty == true
                  ? result.instructions!
                  : 'Odeme istegi olusturuldu. Yonetici onayi bekleniyor.',
            ),
          ),
        );
      }
      await _loadData();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Odeme baslatilamadi. Lutfen tekrar deneyin.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckoutWorking = false;
        });
      }
    }
  }
}
