import 'package:flutter/material.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/navigation/app_routes.dart';
import 'package:hkd/core/push/push_registration_service.dart';
import 'package:hkd/core/utils/error_message_mapper.dart';
import 'package:hkd/core/validation/form_validators.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';

enum _LoginMode {
  password,
  otp,
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _obscurePassword = true;
  bool _otpRequested = false;
  _LoginMode _loginMode = _LoginMode.password;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String phone = _phoneController.text.trim();

    setState(() {
      _isLoading = true;
    });
    try {
      final UserModel? user;
      if (_loginMode == _LoginMode.password) {
        final String password = _passwordController.text.trim();
        user = await widget.dependencies.authRepository.login(
          phone: phone,
          password: password,
        );
      } else {
        user = await widget.dependencies.authRepository.verifyLoginOtp(
          phone: phone,
          otpCode: _otpController.text.trim(),
        );
      }

      if (!mounted) {
        return;
      }

      if (user == null) {
        _showMessage(
          _loginMode == _LoginMode.password
              ? 'Giris basarisiz. Bilgilerinizi kontrol edin.'
              : 'OTP dogrulanamadi. Kodu kontrol edin.',
        );
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
      _showMessage(_readFriendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendOtpCode() async {
    final String? phoneError = FormValidators.phone(_phoneController.text);
    if (phoneError != null) {
      _showMessage(phoneError);
      return;
    }

    final String phone = _phoneController.text.trim();
    setState(() {
      _isSendingOtp = true;
    });
    try {
      await widget.dependencies.authRepository.requestLoginOtp(phone: phone);
      if (!mounted) {
        return;
      }
      setState(() {
        _otpRequested = true;
        _loginMode = _LoginMode.otp;
      });
      _showMessage('OTP kodu gonderildi. SMS kutunuzu kontrol edin.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'OTP kodu gonderilemedi. Lutfen tekrar deneyin.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _readFriendlyError(Object error) {
    final String raw = error.toString();
    if (raw.startsWith('AuthException') && _loginMode == _LoginMode.password) {
      return 'Giris basarisiz. Telefon ya da sifre hatali.';
    }
    if (raw.toLowerCase().contains('otp')) {
      return 'OTP islemi basarisiz. Kodu kontrol edip tekrar deneyin.';
    }
    return ErrorMessageMapper.toFriendlyTurkish(
      error,
      fallback: 'Giris sirasinda hata olustu. Lutfen tekrar deneyin.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Icon(Icons.two_wheeler, size: 56),
                        const SizedBox(height: 8),
                        Text(
                          'Hatay Kuryeler Dernegi',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        SegmentedButton<_LoginMode>(
                          segments: const <ButtonSegment<_LoginMode>>[
                            ButtonSegment<_LoginMode>(
                              value: _LoginMode.password,
                              label: Text('Sifre'),
                              icon: Icon(Icons.lock),
                            ),
                            ButtonSegment<_LoginMode>(
                              value: _LoginMode.otp,
                              label: Text('OTP'),
                              icon: Icon(Icons.sms),
                            ),
                          ],
                          selected: <_LoginMode>{_loginMode},
                          onSelectionChanged: (_isLoading || _isSendingOtp)
                              ? null
                              : (Set<_LoginMode> selection) {
                                  if (selection.isEmpty) {
                                    return;
                                  }
                                  setState(() {
                                    _loginMode = selection.first;
                                  });
                                },
                        ),
                        const SizedBox(height: 24),
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
                        if (_loginMode == _LoginMode.password)
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            validator: FormValidators.password,
                            decoration: InputDecoration(
                              labelText: 'Sifre',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Sifreyi goster'
                                    : 'Sifreyi gizle',
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                          ),
                        if (_loginMode == _LoginMode.otp) ...<Widget>[
                          TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            validator: FormValidators.otpCode,
                            decoration: const InputDecoration(
                              labelText: 'OTP Kodu',
                              hintText: '6 haneli kod',
                              prefixIcon: Icon(Icons.verified_user),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _otpRequested
                                ? 'SMS ile gelen kodu girip devam edin.'
                                : 'Once OTP kodu gondermelisiniz.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  _loginMode == _LoginMode.password
                                      ? 'Giris Yap'
                                      : 'OTP ile Giris Yap',
                                ),
                        ),
                        if (_loginMode == _LoginMode.otp) ...<Widget>[
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: (_isLoading || _isSendingOtp)
                                ? null
                                : _sendOtpCode,
                            child: _isSendingOtp
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _otpRequested
                                        ? 'Kodu Tekrar Gonder'
                                        : 'OTP Kodu Gonder',
                                  ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.membershipApplication);
                          },
                          child: const Text('Yeni Uye Basvurusu'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.acceptInvite);
                          },
                          child: const Text('Davet Kabul Et'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.membershipStatus);
                          },
                          child: const Text('Basvuru Durumu Sorgula'),
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
