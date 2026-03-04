import 'package:flutter/material.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/navigation/app_routes.dart';
import 'package:hkd/core/push/push_registration_service.dart';
import 'package:hkd/core/utils/error_message_mapper.dart';
import 'package:hkd/core/validation/form_validators.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/invites/domain/models/invite_accept_result_model.dart';

class AcceptInvitePage extends StatefulWidget {
  const AcceptInvitePage({
    super.key,
    required this.dependencies,
    this.initialToken,
  });

  final AppDependencies dependencies;
  final String? initialToken;

  @override
  State<AcceptInvitePage> createState() => _AcceptInvitePageState();
}

class _AcceptInvitePageState extends State<AcceptInvitePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final String initialToken = widget.initialToken?.trim() ?? '';
    if (initialToken.isNotEmpty) {
      _tokenController.text = initialToken;
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String token = _tokenController.text.trim();
    final String fullName = _fullNameController.text.trim();
    final String phone = _phoneController.text.trim();
    final String password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      final InviteAcceptResultModel result =
          await widget.dependencies.inviteRepository.acceptInvite(
        token: token,
        fullName: fullName,
        phone: phone,
        password: password,
      );

      if (!result.ok) {
        throw StateError('Davet kabul edilemedi.');
      }

      final UserModel? user = await widget.dependencies.authRepository.login(
        phone: phone,
        password: password,
      );

      if (user == null) {
        if (!mounted) {
          return;
        }
        _showMessage(
          'Davet kabul edildi. Giris ekranindan telefon ve sifrenizle devam edin.',
        );
        Navigator.of(context).pop();
        return;
      }

      await widget.dependencies.sessionController.login(user);
      await PushRegistrationService.ensureInitialized(
        notificationRepository: widget.dependencies.notificationRepository,
      );
      await PushRegistrationService.syncNow(
        notificationRepository: widget.dependencies.notificationRepository,
      );
      if (!mounted) {
        return;
      }

      final String targetRoute =
          user.isActive ? AppRoutes.home : AppRoutes.pendingApproval;

      Navigator.of(context).pushNamedAndRemoveUntil(
        targetRoute,
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Davet kabul islemi basarisiz. Lutfen tekrar deneyin.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Davet Kabul Et')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Davet baglantinizdaki token ile hesap olusturun.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _tokenController,
                          validator: FormValidators.inviteToken,
                          decoration: const InputDecoration(
                            labelText: 'Davet Token',
                            prefixIcon: Icon(Icons.vpn_key),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _fullNameController,
                          validator: (String? value) =>
                              FormValidators.requiredText(
                            value,
                            fieldName: 'Ad Soyad',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Ad Soyad',
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          validator: FormValidators.phone,
                          decoration: const InputDecoration(
                            labelText: 'Telefon',
                            hintText: '05XXXXXXXXX',
                            prefixIcon: Icon(Icons.phone),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          validator: FormValidators.password,
                          decoration: const InputDecoration(
                            labelText: 'Sifre',
                            prefixIcon: Icon(Icons.lock),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Daveti Kabul Et'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
