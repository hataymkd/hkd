import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkd/core/authorization/authorization_service.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/navigation/app_router.dart';
import 'package:hkd/core/navigation/app_routes.dart';
import 'package:hkd/core/session/session_controller.dart';
import 'package:hkd/core/session/session_storage.dart';
import 'package:hkd/features/announcements/domain/models/announcement_model.dart';
import 'package:hkd/features/announcements/domain/repositories/announcement_repository.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/auth/domain/models/user_role.dart';
import 'package:hkd/features/auth/domain/repositories/auth_repository.dart';
import 'package:hkd/features/dues/domain/models/dues_invoice_model.dart';
import 'package:hkd/features/dues/domain/models/dues_period_model.dart';
import 'package:hkd/features/dues/domain/models/dues_summary_model.dart';
import 'package:hkd/features/dues/domain/repositories/dues_repository.dart';
import 'package:hkd/features/events/domain/models/community_event_model.dart';
import 'package:hkd/features/events/domain/repositories/event_repository.dart';
import 'package:hkd/features/invites/domain/models/invite_accept_result_model.dart';
import 'package:hkd/features/invites/domain/repositories/invite_repository.dart';
import 'package:hkd/features/jobs/domain/models/courier_profile_model.dart';
import 'package:hkd/features/jobs/domain/models/job_application_model.dart';
import 'package:hkd/features/jobs/domain/models/job_post_model.dart';
import 'package:hkd/features/jobs/domain/repositories/job_repository.dart';
import 'package:hkd/features/membership/domain/models/membership_application_model.dart';
import 'package:hkd/features/membership/domain/models/membership_review_result_model.dart';
import 'package:hkd/features/membership/domain/repositories/membership_repository.dart';
import 'package:hkd/features/notifications/domain/models/app_notification_model.dart';
import 'package:hkd/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hkd/features/organizations/domain/models/organization_invite_model.dart';
import 'package:hkd/features/organizations/domain/models/organization_member_model.dart';
import 'package:hkd/features/organizations/domain/models/organization_model.dart';
import 'package:hkd/features/organizations/domain/repositories/organization_repository.dart';
import 'package:hkd/features/payments/domain/models/payment_checkout_result_model.dart';
import 'package:hkd/features/payments/domain/models/admin_payment_review_model.dart';
import 'package:hkd/features/payments/domain/repositories/payment_gateway_repository.dart';
import 'package:hkd/features/reports/domain/models/admin_report_snapshot_model.dart';
import 'package:hkd/features/reports/domain/repositories/report_repository.dart';
import 'package:hkd/features/support/domain/models/safety_incident_model.dart';
import 'package:hkd/features/support/domain/models/support_ticket_message_model.dart';
import 'package:hkd/features/support/domain/models/support_ticket_model.dart';
import 'package:hkd/features/support/domain/repositories/support_repository.dart';

