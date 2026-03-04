import 'package:flutter/material.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/utils/date_time_formatter.dart';
import 'package:hkd/core/validation/form_validators.dart';
import 'package:hkd/core/widgets/empty_state_view.dart';
import 'package:hkd/features/membership/domain/models/membership_application_model.dart';

class MembershipStatusPage extends StatefulWidget {
  const MembershipStatusPage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<MembershipStatusPage> createState() => _MembershipStatusPageState();
}

class _MembershipStatusPageState extends State<MembershipStatusPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _applicationIdController =
      TextEditingController();
  MembershipApplicationModel? _application;
  bool _isLoading = false;

  @override
  void dispose() {
    _applicationIdController.dispose();
    super.dispose();
  }

  Future<void> _query() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final MembershipApplicationModel? found =
        await widget.dependencies.membershipRepository.getById(
      _applicationIdController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _application = found;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final MembershipApplicationModel? application = _application;

    return Scaffold(
      appBar: AppBar(title: const Text('Basvuru Durumu')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Form(
              key: _formKey,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _applicationIdController,
                      validator: FormValidators.uuid,
                      decoration: const InputDecoration(
                        labelText: 'Basvuru Takip Kodu',
                        hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _query,
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sorgula'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: application == null
                  ? const EmptyStateView(
                      title: 'Basvuru Bulunamadi',
                      message: 'Bu takip koduna ait basvuru bulunamadi.',
                    )
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              application.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text('Telefon: ${application.phone}'),
                            Text(
                                'Uyelik Tipi: ${application.memberType.label}'),
                            if (application.orgName != null &&
                                application.orgName!.trim().isNotEmpty)
                              Text('Org: ${application.orgName}'),
                            Text(
                              'Basvuru Tarihi: '
                              '${DateTimeFormatter.dateTime(application.createdAt)}',
                            ),
                            const SizedBox(height: 10),
                            Text('Durum: ${application.status.label}'),
                            if (application.decidedBy != null) ...<Widget>[
                              Text('Karar Veren: ${application.decidedBy}'),
                            ],
                            if (application.decidedAt != null) ...<Widget>[
                              Text(
                                'Karar Zamani: '
                                '${DateTimeFormatter.dateTime(application.decidedAt!)}',
                              ),
                            ],
                            if (application.rejectReason != null) ...<Widget>[
                              Text('Red Nedeni: ${application.rejectReason}'),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
