import 'package:flutter/material.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/navigation/app_routes.dart';
import 'package:hkd/core/utils/error_message_mapper.dart';

class PendingApprovalPage extends StatefulWidget {
  const PendingApprovalPage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<PendingApprovalPage> createState() => _PendingApprovalPageState();
}

class _PendingApprovalPageState extends State<PendingApprovalPage> {
  bool _isLoggingOut = false;
  bool _isClaimingPresident = false;

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }
    setState(() {
      _isLoggingOut = true;
    });
    await widget.dependencies.sessionController.logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _claimInitialPresident() async {
    if (_isClaimingPresident || _isLoggingOut) {
      return;
    }

    final currentUser = widget.dependencies.sessionController.currentUser;
    if (currentUser == null) {
      return;
    }

    setState(() {
      _isClaimingPresident = true;
    });

    try {
      await widget.dependencies.authRepository.claimInitialPresident();
      final refreshedUser =
          await widget.dependencies.authRepository.fetchById(currentUser.id);
      if (refreshedUser != null) {
        await widget.dependencies.sessionController.login(refreshedUser);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_normalizeErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isClaimingPresident = false;
        });
      }
    }
  }

  String _normalizeErrorMessage(Object error) {
    return ErrorMessageMapper.toFriendlyTurkish(
      error,
      fallback: 'Islem tamamlanamadi. Lutfen daha sonra tekrar deneyin.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayName =
        widget.dependencies.sessionController.currentUser?.name ?? 'Uyemiz';

    return Scaffold(
      appBar: AppBar(title: const Text('Onay Bekleniyor')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.hourglass_top, size: 38),
                    const SizedBox(height: 10),
                    Text(
                      'Merhaba $displayName,',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hesabiniz dernek yonetimi tarafindan onaylanana kadar '
                      'uygulama modullerine erisemezsiniz.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Onay tamamlandiginda tekrar giris yaparak devam edebilirsiniz.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: (_isClaimingPresident || _isLoggingOut)
                            ? null
                            : _claimInitialPresident,
                        icon: _isClaimingPresident
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified_user),
                        label: const Text(
                          'Ilk Kurulum: Baskan Olarak Aktiflestir',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoggingOut ? null : _logout,
                        child: _isLoggingOut
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Cikis Yap'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
