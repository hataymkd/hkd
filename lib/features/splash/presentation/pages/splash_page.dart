import 'package:flutter/material.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/navigation/app_deep_link_service.dart';
import 'package:hkd/core/navigation/app_routes.dart';
import 'package:hkd/core/push/push_registration_service.dart';
import 'package:hkd/features/update/update_dialog.dart';
import 'package:hkd/features/update/update_model.dart';
import 'package:hkd/features/update/update_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final UpdateService _updateService = UpdateService(
    timeout: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  Future<void> _startFlow() async {
    try {
      final Future<UpdateCheckResult> updateCheckFuture =
          _updateService.checkForUpdate();

      await widget.dependencies.sessionController.initialize();
      await PushRegistrationService.ensureInitialized(
        notificationRepository: widget.dependencies.notificationRepository,
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));

      final UpdateCheckResult updateResult = await updateCheckFuture;

      if (!mounted) {
        return;
      }

      if (updateResult.manifest != null &&
          (updateResult.isMandatory || updateResult.isOptional)) {
        await showUpdateDialog(
          context: context,
          manifest: updateResult.manifest!,
          isMandatory: updateResult.isMandatory,
        );

        if (!mounted) {
          return;
        }

        if (updateResult.isMandatory) {
          return;
        }
      }

      final String? inviteToken =
          AppDeepLinkService.instance.consumePendingInviteToken();
      if (inviteToken != null && inviteToken.trim().isNotEmpty) {
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.acceptInvite,
          arguments: inviteToken,
        );
        return;
      }

      final bool isLoggedIn = widget.dependencies.sessionController.isLoggedIn;
      final bool isActive =
          widget.dependencies.sessionController.currentUser?.isActive ?? false;

      final String targetRoute = !isLoggedIn
          ? AppRoutes.login
          : isActive
              ? AppRoutes.home
              : AppRoutes.pendingApproval;

      Navigator.of(context).pushReplacementNamed(
        targetRoute,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFFD32F2F),
              Color(0xFFEF5350),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.two_wheeler,
                  size: 40,
                  color: Color(0xFFD32F2F),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'HAMOKDER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Hatay Kuryeler Dernegi',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 22),
              SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