void main() {
  group('App smoke navigation', () {
    testWidgets('authenticated routes open without crash',
        (WidgetTester tester) async {
      final _Harness harness = await _Harness.create(
        currentUser: _Users.president,
      );

      final GlobalKey<NavigatorState> navigatorKey =
          GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          initialRoute: AppRoutes.home,
          onGenerateRoute:
              AppRouter(dependencies: harness.dependencies).onGenerateRoute,
        ),
      );
      await tester.pumpAndSettle();

      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.home,
        expectedFinder: find.text('HAMOKDER Ana Sayfa'),
      );

      final AnnouncementModel detailItem =
          harness.announcementRepository.items.first;

      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.announcements,
        expectedFinder: find.text('Duyurular'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.events,
        expectedFinder: find.text('Etkinlikler'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.announcementDetail,
        arguments: detailItem,
        expectedFinder: find.text(detailItem.title),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.profile,
        expectedFinder: find.text('Profil'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.paymentStatus,
        expectedFinder: find.text('Aidat Durumu'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.notifications,
        expectedFinder: find.text('Bildirimler'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.supportCenter,
        expectedFinder: find.text('Destek Merkezi'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.jobsMarketplace,
        expectedFinder: find.text('Is Pazari'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.organizationPanel,
        expectedFinder: find.text('Organizasyon Paneli'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.management,
        expectedFinder: find.text('Yonetim Paneli'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.adminReports,
        expectedFinder: find.text('Raporlar'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.membershipApplication,
        expectedFinder: find.text('Yeni Uye Basvurusu'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.membershipStatus,
        expectedFinder: find.text('Basvuru Durumu'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.acceptInvite,
        expectedFinder: find.text('Davet Kabul Et'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.pendingApproval,
        expectedFinder: find.text('Onay Bekleniyor'),
      );
      await _openAndAssert(
        tester: tester,
        navigatorKey: navigatorKey,
        routeName: AppRoutes.login,
        expectedFinder: find.text('Giris Yap'),
      );

      await _drainPendingTimers(tester);
    });

    testWidgets('inactive user is guarded to pending approval',
        (WidgetTester tester) async {
      final _Harness harness = await _Harness.create(
        currentUser: _Users.inactiveMember,
      );

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: AppRoutes.home,
          onGenerateRoute:
              AppRouter(dependencies: harness.dependencies).onGenerateRoute,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Onay Bekleniyor'), findsOneWidget);
      expect(find.text('Cikis Yap'), findsOneWidget);

      await _drainPendingTimers(tester);
    });
  });
}

Future<void> _drainPendingTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Future<void> _openAndAssert({
  required WidgetTester tester,
  required GlobalKey<NavigatorState> navigatorKey,
  required String routeName,
  Object? arguments,
  required Finder expectedFinder,
}) async {
  navigatorKey.currentState!.pushNamed(routeName, arguments: arguments);
  await tester.pumpAndSettle();
  expect(expectedFinder, findsOneWidget);
  navigatorKey.currentState!.pop();
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness({
    required this.dependencies,
    required this.announcementRepository,
  });

  final AppDependencies dependencies;
  final _FakeAnnouncementRepository announcementRepository;

  static Future<_Harness> create({
    required UserModel currentUser,
  }) async {
    final _FakeAuthRepository authRepository = _FakeAuthRepository(
      users: <UserModel>[
        _Users.president,
        _Users.manager,
        _Users.member,
        _Users.inactiveMember,
      ],
      passwordsByPhone: <String, String>{
        _Users.president.phone: '12345678',
      },
    );
    final _FakeAnnouncementRepository announcementRepository =
        _FakeAnnouncementRepository();
    final _FakeMembershipRepository membershipRepository =
        _FakeMembershipRepository();
    final _FakeDuesRepository duesRepository = _FakeDuesRepository();
    final _FakeEventRepository eventRepository = _FakeEventRepository();
    final _FakeSupportRepository supportRepository = _FakeSupportRepository();
    final _FakeInviteRepository inviteRepository = _FakeInviteRepository();
    final _FakeJobRepository jobRepository = _FakeJobRepository();
    final _FakeOrganizationRepository organizationRepository =
        _FakeOrganizationRepository();
    final _FakeNotificationRepository notificationRepository =
        _FakeNotificationRepository();
    final _FakePaymentGatewayRepository paymentGatewayRepository =
        _FakePaymentGatewayRepository();
    final _FakeReportRepository reportRepository = _FakeReportRepository();
    final SessionController sessionController = SessionController(
      storage: _InMemorySessionStorage(),
      authRepository: authRepository,
    );
    await sessionController.login(currentUser);

    final AppDependencies dependencies = AppDependencies(
      authRepository: authRepository,
      announcementRepository: announcementRepository,
      membershipRepository: membershipRepository,
      duesRepository: duesRepository,
      eventRepository: eventRepository,
      supportRepository: supportRepository,
      inviteRepository: inviteRepository,
      jobRepository: jobRepository,
      organizationRepository: organizationRepository,
      notificationRepository: notificationRepository,
      paymentGatewayRepository: paymentGatewayRepository,
      reportRepository: reportRepository,
      authorizationService: const AuthorizationService(),
      sessionController: sessionController,
    );

    return _Harness(
      dependencies: dependencies,
      announcementRepository: announcementRepository,
    );
  }
}

class _InMemorySessionStorage implements SessionStorage {
  String? _userId;

  @override
  Future<void> clear() async {
    _userId = null;
  }

  @override
  Future<String?> readUserId() async => _userId;

  @override
  Future<void> writeUserId(String userId) async {
    _userId = userId;
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    required List<UserModel> users,
    required Map<String, String> passwordsByPhone,
  })  : _users = List<UserModel>.from(users),
        _passwordsByPhone = Map<String, String>.from(passwordsByPhone);

  final List<UserModel> _users;
  final Map<String, String> _passwordsByPhone;
  final Map<String, String> _otpByPhone = <String, String>{};
  final List<MembershipApplicationModel> _applications =
      <MembershipApplicationModel>[
    MembershipApplicationModel(
      id: 'app-1',
      name: 'Yeni Basvuru',
      phone: '05001112233',
      createdAt: DateTime(2026, 1, 10),
      status: MembershipApplicationStatus.pending,
      memberType: MembershipMemberType.courier,
    ),
  ];

  @override
  Future<List<UserModel>> fetchActiveUsers() async {
    return getActiveUsers();
  }

  @override
  Future<UserModel?> fetchById(String userId) async {
    return getById(userId);
  }

  @override
  Future<MembershipApplicationModel?> fetchLatestMembershipApplicationByPhone(
    String phone,
  ) async {
    return getLatestMembershipApplicationByPhone(phone);
  }

  @override
  Future<List<MembershipApplicationModel>> fetchMembershipApplications({
    MembershipApplicationStatus? status,
  }) async {
    return getMembershipApplications(status: status);
  }

  @override
  Future<List<UserModel>> fetchPendingUsers() async {
    return getPendingUsers();
  }

  @override
  Future<List<String>> fetchUserRoleKeys(String userId) async {
    final UserModel? user = getById(userId);
    if (user == null) {
      return <String>['member'];
    }
    switch (user.role) {
      case UserRole.president:
        return <String>['president', 'member'];
      case UserRole.manager:
        return <String>['admin', 'member'];
      case UserRole.member:
        return <String>['member'];
    }
  }

  @override
  Future<List<UserModel>> fetchUsers() async {
    return getUsers();
  }

  @override
  UserModel? getById(String userId) {
    for (final UserModel item in _users) {
      if (item.id == userId) {
        return item;
      }
    }
    return null;
  }

  @override
  List<UserModel> getActiveUsers() {
    return _users.where((UserModel item) => item.isActive).toList();
  }

  @override
  MembershipApplicationModel? getLatestMembershipApplicationByPhone(
    String phone,
  ) {
    for (final MembershipApplicationModel item in _applications.reversed) {
      if (item.phone == phone) {
        return item;
      }
    }
    return null;
  }

  @override
  List<MembershipApplicationModel> getMembershipApplications({
    MembershipApplicationStatus? status,
  }) {
    if (status == null) {
      return List<MembershipApplicationModel>.from(_applications);
    }
    return _applications
        .where((MembershipApplicationModel item) => item.status == status)
        .toList();
  }

  @override
  List<UserModel> getPendingUsers() {
    return _users.where((UserModel item) => !item.isActive).toList();
  }

  @override
  List<UserModel> getUsers() {
    return List<UserModel>.from(_users);
  }

  @override
  Future<void> approveMember(String userId) async {
    await reviewUserActivation(userId: userId, approve: true);
  }

  @override
  Future<void> approveMembershipApplication({
    required String applicationId,
    required String approvedBy,
  }) async {}

  @override
  Future<void> assignManager(String userId) async {
    final int index = _users.indexWhere((UserModel item) => item.id == userId);
    if (index == -1) {
      return;
    }
    _users[index] = _users[index].copyWith(role: UserRole.manager);
  }

  @override
  Future<void> claimInitialPresident() async {}

  @override
  Future<UserModel?> login({
    required String phone,
    required String password,
  }) async {
    final String? storedPassword = _passwordsByPhone[phone];
    if (storedPassword == null || storedPassword != password) {
      return null;
    }
    for (final UserModel user in _users) {
      if (user.phone == phone) {
        return user;
      }
    }
    return null;
  }

  @override
  Future<void> requestLoginOtp({
    required String phone,
  }) async {
    if (_users.every((UserModel item) => item.phone != phone)) {
      throw StateError('Telefon bulunamadi.');
    }
    _otpByPhone[phone] = '123456';
  }

  @override
  Future<UserModel?> verifyLoginOtp({
    required String phone,
    required String otpCode,
  }) async {
    final String? expected = _otpByPhone[phone];
    if (expected == null || expected != otpCode) {
      return null;
    }
    for (final UserModel user in _users) {
      if (user.phone == phone) {
        return user;
      }
    }
    return null;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> rejectMembershipApplication({
    required String applicationId,
    required String rejectedBy,
    required String reason,
  }) async {}

  @override
  Future<void> reviewUserActivation({
    required String userId,
    required bool approve,
    String? reason,
  }) async {
    final int index = _users.indexWhere((UserModel item) => item.id == userId);
    if (index == -1) {
      return;
    }
    _users[index] = _users[index].copyWith(isActive: approve);
  }

  @override
  Future<UserModel?> restoreSession() async {
    return null;
  }

  @override
  Future<void> submitMembershipApplication({
    required String name,
    required String phone,
    required String password,
  }) async {
    _applications.add(
      MembershipApplicationModel(
        id: 'app-${_applications.length + 1}',
        name: name,
        phone: phone,
        createdAt: DateTime.now(),
        status: MembershipApplicationStatus.pending,
        memberType: MembershipMemberType.courier,
      ),
    );
  }
}

class _FakeAnnouncementRepository implements AnnouncementRepository {
  final List<AnnouncementModel> items = <AnnouncementModel>[
    AnnouncementModel(
      id: 'ann-1',
      title: 'Dernek toplantisi',
      content: 'Aylik toplanti pazar gunu saat 20:00.',
      createdAt: DateTime(2026, 2, 20, 18, 0),
      createdBy: 'Baskan',
    ),
  ];

  @override
  Future<void> addAnnouncement({
    required String title,
    required String content,
    required String createdBy,
  }) async {
    items.add(
      AnnouncementModel(
        id: 'ann-${items.length + 1}',
        title: title,
        content: content,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      ),
    );
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    items.removeWhere((AnnouncementModel item) => item.id == id);
  }

  @override
  Future<AnnouncementModel?> fetchAnnouncementById(String id) async {
    for (final AnnouncementModel item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<AnnouncementModel>> fetchAnnouncementsAsync({
    bool publishedOnly = true,
  }) async {
    return fetchAnnouncements();
  }

  @override
  List<AnnouncementModel> fetchAnnouncements() {
    return List<AnnouncementModel>.from(items);
  }

  @override
  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String content,
  }) async {
    final int index =
        items.indexWhere((AnnouncementModel item) => item.id == id);
    if (index == -1) {
      return;
    }
    final AnnouncementModel current = items[index];
    items[index] = AnnouncementModel(
      id: current.id,
      title: title,
      content: content,
      createdAt: current.createdAt,
      createdBy: current.createdBy,
    );
  }
}

class _FakeMembershipRepository implements MembershipRepository {
  final List<MembershipApplicationModel> _items = <MembershipApplicationModel>[
    MembershipApplicationModel(
      id: 'membership-1',
      name: 'Ornek Uye',
      phone: '05001112233',
      createdAt: DateTime(2026, 2, 1),
      status: MembershipApplicationStatus.pending,
      memberType: MembershipMemberType.courier,
    ),
  ];

  @override
  Future<String> apply({
    required String fullName,
    required String phone,
    required String password,
    MembershipMemberType memberType = MembershipMemberType.courier,
    String? orgName,
    String? orgPhone,
    String? orgTaxNo,
  }) async {
    final String id = 'membership-${_items.length + 1}';
    _items.add(
      MembershipApplicationModel(
        id: id,
        name: fullName,
        phone: phone,
        createdAt: DateTime.now(),
        status: MembershipApplicationStatus.pending,
        memberType: memberType,
        orgName: orgName,
        orgPhone: orgPhone,
        orgTaxNo: orgTaxNo,
      ),
    );
    return id;
  }

  @override
  Future<MembershipApplicationModel?> getById(String applicationId) async {
    for (final MembershipApplicationModel item in _items) {
      if (item.id == applicationId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<MembershipApplicationModel>> list({
    MembershipApplicationStatus? status,
  }) async {
    if (status == null) {
      return List<MembershipApplicationModel>.from(_items);
    }
    return _items
        .where((MembershipApplicationModel item) => item.status == status)
        .toList();
  }

  @override
  Future<MembershipReviewResultModel> review({
    required String applicationId,
    required bool approve,
    String? rejectReason,
    String? tempPassword,
  }) async {
    return MembershipReviewResultModel(
      status: approve ? 'approved' : 'rejected',
      userId: approve ? _Users.member.id : null,
      tempPassword: tempPassword,
    );
  }
}

class _FakeDuesRepository implements DuesRepository {
  final List<DuesPeriodModel> _periods = <DuesPeriodModel>[
    DuesPeriodModel(
      id: 'period-1',
      year: 2026,
      month: 2,
      periodKey: '2026-02',
      amount: 250,
      dueDate: DateTime(2026, 2, 10),
      createdAt: DateTime(2026, 2, 1),
    ),
  ];

  final List<DuesInvoiceModel> _invoices = <DuesInvoiceModel>[
    DuesInvoiceModel(
      id: 'inv-1',
      userId: _UserFixtures.memberId,
      periodId: 'period-1',
      periodKey: '2026-02',
      amount: 250,
      status: DuesInvoiceStatus.unpaid,
      dueDate: DateTime(2026, 2, 10),
      createdAt: DateTime(2026, 2, 1),
    ),
  ];

  @override
  Future<void> ensureUserInvoicePlan(String userId) async {}

  @override
  Future<double> fetchCurrentAmount() async => 250;

  @override
  Future<List<DuesInvoiceModel>> fetchInvoices({
    String? userId,
    String? periodKey,
  }) async {
    Iterable<DuesInvoiceModel> values = _invoices;
    if (userId != null) {
      values = values.where((DuesInvoiceModel item) => item.userId == userId);
    }
    if (periodKey != null) {
      values =
          values.where((DuesInvoiceModel item) => item.periodKey == periodKey);
    }
    return values.toList();
  }

  @override
  Future<List<DuesPeriodModel>> fetchPeriods() async {
    return List<DuesPeriodModel>.from(_periods);
  }

  @override
  Future<void> setCurrentAmount(double amount) async {}

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
    final double totalAmount = invoices.fold<double>(
      0,
      (double total, DuesInvoiceModel item) => total + item.amount,
    );
    final double outstandingAmount = invoices
        .where(
          (DuesInvoiceModel item) =>
              item.status == DuesInvoiceStatus.unpaid ||
              item.status == DuesInvoiceStatus.overdue,
        )
        .fold<double>(
          0,
          (double total, DuesInvoiceModel item) => total + item.amount,
        );

    return DuesSummaryModel(
      totalCount: invoices.length,
      paidCount: paidCount,
      unpaidCount: unpaidCount,
      overdueCount: overdueCount,
      totalAmount: totalAmount,
      outstandingAmount: outstandingAmount,
    );
  }
}

class _FakeEventRepository implements EventRepository {
  @override
  Future<void> createEvent({
    required String title,
    required String description,
    String? location,
    required DateTime startsAt,
    DateTime? endsAt,
  }) async {}

  @override
  Future<List<CommunityEventModel>> fetchUpcomingEvents({
    bool includeDrafts = false,
  }) async {
    return <CommunityEventModel>[
      CommunityEventModel(
        id: 'event-1',
        title: 'Aylik Dernek Toplantisi',
        description: 'Tum uyeler davetlidir.',
        location: 'Hatay Merkez',
        startsAt: DateTime(2026, 3, 10, 20, 0),
        endsAt: DateTime(2026, 3, 10, 22, 0),
        status: CommunityEventStatus.published,
        createdBy: _UserFixtures.presidentId,
        createdAt: DateTime(2026, 3, 1, 9, 0),
        updatedAt: DateTime(2026, 3, 1, 9, 0),
        goingCount: 5,
        myRsvpStatus: EventRsvpStatus.interested,
      ),
    ];
  }

  @override
  Future<void> updateEventStatus({
    required String eventId,
    required CommunityEventStatus status,
  }) async {}

  @override
  Future<void> upsertMyRsvp({
    required String eventId,
    required EventRsvpStatus status,
    String? note,
  }) async {}
}

class _FakeSupportRepository implements SupportRepository {
  @override
  Future<void> addTicketMessage({
    required String ticketId,
    required String body,
    bool isInternal = false,
  }) async {}

  @override
  Future<List<SupportTicketMessageModel>> fetchTicketMessages({
    required String ticketId,
    int limit = 100,
  }) async {
    return <SupportTicketMessageModel>[
      SupportTicketMessageModel(
        id: 'msg-1',
        ticketId: ticketId,
        senderId: _UserFixtures.memberId,
        senderName: 'HKD Uye',
        body: 'Odeme hatasi aliyorum.',
        isInternal: false,
        createdAt: DateTime(2026, 3, 1, 11, 0),
      ),
    ];
  }

  @override
  Future<void> createIncident({
    required String title,
    required String details,
    SafetyIncidentSeverity severity = SafetyIncidentSeverity.high,
    String? contactPhone,
    String? organizationId,
    double? latitude,
    double? longitude,
  }) async {}

  @override
  Future<void> createTicket({
    required String title,
    required String description,
    SupportTicketCategory category = SupportTicketCategory.general,
    SupportTicketPriority priority = SupportTicketPriority.normal,
    String? organizationId,
  }) async {}

  @override
  Future<List<SafetyIncidentModel>> fetchIncidents({
    bool includeAll = false,
  }) async {
    return <SafetyIncidentModel>[
      SafetyIncidentModel(
        id: 'incident-1',
        reporterId: _UserFixtures.memberId,
        reporterName: 'HKD Uye',
        orgId: null,
        title: 'Acil Trafik Olayi',
        details: 'Kaza bildirimi acildi.',
        severity: SafetyIncidentSeverity.high,
        status: SafetyIncidentStatus.open,
        contactPhone: '05003334455',
        latitude: null,
        longitude: null,
        resolvedBy: null,
        resolvedAt: null,
        createdAt: DateTime(2026, 3, 1, 10, 0),
        updatedAt: DateTime(2026, 3, 1, 10, 0),
      ),
    ];
  }

  @override
  Future<List<SupportTicketModel>> fetchTickets({
    bool includeAll = false,
  }) async {
    return <SupportTicketModel>[
      SupportTicketModel(
        id: 'ticket-1',
        userId: _UserFixtures.memberId,
        userName: 'HKD Uye',
        orgId: null,
        title: 'Odeme Sorunu',
        description: 'Kart odemesi basarisiz oldu.',
        category: SupportTicketCategory.payment,
        priority: SupportTicketPriority.normal,
        status: SupportTicketStatus.open,
        assignedTo: null,
        resolutionNote: null,
        createdAt: DateTime(2026, 3, 1, 9, 30),
        updatedAt: DateTime(2026, 3, 1, 9, 30),
      ),
    ];
  }

  @override
  Future<void> updateIncidentStatus({
    required String incidentId,
    required SafetyIncidentStatus status,
  }) async {}

  @override
  Future<void> updateTicket({
    required String ticketId,
    required SupportTicketStatus status,
    String? resolutionNote,
    String? assignedTo,
  }) async {}
}

class _FakeInviteRepository implements InviteRepository {
  @override
  Future<InviteAcceptResultModel> acceptInvite({
    required String token,
    required String fullName,
    required String phone,
    required String password,
  }) async {
    return const InviteAcceptResultModel(
      ok: true,
      status: 'pending_approval',
      userId: 'invite-user-1',
    );
  }
}

class _FakeOrganizationRepository implements OrganizationRepository {
  final OrganizationModel _org = OrganizationModel(
    id: 'org-1',
    type: OrganizationType.business,
    name: 'HKD Isletme',
    phone: '05001112233',
    taxNo: '1234567890',
    createdBy: _UserFixtures.presidentId,
    createdAt: DateTime(2026, 1, 1),
    myRole: OrganizationRole.owner,
    myStatus: OrganizationMembershipStatus.active,
  );

  @override
  Future<void> cancelInvite({
    required String inviteId,
  }) async {}

  @override
  Future<OrganizationInviteModel> createInvite({
    required String organizationId,
    required String phone,
  }) async {
    return OrganizationInviteModel(
      id: 'invite-created',
      orgId: organizationId,
      phone: phone,
      token: 'token-created',
      status: 'pending',
      expiresAt: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now(),
      inviteUrl: 'hkd://invite?token=token-created',
    );
  }

  @override
  Future<List<OrganizationInviteModel>> fetchOrganizationInvites({
    required String organizationId,
  }) async {
    return <OrganizationInviteModel>[
      OrganizationInviteModel(
        id: 'invite-1',
        orgId: organizationId,
        phone: '05002223344',
        token: 'token-1',
        status: 'pending',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        inviteUrl: 'hkd://invite?token=token-1',
      ),
    ];
  }

  @override
  Future<List<OrganizationMemberModel>> fetchOrganizationMembers({
    required String organizationId,
  }) async {
    return <OrganizationMemberModel>[
      OrganizationMemberModel(
        userId: _UserFixtures.presidentId,
        fullName: 'HKD Baskan',
        phone: '05001112233',
        isActive: true,
        role: OrganizationRole.owner,
        status: OrganizationMembershipStatus.active,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<List<OrganizationModel>> fetchMyOrganizations() async {
    return <OrganizationModel>[_org];
  }

  @override
  Future<void> updateMemberRole({
    required String organizationId,
    required String userId,
    required OrganizationRole role,
  }) async {}

  @override
  Future<void> updateMemberStatus({
    required String organizationId,
    required String userId,
    required OrganizationMembershipStatus status,
  }) async {}
}

class _FakeJobRepository implements JobRepository {
  @override
  Future<void> applyToJob({
    required String jobId,
    String? note,
  }) async {}

  @override
  Future<void> createJob({
    String? organizationId,
    required String title,
    required String description,
    required String city,
    String? district,
    JobEmploymentType employmentType = JobEmploymentType.fullTime,
    JobVehicleType vehicleType = JobVehicleType.motorcycle,
    double? salaryMin,
    double? salaryMax,
    String? contactPhone,
    DateTime? expiresAt,
  }) async {}

  @override
  Future<JobPostModel?> fetchJobById(String jobId) async {
    return null;
  }

  @override
  Future<List<JobApplicationModel>> fetchMyApplications() async {
    return <JobApplicationModel>[];
  }

  @override
  Future<CourierProfileModel?> fetchMyCourierProfile() async {
    return null;
  }

  @override
  Future<List<JobPostModel>> fetchOpenJobs({
    String? query,
    String? city,
  }) async {
    return <JobPostModel>[
      JobPostModel(
        id: 'job-1',
        createdBy: _UserFixtures.presidentId,
        title: 'Acil Kurye Araniyor',
        description: 'Tam zamanli motosikletli kurye',
        city: 'Hatay',
        employmentType: JobEmploymentType.fullTime,
        vehicleType: JobVehicleType.motorcycle,
        currency: 'TRY',
        status: JobPostStatus.open,
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
        organizationName: 'HKD Isletme',
      ),
    ];
  }

  @override
  Future<List<CourierProfileModel>> searchCouriers({
    String? query,
    String? city,
    JobVehicleType? vehicleType,
  }) async {
    return <CourierProfileModel>[
      CourierProfileModel(
        userId: _UserFixtures.memberId,
        fullName: 'HKD Uye',
        phone: '05003334455',
        vehicleType: JobVehicleType.motorcycle,
        yearsExperience: 2,
        isAvailable: true,
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
        city: 'Hatay',
      ),
    ];
  }

  @override
  Future<void> updateJobStatus({
    required String jobId,
    required JobPostStatus status,
  }) async {}

  @override
  Future<void> upsertMyCourierProfile({
    String? headline,
    String? bio,
    String? city,
    String? district,
    required JobVehicleType vehicleType,
    required int yearsExperience,
    required bool isAvailable,
  }) async {}
}

class _FakeNotificationRepository implements NotificationRepository {
  final List<AppNotificationModel> _items = <AppNotificationModel>[
    AppNotificationModel(
      id: 'notif-1',
      userId: _UserFixtures.presidentId,
      title: 'Sistem Bildirimi',
      body: 'Test bildirimi',
      category: AppNotificationCategory.general,
      isRead: false,
      createdAt: DateTime(2026, 3, 1, 10, 0),
    ),
  ];

  @override
  Future<int> fetchUnreadCount() async {
    return _items.where((AppNotificationModel item) => !item.isRead).length;
  }

  @override
  Future<List<AppNotificationModel>> fetchMyNotifications({
    int limit = 50,
  }) async {
    return _items.take(limit).toList();
  }

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> markAsRead(String notificationId) async {}

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
  }) async {}

  @override
  Future<void> sendNotification({
    required String title,
    required String body,
    AppNotificationCategory category = AppNotificationCategory.general,
    String? userId,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {}
}

class _FakePaymentGatewayRepository implements PaymentGatewayRepository {
  @override
  Future<PaymentCheckoutResultModel> startCheckout({
    required String invoiceId,
  }) async {
    return const PaymentCheckoutResultModel(
      paymentId: 'pay-checkout-1',
      provider: 'manual',
      status: 'created',
      instructions: 'Test odeme',
    );
  }

  @override
  Future<void> confirmPayment({
    required String paymentId,
    required String status,
    String? providerRef,
    String? reason,
  }) async {}

  @override
  Future<List<PaymentReconciliationLogModel>> fetchReconciliationLogs({
    int limit = 30,
  }) async {
    return const <PaymentReconciliationLogModel>[];
  }

  @override
  Future<List<AdminPaymentReviewModel>> fetchReviewQueue({
    int limit = 30,
  }) async {
    return const <AdminPaymentReviewModel>[];
  }
}

class _FakeReportRepository implements ReportRepository {
  @override
  Future<AdminReportSnapshotModel> fetchAdminSnapshot() async {
    return AdminReportSnapshotModel(
      generatedAt: DateTime(2026, 3, 1, 12, 0),
      activeUsers: 10,
      pendingUsers: 2,
      totalOrganizations: 3,
      pendingApplications: 4,
      openJobs: 5,
      pendingInvoices: 6,
      overdueInvoices: 1,
      totalDueAmount: 10000,
      outstandingAmount: 2500,
      unreadNotifications: 7,
    );
  }
}

class _UserFixtures {
  static const String presidentId = 'user-president';
  static const String memberId = 'user-member';
}

class _Users {
  static final UserModel president = UserModel(
    id: _UserFixtures.presidentId,
    name: 'HKD Baskan',
    phone: '05001112233',
    role: UserRole.president,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  static final UserModel manager = UserModel(
    id: 'user-manager',
    name: 'HKD Yonetici',
    phone: '05002223344',
    role: UserRole.manager,
    isActive: true,
    createdAt: DateTime(2026, 1, 2),
  );

  static final UserModel member = UserModel(
    id: _UserFixtures.memberId,
    name: 'HKD Uye',
    phone: '05003334455',
    role: UserRole.member,
    isActive: true,
    createdAt: DateTime(2026, 1, 3),
  );

  static final UserModel inactiveMember = UserModel(
    id: 'user-inactive',
    name: 'HKD Bekleyen Uye',
    phone: '05004445566',
    role: UserRole.member,
    isActive: false,
    createdAt: DateTime(2026, 1, 4),
  );
}
