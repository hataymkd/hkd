import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hkd/core/authorization/app_permission.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/navigation/app_routes.dart';
import 'package:hkd/core/utils/date_time_formatter.dart';
import 'package:hkd/core/widgets/error_state_view.dart';
import 'package:hkd/core/widgets/loading_state_view.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/auth/domain/models/user_role.dart';
import 'package:hkd/features/dues/domain/models/dues_invoice_model.dart';
import 'package:hkd/features/dues/domain/models/dues_summary_model.dart';
import 'package:hkd/features/membership/domain/models/membership_application_model.dart';
import 'package:hkd/features/membership/domain/models/membership_review_result_model.dart';
import 'package:hkd/features/notifications/domain/models/app_notification_model.dart';
import 'package:hkd/features/payments/domain/models/admin_payment_review_model.dart';

class ManagementPanelPage extends StatefulWidget {
  const ManagementPanelPage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<ManagementPanelPage> createState() => _ManagementPanelPageState();
}

class _ManagementPanelPageState extends State<ManagementPanelPage> {
  static const String _cancelApprovalToken = '__cancel_approval__';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _duesController = TextEditingController();
  final Set<String> _selectedApplicationIds = <String>{};

  bool _isLoading = false;
  bool _isWorking = false;
  String? _errorMessage;
  String? _selectedMemberId;

  List<UserModel> _users = <UserModel>[];
  List<UserModel> _pendingUsers = <UserModel>[];
  List<MembershipApplicationModel> _pendingApplications =
      <MembershipApplicationModel>[];
  List<MembershipApplicationModel> _historyApplications =
      <MembershipApplicationModel>[];
  List<AdminPaymentReviewModel> _paymentReviewQueue =
      <AdminPaymentReviewModel>[];
  List<PaymentReconciliationLogModel> _paymentLogs =
      <PaymentReconciliationLogModel>[];
  DuesSummaryModel _summary = const DuesSummaryModel(
    totalCount: 0,
    paidCount: 0,
    unpaidCount: 0,
    overdueCount: 0,
    totalAmount: 0,
    outstandingAmount: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadPanelData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _duesController.dispose();
    super.dispose();
  }

