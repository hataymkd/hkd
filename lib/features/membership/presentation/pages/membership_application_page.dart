import 'package:flutter/material.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/utils/error_message_mapper.dart';
import 'package:hkd/core/validation/form_validators.dart';
import 'package:hkd/features/membership/domain/models/membership_application_model.dart';

class MembershipApplicationPage extends StatefulWidget {
  const MembershipApplicationPage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<MembershipApplicationPage> createState() =>
      _MembershipApplicationPageState();
}

class _MembershipApplicationPageState extends State<MembershipApplicationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _orgPhoneController = TextEditingController();
  final TextEditingController _orgTaxNoController = TextEditingController();

  MembershipMemberType _selectedMemberType = MembershipMemberType.courier;

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _orgNameController.dispose();
    _orgPhoneController.dispose();
    _orgTaxNoController.dispose();
    super.dispose();
  }

  bool get _requiresOrganizationFields =>
      _selectedMemberType != MembershipMemberType.courier;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String applicationId =
          await widget.dependencies.membershipRepository.apply(
        fullName: _nameController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
        memberType: _selectedMemberType,
        orgName: _requiresOrganizationFields ? _orgNameController.text : null,
        orgPhone: _requiresOrganizationFields ? _orgPhoneController.text : null,
        orgTaxNo: _requiresOrganizationFields ? _orgTaxNoController.text : null,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Basvuru alindi. Takip kodu: $applicationId'),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorMessageMapper.toFriendlyTurkish(
              error,
              fallback:
                  'Basvuru gonderilirken hata olustu. Lutfen tekrar deneyin.',
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Uye Basvurusu')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  validator: (String? value) => FormValidators.requiredText(
                    value,
                    fieldName: 'Ad soyad',
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
                const SizedBox(height: 12),
                DropdownButtonFormField<MembershipMemberType>(
                  initialValue: _selectedMemberType,
                  items: MembershipMemberType.values
                      .map(
                        (MembershipMemberType type) =>
                            DropdownMenuItem<MembershipMemberType>(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (MembershipMemberType? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedMemberType = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Uyelik Tipi',
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                if (_requiresOrganizationFields) ...<Widget>[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _orgNameController,
                    validator: (String? value) => FormValidators.requiredText(
                      value,
                      fieldName: 'Isletme/Sirket Adi',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Isletme/Sirket Adi',
                      prefixIcon: Icon(Icons.apartment),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _orgPhoneController,
                    keyboardType: TextInputType.phone,
                    validator: FormValidators.phone,
                    decoration: const InputDecoration(
                      labelText: 'Isletme/Sirket Telefonu',
                      hintText: '05XXXXXXXXX',
                      prefixIcon: Icon(Icons.phone_enabled),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _orgTaxNoController,
                    decoration: const InputDecoration(
                      labelText: 'Vergi No (Opsiyonel)',
                      prefixIcon: Icon(Icons.receipt_long),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Basvuru Gonder'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
