import 'package:flutter/material.dart';
import 'package:hkd/core/authorization/app_permission.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/navigation/app_routes.dart';
import 'package:hkd/core/widgets/error_state_view.dart';
import 'package:hkd/features/announcements/domain/models/announcement_model.dart';
import 'package:hkd/features/announcements/presentation/pages/announcement_detail_page.dart';
import 'package:hkd/features/announcements/presentation/pages/announcements_page.dart';
import 'package:hkd/features/auth/presentation/pages/login_page.dart';
import 'package:hkd/features/auth/presentation/pages/pending_approval_page.dart';
import 'package:hkd/features/events/presentation/pages/events_page.dart';
import 'package:hkd/features/home/presentation/pages/home_page.dart';
import 'package:hkd/features/invites/presentation/pages/accept_invite_page.dart';
import 'package:hkd/features/jobs/presentation/pages/jobs_marketplace_page.dart';
import 'package:hkd/features/management/presentation/pages/management_panel_page.dart';
import 'package:hkd/features/membership/presentation/pages/membership_application_page.dart';
import 'package:hkd/features/membership/presentation/pages/membership_status_page.dart';
import 'package:hkd/features/notifications/presentation/pages/notifications_page.dart';
import 'package:hkd/features/organizations/presentation/pages/organization_panel_page.dart';
import 'package:hkd/features/payments/presentation/pages/payment_status_page.dart';
import 'package:hkd/features/profile/presentation/pages/profile_page.dart';
import 'package:hkd/features/reports/presentation/pages/admin_reports_page.dart';
import 'package:hkd/features/splash/presentation/pages/splash_page.dart';
import 'package:hkd/features/support/presentation/pages/support_center_page.dart';

class AppRouter {
  const AppRouter({
    required this.dependencies,
  });

  final AppDependencies dependencies;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute<SplashPage>(
          builder: (_) => SplashPage(dependencies: dependencies),
          settings: settings,
        );
      case AppRoutes.login:
        return MaterialPageRoute<LoginPage>(
          builder: (_) => LoginPage(dependencies: dependencies),
          settings: settings,
        );
      case AppRoutes.acceptInvite:
        final String? initialToken =
            _resolveInviteTokenFromArguments(settings.arguments);
        return MaterialPageRoute<AcceptInvitePage>(
          builder: (_) => AcceptInvitePage(
            dependencies: dependencies,
            initialToken: initialToken,
          ),
          settings: settings,
        );
      case AppRoutes.pendingApproval:
        return _forAuthenticated(
          settings: settings,
          allowInactive: true,
          builder: () => PendingApprovalPage(dependencies: dependencies),
        );
      case AppRoutes.home:
        return _forAuthenticated(
          settings: settings,
          builder: () => HomePage(dependencies: dependencies),
        );
      case AppRoutes.announcements:
        return _forAuthenticated(
          settings: settings,
          builder: () => AnnouncementsPage(dependencies: dependencies),
        );
      case AppRoutes.events:
        return _forAuthenticated(
          settings: settings,
          builder: () => EventsPage(dependencies: dependencies),
        );
      case AppRoutes.announcementDetail:
        if (settings.arguments is! AnnouncementModel) {
          return _errorRoute(
            title: 'Gecersiz Duyuru',
            message: 'Duyuru detayi acilamadi.',
            settings: settings,
          );
        }
        final AnnouncementModel announcement =
            settings.arguments! as AnnouncementModel;
        return MaterialPageRoute<AnnouncementDetailPage>(
          builder: (_) => AnnouncementDetailPage(announcement: announcement),
          settings: settings,
        );
      case AppRoutes.profile:
        return _forAuthenticated(
          settings: settings,
          builder: () => ProfilePage(dependencies: dependencies),
        );
      case AppRoutes.paymentStatus:
        return _forAuthenticated(
          settings: settings,
          builder: () => PaymentStatusPage(dependencies: dependencies),
        );
      case AppRoutes.notifications:
        return _forAuthenticated(
          settings: settings,
          builder: () => NotificationsPage(dependencies: dependencies),
        );
      case AppRoutes.supportCenter:
        return _forAuthenticated(
          settings: settings,
          builder: () => SupportCenterPage(dependencies: dependencies),
        );
      case AppRoutes.jobsMarketplace:
        return _forAuthenticated(
          settings: settings,
          builder: () => JobsMarketplacePage(dependencies: dependencies),
        );
      case AppRoutes.organizationPanel:
        return _forAuthenticated(
          settings: settings,
          builder: () => OrganizationPanelPage(dependencies: dependencies),
        );
      case AppRoutes.management:
        return _forAuthenticated(
          settings: settings,
          builder: () => ManagementPanelPage(dependencies: dependencies),
          guardPermission: AppPermission.openManagementPanel,
        );
      case AppRoutes.adminReports:
        return _forAuthenticated(
          settings: settings,
          builder: () => AdminReportsPage(dependencies: dependencies),
          guardPermission: AppPermission.openManagementPanel,
        );
      case AppRoutes.membershipApplication:
        return MaterialPageRoute<MembershipApplicationPage>(
          builder: (_) => MembershipApplicationPage(dependencies: dependencies),
          settings: settings,
        );
      case AppRoutes.membershipStatus:
        return MaterialPageRoute<MembershipStatusPage>(
          builder: (_) => MembershipStatusPage(dependencies: dependencies),
          settings: settings,
        );
      default:
        return _errorRoute(
          title: 'Sayfa Bulunamadi',
          message: 'Istediginiz sayfa mevcut degil.',
          settings: settings,
        );
    }
  }

  Route<dynamic> _forAuthenticated({
    required RouteSettings settings,
    required Widget Function() builder,
    AppPermission? guardPermission,
    bool allowInactive = false,
  }) {
    final user = dependencies.sessionController.currentUser;
    if (user == null) {
      return MaterialPageRoute<LoginPage>(
        builder: (_) => LoginPage(dependencies: dependencies),
        settings: settings,
      );
    }

    if (!allowInactive && !user.isActive) {
      return MaterialPageRoute<PendingApprovalPage>(
        builder: (_) => PendingApprovalPage(dependencies: dependencies),
        settings: const RouteSettings(name: AppRoutes.pendingApproval),
      );
    }

    if (guardPermission != null &&
        !dependencies.authorizationService.can(
          user: user,
          permission: guardPermission,
        )) {
      return _errorRoute(
        title: 'Yetkisiz Islem',
        message: 'Bu sayfaya erisim yetkiniz bulunmuyor.',
        settings: settings,
      );
    }

    return MaterialPageRoute<dynamic>(
      builder: (_) => builder(),
      settings: settings,
    );
  }

  Route<dynamic> _errorRoute({
    required String title,
    required String message,
    required RouteSettings settings,
  }) {
    return MaterialPageRoute<Scaffold>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('HAMOKDER')),
        body: ErrorStateView(
          title: title,
          message: message,
        ),
      ),
      settings: settings,
    );
  }

  String? _resolveInviteTokenFromArguments(dynamic arguments) {
    if (arguments is String) {
      final String value = arguments.trim();
      return value.isEmpty ? null : value;
    }
    if (arguments is Map && arguments['token'] is String) {
      final String value = (arguments['token'] as String).trim();
      return value.isEmpty ? null : value;
    }
    return null;
  }
}