  Future<void> _loadPanelData() async {
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
      final List<UserModel> users =
          await widget.dependencies.authRepository.fetchUsers();
      final List<UserModel> pendingUsers =
          await widget.dependencies.authRepository.fetchPendingUsers();
      final List<MembershipApplicationModel> pendingApplications =
          await widget.dependencies.membershipRepository.list(
        status: MembershipApplicationStatus.pending,
      );
      final List<MembershipApplicationModel> allApplications =
          await widget.dependencies.membershipRepository.list();
      final List<MembershipApplicationModel> history = allApplications
          .where(
            (MembershipApplicationModel item) =>
                item.status != MembershipApplicationStatus.pending,
          )
          .toList();

      final List<DuesInvoiceModel> allInvoices =
          await widget.dependencies.duesRepository.fetchInvoices();
      final DuesSummaryModel summary =
          widget.dependencies.duesRepository.summarize(allInvoices);
      final double currentAmount =
          await widget.dependencies.duesRepository.fetchCurrentAmount();
      final bool canViewAllPayments =
          widget.dependencies.authorizationService.can(
        user: currentUser,
        permission: AppPermission.viewAllPayments,
      );
      List<AdminPaymentReviewModel> paymentReviewQueue =
          const <AdminPaymentReviewModel>[];
      List<PaymentReconciliationLogModel> paymentLogs =
          const <PaymentReconciliationLogModel>[];
      if (canViewAllPayments) {
        paymentReviewQueue = await widget.dependencies.paymentGatewayRepository
            .fetchReviewQueue(limit: 20);
        paymentLogs = await widget.dependencies.paymentGatewayRepository
            .fetchReconciliationLogs(limit: 20);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _users = users;
        _pendingUsers = pendingUsers;
        _pendingApplications = pendingApplications;
        _historyApplications = history;
        _paymentReviewQueue = paymentReviewQueue;
        _paymentLogs = paymentLogs;
        _summary = summary;
        _duesController.text =
            currentAmount == 0 ? '' : currentAmount.toStringAsFixed(2);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Yonetim verileri yuklenemedi.';
      });
    }
  }

  Future<void> _saveDuesAmount() async {
    final double? amount = double.tryParse(
      _duesController.text.replaceAll(',', '.').trim(),
    );
    if (amount == null || amount <= 0) {
      _showMessage('Gecerli bir aidat tutari giriniz.');
      return;
    }

    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.duesRepository.setCurrentAmount(amount);
      await _loadPanelData();
      _showMessage('Aidat tutari guncellendi.');
    } catch (error) {
      _showMessage('Aidat tutari guncellenemedi.');
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _assignManager(String? memberId) async {
    if (memberId == null) {
      _showMessage('Yonetici atanacak uye seciniz.');
      return;
    }
    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.authRepository.assignManager(memberId);
      await _loadPanelData();
      _showMessage('Yonetici atamasi tamamlandi.');
    } catch (_) {
      _showMessage('Yonetici atamasi basarisiz.');
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _approvePendingUser(String userId) async {
    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.authRepository.reviewUserActivation(
        userId: userId,
        approve: true,
      );
      await _loadPanelData();
      _showMessage('Kullanici onaylandi.');
    } catch (_) {
      _showMessage('Kullanici onaylanamadi.');
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _rejectPendingUser(String userId) async {
    final TextEditingController reasonController = TextEditingController();
    final bool? shouldReject = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kullaniciyi Reddet'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Red nedeni'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgec'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reddet'),
            ),
          ],
        );
      },
    );

    if (shouldReject != true) {
      reasonController.dispose();
      return;
    }

    final String reason = reasonController.text.trim();
    reasonController.dispose();

    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.authRepository.reviewUserActivation(
        userId: userId,
        approve: false,
        reason: reason.isEmpty ? null : reason,
      );
      await _loadPanelData();
      _showMessage('Kullanici reddedildi.');
    } catch (_) {
      _showMessage('Kullanici reddedilemedi.');
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _approveApplication(String applicationId) async {
    final String? tempPassword = await _promptTempPassword();
    if (tempPassword == _cancelApprovalToken) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _isWorking = true;
    });

    try {
      final MembershipReviewResultModel result =
          await widget.dependencies.membershipRepository.review(
        applicationId: applicationId,
        approve: true,
        tempPassword: tempPassword == null || tempPassword.trim().isEmpty
            ? null
            : tempPassword.trim(),
      );
      if (result.userId != null) {
        await widget.dependencies.duesRepository.ensureUserInvoicePlan(
          result.userId!,
        );
      }
      _selectedApplicationIds.remove(applicationId);
      await _loadPanelData();
      if (!mounted) {
        return;
      }
      await _showPasswordResultIfNeeded(result.tempPassword);
      _showMessage('Basvuru onaylandi.');
    } catch (_) {
      _showMessage('Basvuru onaylanamadi.');
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _rejectApplication(String applicationId) async {
    final TextEditingController reasonController = TextEditingController();
    final bool? shouldReject = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Basvuruyu Reddet'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Red nedeni'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgec'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reddet'),
            ),
          ],
        );
      },
    );

    if (shouldReject != true) {
      reasonController.dispose();
      return;
    }

    final String reason = reasonController.text.trim();
    reasonController.dispose();
    if (reason.isEmpty) {
      _showMessage('Red nedeni zorunludur.');
      return;
    }

    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.membershipRepository.review(
        applicationId: applicationId,
        approve: false,
        rejectReason: reason,
      );
      _selectedApplicationIds.remove(applicationId);
      await _loadPanelData();
      _showMessage('Basvuru reddedildi.');
    } catch (_) {
      _showMessage('Basvuru reddedilemedi.');
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _approveSelectedApplications() async {
    if (_selectedApplicationIds.isEmpty) {
      _showMessage('Toplu onay icin en az bir basvuru seciniz.');
      return;
    }
    final List<String> selected = List<String>.from(_selectedApplicationIds);
    for (final String id in selected) {
      await _approveApplication(id);
    }
  }

  Future<String?> _promptTempPassword() async {
    final TextEditingController passwordController = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Onay Sifresi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Bos birakirsaniz sistem guclu gecici sifre uretir.',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Gecici Sifre (Opsiyonel)',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(_cancelApprovalToken),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(passwordController.text),
              child: const Text('Devam'),
            ),
          ],
        );
      },
    );
    passwordController.dispose();
    return value;
  }

  Future<void> _showPasswordResultIfNeeded(String? tempPassword) async {
    if (tempPassword == null || tempPassword.trim().isEmpty) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Gecici Sifre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Sistem bu basvuru icin gecici sifre olusturdu:'),
              const SizedBox(height: 10),
              SelectableText(
                tempPassword,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
            ElevatedButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: tempPassword));
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
              },
              child: const Text('Kopyala'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendAdminNotification() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController bodyController = TextEditingController();
    AppNotificationCategory selectedCategory = AppNotificationCategory.general;

    final bool? shouldSend = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Bildirim Gonder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Baslik',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bodyController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Icerik',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<AppNotificationCategory>(
                      initialValue: selectedCategory,
                      items: AppNotificationCategory.values
                          .map((AppNotificationCategory item) {
                        return DropdownMenuItem<AppNotificationCategory>(
                          value: item,
                          child: Text(item.label),
                        );
                      }).toList(),
                      onChanged: (AppNotificationCategory? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedCategory = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Vazgec'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Gonder'),
                ),
              ],
            );
          },
        );
      },
    );

    final String title = titleController.text.trim();
    final String body = bodyController.text.trim();
    titleController.dispose();
    bodyController.dispose();

    if (shouldSend != true) {
      return;
    }
    if (title.isEmpty || body.isEmpty) {
      _showMessage('Baslik ve icerik zorunludur.');
      return;
    }

    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.notificationRepository.sendNotification(
        title: title,
        body: body,
        category: selectedCategory,
      );
      _showMessage('Bildirim gonderildi.');
    } catch (_) {
      _showMessage('Bildirim gonderilemedi.');
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _reviewPayment({
    required AdminPaymentReviewModel payment,
    required String status,
  }) async {
    final TextEditingController providerRefController =
        TextEditingController(text: payment.providerRef ?? '');
    final TextEditingController reasonController = TextEditingController();

    final bool? shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Odeme Durumu: $status'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: providerRefController,
                  decoration: const InputDecoration(
                    labelText: 'Provider Ref (opsiyonel)',
                  ),
                ),
                TextField(
                  controller: reasonController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Not/Neden (opsiyonel)',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgec'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guncelle'),
            ),
          ],
        );
      },
    );

    final String providerRef = providerRefController.text.trim();
    final String reason = reasonController.text.trim();
    providerRefController.dispose();
    reasonController.dispose();

    if (shouldSubmit != true) {
      return;
    }

    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.paymentGatewayRepository.confirmPayment(
        paymentId: payment.paymentId,
        status: status,
        providerRef: providerRef.isEmpty ? null : providerRef,
        reason: reason.isEmpty ? null : reason,
      );
      await _loadPanelData();
      _showMessage('Odeme durumu guncellendi.');
    } catch (_) {
      _showMessage('Odeme durumu guncellenemedi.');
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserModel? currentUser =
        widget.dependencies.sessionController.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: ErrorStateView(
          title: 'Oturum Bulunamadi',
          message: 'Lutfen tekrar giris yapin.',
        ),
      );
    }

    if (!widget.dependencies.authorizationService.can(
      user: currentUser,
      permission: AppPermission.openManagementPanel,
    )) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yonetim Paneli')),
        body: const Center(
          child: Text('Bu alana erisim yetkiniz yok.'),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: LoadingStateView(message: 'Yonetim verileri yukleniyor...'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yonetim Paneli')),
        body: ErrorStateView(
          title: 'Hata',
          message: _errorMessage!,
          onRetry: _loadPanelData,
        ),
      );
    }

    final String searchQuery = _searchController.text.trim().toLowerCase();
    final List<UserModel> membersOnly = _users
        .where(
          (UserModel item) => item.role == UserRole.member && item.isActive,
        )
        .toList();
    final List<UserModel> filteredUsers = _users.where((UserModel item) {
      final String payload =
          '${item.name.toLowerCase()} ${item.phone.toLowerCase()}';
      return payload.contains(searchQuery);
    }).toList();
    final List<UserModel> filteredPendingUsers =
        _pendingUsers.where((UserModel item) {
      final String payload =
          '${item.name.toLowerCase()} ${item.phone.toLowerCase()}';
      return payload.contains(searchQuery);
    }).toList();
    final List<MembershipApplicationModel> filteredPendingApplications =
        _pendingApplications.where((MembershipApplicationModel application) {
      final String payload =
          '${application.name.toLowerCase()} ${application.phone.toLowerCase()}';
      return payload.contains(searchQuery);
    }).toList();

    final String? selectedMemberId = membersOnly.any(
      (UserModel user) => user.id == _selectedMemberId,
    )
        ? _selectedMemberId
        : membersOnly.isNotEmpty
            ? membersOnly.first.id
            : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Yonetim Paneli')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CapabilityCard(
              currentUser: currentUser,
              dependencies: widget.dependencies,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Detayli KPI ve sistem metrikleri icin rapor ekranini acin.',
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.adminReports);
                      },
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('Raporlar'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.dependencies.authorizationService.can(
              user: currentUser,
              permission: AppPermission.viewAllPayments,
            )) ...<Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Odeme Operasyonlari',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (_paymentReviewQueue.isEmpty)
                        const Text('Islem bekleyen odeme kaydi yok.')
                      else
                        ..._paymentReviewQueue
                            .map((AdminPaymentReviewModel item) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.userName,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tutar: ${item.amount.toStringAsFixed(2)} TL',
                                  ),
                                  Text(
                                    'Durum: ${item.status} | Donem: ${item.periodKey ?? '-'}',
                                  ),
                                  Text(
                                    'Olusturma: ${DateTimeFormatter.dateTime(item.createdAt)}',
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: <Widget>[
                                      if (item.status != 'succeeded')
                                        ElevatedButton(
                                          onPressed: _isWorking
                                              ? null
                                              : () => _reviewPayment(
                                                    payment: item,
                                                    status: 'succeeded',
                                                  ),
                                          child: const Text('Basarili'),
                                        ),
                                      if (item.status != 'failed')
                                        OutlinedButton(
                                          onPressed: _isWorking
                                              ? null
                                              : () => _reviewPayment(
                                                    payment: item,
                                                    status: 'failed',
                                                  ),
                                          child: const Text('Basarisiz'),
                                        ),
                                      if (item.status != 'refunded')
                                        OutlinedButton(
                                          onPressed: _isWorking
                                              ? null
                                              : () => _reviewPayment(
                                                    payment: item,
                                                    status: 'refunded',
                                                  ),
                                          child: const Text('Iade'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                      Text(
                        'Son Mutabakat Kayitlari',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (_paymentLogs.isEmpty)
                        const Text('Mutabakat kaydi bulunmuyor.')
                      else
                        ..._paymentLogs.take(8).map(
                          (PaymentReconciliationLogModel item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${DateTimeFormatter.dateTime(item.createdAt)} '
                                '- ${item.previousStatus ?? '-'} -> ${item.nextStatus}'
                                '${(item.reason ?? '').trim().isEmpty ? '' : ' (${item.reason})'}',
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Aktif uyelere sistem bildirimi gonderin.',
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isWorking ? null : _sendAdminNotification,
                      icon: const Icon(Icons.send),
                      label: const Text('Bildirim Gonder'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Uye/Basvuru Ara',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.dependencies.authorizationService.can(
              user: currentUser,
              permission: AppPermission.setDueAmount,
            )) ...<Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Aidat Tutari Belirle',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _duesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Aylik aidat tutari (TL)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _isWorking ? null : _saveDuesAmount,
                        child: const Text('Guncelle'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.dependencies.authorizationService.can(
              user: currentUser,
              permission: AppPermission.approveMembers,
            )) ...<Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Bekleyen Kullanici Onayi',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (filteredPendingUsers.isEmpty)
                        const Text('Filtreye uygun bekleyen kullanici yok.')
                      else
                        ...filteredPendingUsers.map((UserModel user) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(user.name),
                                  const SizedBox(height: 4),
                                  Text(user.phone),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: <Widget>[
                                      ElevatedButton(
                                        onPressed: _isWorking
                                            ? null
                                            : () =>
                                                _approvePendingUser(user.id),
                                        child: const Text('Onayla'),
                                      ),
                                      OutlinedButton(
                                        onPressed: _isWorking
                                            ? null
                                            : () => _rejectPendingUser(user.id),
                                        child: const Text('Reddet'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Basvuru Onay/Red',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (filteredPendingApplications.isEmpty)
                        const Text('Filtreye uygun bekleyen basvuru yok.')
                      else ...<Widget>[
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: _isWorking
                                ? null
                                : _approveSelectedApplications,
                            child: Text(
                              'Secilenleri Onayla (${_selectedApplicationIds.length})',
                            ),
                          ),
                        ),
                        ...filteredPendingApplications.map(
                          (MembershipApplicationModel application) {
                            final bool selected = _selectedApplicationIds
                                .contains(application.id);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      value: selected,
                                      onChanged: _isWorking
                                          ? null
                                          : (bool? value) {
                                              setState(() {
                                                if (value == true) {
                                                  _selectedApplicationIds.add(
                                                    application.id,
                                                  );
                                                } else {
                                                  _selectedApplicationIds
                                                      .remove(application.id);
                                                }
                                              });
                                            },
                                      title: Text(application.name),
                                      subtitle: Text(application.phone),
                                    ),
                                    Wrap(
                                      spacing: 8,
                                      children: <Widget>[
                                        ElevatedButton(
                                          onPressed: _isWorking
                                              ? null
                                              : () => _approveApplication(
                                                    application.id,
                                                  ),
                                          child: const Text('Onayla'),
                                        ),
                                        OutlinedButton(
                                          onPressed: _isWorking
                                              ? null
                                              : () => _rejectApplication(
                                                    application.id,
                                                  ),
                                          child: const Text('Reddet'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.dependencies.authorizationService.can(
              user: currentUser,
              permission: AppPermission.assignManager,
            )) ...<Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Yonetici Ata',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedMemberId,
                        items: membersOnly.map((UserModel user) {
                          return DropdownMenuItem<String>(
                            value: user.id,
                            child: Text('${user.name} (${user.phone})'),
                          );
                        }).toList(),
                        onChanged: membersOnly.isEmpty
                            ? null
                            : (String? value) {
                                setState(() {
                                  _selectedMemberId = value;
                                });
                              },
                        decoration: const InputDecoration(
                          labelText: 'Uye seciniz',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: membersOnly.isEmpty || _isWorking
                            ? null
                            : () => _assignManager(selectedMemberId),
                        child: const Text('Yonetici Olarak Ata'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Uyeler',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (filteredUsers.isEmpty)
                      const Text('Filtreye uygun uye bulunamadi.')
                    else
                      ...filteredUsers.map((UserModel user) {
                        final String activityLabel =
                            user.isActive ? 'Aktif' : 'Onay Bekliyor';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${user.name} - ${user.role.label} - $activityLabel',
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Aidat Ozeti',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    Text('Toplam Kayit: ${_summary.totalCount}'),
                    Text('Odendi: ${_summary.paidCount}'),
                    Text('Odenmedi: ${_summary.unpaidCount}'),
                    Text('Gecikmis: ${_summary.overdueCount}'),
                    Text(
                      'Toplam Tutar: ${_summary.totalAmount.toStringAsFixed(2)} TL',
                    ),
                    Text(
                      'Bekleyen Borc: ${_summary.outstandingAmount.toStringAsFixed(2)} TL',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Basvuru Gecmisi',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_historyApplications.isEmpty)
                      const Text('Basvuru gecmisi bulunmuyor.')
                    else
                      ..._historyApplications.take(8).map(
                        (MembershipApplicationModel application) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${application.name} - ${application.status.label}'
                              ' (${application.decidedBy ?? 'Sistem'})',
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.currentUser,
    required this.dependencies,
  });

  final UserModel currentUser;
  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final List<String> capabilities = <String>[
      if (dependencies.authorizationService.can(
        user: currentUser,
        permission: AppPermission.addAnnouncement,
      ))
        'Duyuru ekleme',
      if (dependencies.authorizationService.can(
        user: currentUser,
        permission: AppPermission.viewMembers,
      ))
        'Uyeleri goruntuleme',
      if (dependencies.authorizationService.can(
        user: currentUser,
        permission: AppPermission.viewAllPayments,
      ))
        'Aidat durumlarini goruntuleme',
      if (dependencies.authorizationService.can(
        user: currentUser,
        permission: AppPermission.approveMembers,
      ))
        'Uye onaylama',
      if (dependencies.authorizationService.can(
        user: currentUser,
        permission: AppPermission.assignManager,
      ))
        'Yonetici atama',
      if (dependencies.authorizationService.can(
        user: currentUser,
        permission: AppPermission.setDueAmount,
      ))
        'Aidat tutari belirleme',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Yetki Ozeti (${currentUser.role.label})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (capabilities.isEmpty)
              const Text('Bu rol icin tanimli yetki yok.')
            else
              ...capabilities.map(
                (String capability) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('- $capability'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
