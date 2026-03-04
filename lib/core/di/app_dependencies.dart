import 'package:hkd/core/authorization/authorization_service.dart';
import 'package:hkd/core/session/session_controller.dart';
import 'package:hkd/core/session/session_storage.dart';
import 'package:hkd/core/session/shared_preferences_session_storage.dart';
import 'package:hkd/core/supabase_client.dart';
import 'package:hkd/features/announcements/data/supabase_announcement_repository.dart';
import 'package:hkd/features/announcements/domain/repositories/announcement_repository.dart';
import 'package:hkd/features/auth/data/supabase_auth_repository.dart';
import 'package:hkd/features/auth/domain/repositories/auth_repository.dart';
import 'package:hkd/features/dues/data/supabase_dues_repository.dart';
import 'package:hkd/features/dues/domain/repositories/dues_repository.dart';
import 'package:hkd/features/events/data/supabase_event_repository.dart';
import 'package:hkd/features/events/domain/repositories/event_repository.dart';
import 'package:hkd/features/invites/data/supabase_invite_repository.dart';
import 'package:hkd/features/invites/domain/repositories/invite_repository.dart';
import 'package:hkd/features/jobs/data/supabase_job_repository.dart';
import 'package:hkd/features/jobs/domain/repositories/job_repository.dart';
import 'package:hkd/features/membership/data/supabase_membership_repository.dart';
import 'package:hkd/features/membership/domain/repositories/membership_repository.dart';
import 'package:hkd/features/notifications/data/supabase_notification_repository.dart';
import 'package:hkd/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hkd/features/organizations/data/supabase_organization_repository.dart';
import 'package:hkd/features/organizations/domain/repositories/organization_repository.dart';
import 'package:hkd/features/payments/data/supabase_payment_gateway_repository.dart';
import 'package:hkd/features/payments/domain/repositories/payment_gateway_repository.dart';
import 'package:hkd/features/reports/data/supabase_report_repository.dart';
import 'package:hkd/features/reports/domain/repositories/report_repository.dart';
import 'package:hkd/features/support/data/supabase_support_repository.dart';
import 'package:hkd/features/support/domain/repositories/support_repository.dart';

class AppDependencies {
  factory AppDependencies({
    required AuthRepository authRepository,
    required AnnouncementRepository announcementRepository,
    required MembershipRepository membershipRepository,
    required DuesRepository duesRepository,
    required EventRepository eventRepository,
    required SupportRepository supportRepository,
    required InviteRepository inviteRepository,
    required JobRepository jobRepository,
    required OrganizationRepository organizationRepository,
    required NotificationRepository notificationRepository,
    required PaymentGatewayRepository paymentGatewayRepository,
    required ReportRepository reportRepository,
    required AuthorizationService authorizationService,
    required SessionController sessionController,
  }) {
    return AppDependencies._(
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
      authorizationService: authorizationService,
      sessionController: sessionController,
    );
  }

  AppDependencies._({
    required this.authRepository,
    required this.announcementRepository,
    required this.membershipRepository,
    required this.duesRepository,
    required this.eventRepository,
    required this.supportRepository,
    required this.inviteRepository,
    required this.jobRepository,
    required this.organizationRepository,
    required this.notificationRepository,
    required this.paymentGatewayRepository,
    required this.reportRepository,
    required this.authorizationService,
    required this.sessionController,
  });

  final AuthRepository authRepository;
  final AnnouncementRepository announcementRepository;
  final MembershipRepository membershipRepository;
  final DuesRepository duesRepository;
  final EventRepository eventRepository;
  final SupportRepository supportRepository;
  final InviteRepository inviteRepository;
  final JobRepository jobRepository;
  final OrganizationRepository organizationRepository;
  final NotificationRepository notificationRepository;
  final PaymentGatewayRepository paymentGatewayRepository;
  final ReportRepository reportRepository;
  final AuthorizationService authorizationService;
  final SessionController sessionController;

  factory AppDependencies.live() {
    final AuthRepository authRepository = SupabaseAuthRepository(
      client: AppSupabaseClient.client,
    );
    final SessionStorage storage = SharedPreferencesSessionStorage();

    return AppDependencies._(
      authRepository: authRepository,
      announcementRepository: SupabaseAnnouncementRepository(
        client: AppSupabaseClient.client,
      ),
      membershipRepository: SupabaseMembershipRepository(
        client: AppSupabaseClient.client,
      ),
      duesRepository: SupabaseDuesRepository(
        client: AppSupabaseClient.client,
      ),
      eventRepository: SupabaseEventRepository(
        client: AppSupabaseClient.client,
      ),
      supportRepository: SupabaseSupportRepository(
        client: AppSupabaseClient.client,
      ),
      inviteRepository: SupabaseInviteRepository(
        client: AppSupabaseClient.client,
      ),
      jobRepository: SupabaseJobRepository(
        client: AppSupabaseClient.client,
      ),
      organizationRepository: SupabaseOrganizationRepository(
        client: AppSupabaseClient.client,
      ),
      notificationRepository: SupabaseNotificationRepository(
        client: AppSupabaseClient.client,
      ),
      paymentGatewayRepository: SupabasePaymentGatewayRepository(
        client: AppSupabaseClient.client,
      ),
      reportRepository: SupabaseReportRepository(
        client: AppSupabaseClient.client,
      ),
      authorizationService: const AuthorizationService(),
      sessionController: SessionController(
        storage: storage,
        authRepository: authRepository,
      ),
    );
  }
}
