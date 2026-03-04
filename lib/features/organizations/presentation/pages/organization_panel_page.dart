import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/utils/date_time_formatter.dart';
import 'package:hkd/core/utils/error_message_mapper.dart';
import 'package:hkd/core/validation/form_validators.dart';
import 'package:hkd/core/widgets/empty_state_view.dart';
import 'package:hkd/core/widgets/error_state_view.dart';
import 'package:hkd/core/widgets/loading_state_view.dart';
import 'package:hkd/features/organizations/domain/models/organization_invite_model.dart';
import 'package:hkd/features/organizations/domain/models/organization_member_model.dart';
import 'package:hkd/features/organizations/domain/models/organization_model.dart';

class OrganizationPanelPage extends StatefulWidget {
  const OrganizationPanelPage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<OrganizationPanelPage> createState() => _OrganizationPanelPageState();
}

class _OrganizationPanelPageState extends State<OrganizationPanelPage> {
  final GlobalKey<FormState> _inviteFormKey = GlobalKey<FormState>();
  final TextEditingController _invitePhoneController = TextEditingController();

  bool _isLoading = false;
  bool _isWorking = false;
  String? _errorMessage;
  String? _selectedOrganizationId;

  List<OrganizationModel> _organizations = <OrganizationModel>[];
  List<OrganizationMemberModel> _members = <OrganizationMemberModel>[];
  List<OrganizationInviteModel> _invites = <OrganizationInviteModel>[];

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  @override
  void dispose() {
    _invitePhoneController.dispose();
    super.dispose();
  }

  OrganizationModel? get _selectedOrganization {
    for (final OrganizationModel item in _organizations) {
      if (item.id == _selectedOrganizationId) {
        return item;
      }
    }
    return null;
  }

  bool get _canManageInvites {
    final OrganizationModel? selected = _selectedOrganization;
    if (selected == null) {
      return false;
    }
    if (selected.myStatus != OrganizationMembershipStatus.active) {
      return false;
    }
    return selected.myRole == OrganizationRole.owner ||
        selected.myRole == OrganizationRole.manager;
  }

  Future<void> _loadOrganizations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<OrganizationModel> organizations = await widget
          .dependencies.organizationRepository
          .fetchMyOrganizations();

      if (!mounted) {
        return;
      }

      final String? selectedId = _resolveSelectedOrganization(
        previous: _selectedOrganizationId,
        organizations: organizations,
      );

      setState(() {
        _organizations = organizations;
        _selectedOrganizationId = selectedId;
        _isLoading = false;
      });

      if (selectedId != null) {
        await _loadOrganizationDetails(selectedId);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Organizasyon bilgileri yuklenemedi.';
        _isLoading = false;
      });
    }
  }

  String? _resolveSelectedOrganization({
    required String? previous,
    required List<OrganizationModel> organizations,
  }) {
    if (organizations.isEmpty) {
      return null;
    }

    if (previous != null &&
        organizations.any((OrganizationModel item) => item.id == previous)) {
      return previous;
    }

    return organizations.first.id;
  }

  Future<void> _loadOrganizationDetails(String organizationId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<OrganizationMemberModel> members = await widget
          .dependencies.organizationRepository
          .fetchOrganizationMembers(organizationId: organizationId);
      final List<OrganizationInviteModel> invites = await widget
          .dependencies.organizationRepository
          .fetchOrganizationInvites(organizationId: organizationId);

      if (!mounted) {
        return;
      }

      setState(() {
        _members = members;
        _invites = invites;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Organizasyon detaylari yuklenemedi.';
        _isLoading = false;
      });
    }
  }

  Future<void> _createInvite() async {
    if (!_inviteFormKey.currentState!.validate()) {
      return;
    }

    final OrganizationModel? selected = _selectedOrganization;
    if (selected == null) {
      _showMessage('Organizasyon seciniz.');
      return;
    }

    setState(() {
      _isWorking = true;
    });

    try {
      final OrganizationInviteModel invite =
          await widget.dependencies.organizationRepository.createInvite(
        organizationId: selected.id,
        phone: _invitePhoneController.text,
      );

      _invitePhoneController.clear();
      await _loadOrganizationDetails(selected.id);

      if (!mounted) {
        return;
      }

      await _showInviteResult(invite);
    } catch (error) {
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Davet olusturulamadi. Lutfen tekrar deneyin.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _cancelInvite(String inviteId) async {
    final OrganizationModel? selected = _selectedOrganization;
    if (selected == null) {
      return;
    }

    setState(() {
      _isWorking = true;
    });

    try {
      await widget.dependencies.organizationRepository.cancelInvite(
        inviteId: inviteId,
      );
      await _loadOrganizationDetails(selected.id);
      _showMessage('Davet iptal edildi.');
    } catch (_) {
      _showMessage('Davet iptal edilemedi.');
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _updateMemberRole({
    required String userId,
    required OrganizationRole role,
  }) async {
    final OrganizationModel? selected = _selectedOrganization;
    if (selected == null) {
      return;
    }
    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.organizationRepository.updateMemberRole(
        organizationId: selected.id,
        userId: userId,
        role: role,
      );
      await _loadOrganizationDetails(selected.id);
      _showMessage('Uye rolu guncellendi.');
    } catch (error) {
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Uye rolu guncellenemedi.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _updateMemberStatus({
    required String userId,
    required OrganizationMembershipStatus status,
  }) async {
    final OrganizationModel? selected = _selectedOrganization;
    if (selected == null) {
      return;
    }
    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.organizationRepository.updateMemberStatus(
        organizationId: selected.id,
        userId: userId,
        status: status,
      );
      await _loadOrganizationDetails(selected.id);
      _showMessage('Uye durumu guncellendi.');
    } catch (error) {
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Uye durumu guncellenemedi.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _showInviteResult(OrganizationInviteModel invite) async {
    final String inviteLink =
        invite.inviteUrl ?? 'hkd://invite?token=${invite.token}';

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Davet Olusturuldu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Telefon: ${invite.phone}'),
              const SizedBox(height: 8),
              Text(
                  'Gecerlilik: ${DateTimeFormatter.dateTime(invite.expiresAt)}'),
              const SizedBox(height: 10),
              SelectableText(inviteLink),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
            ElevatedButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: inviteLink));
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                _showMessage('Davet linki panoya kopyalandi.');
              },
              child: const Text('Linki Kopyala'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingStateView(message: 'Organizasyon verileri yukleniyor...'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Organizasyon Paneli')),
        body: ErrorStateView(
          title: 'Hata',
          message: _errorMessage!,
          onRetry: _loadOrganizations,
        ),
      );
    }

    if (_organizations.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Organizasyon Paneli')),
        body: const EmptyStateView(
          title: 'Organizasyon Bulunamadi',
          message: 'Size ait aktif/pending organizasyon uyeligi yok.',
        ),
      );
    }

    final OrganizationModel? selected = _selectedOrganization;
    if (selected == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Organizasyon Paneli')),
        body: const EmptyStateView(
          title: 'Organizasyon Secilemedi',
          message: 'Lutfen tekrar deneyin.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Organizasyon Paneli')),
      body: RefreshIndicator(
        onRefresh: () => _loadOrganizationDetails(selected.id),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: _selectedOrganizationId,
              decoration: const InputDecoration(
                labelText: 'Organizasyon',
                prefixIcon: Icon(Icons.apartment),
              ),
              items: _organizations.map((OrganizationModel organization) {
                return DropdownMenuItem<String>(
                  value: organization.id,
                  child: Text(organization.name),
                );
              }).toList(),
              onChanged: (String? value) async {
                if (value == null || value == _selectedOrganizationId) {
                  return;
                }
                setState(() {
                  _selectedOrganizationId = value;
                });
                await _loadOrganizationDetails(value);
              },
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      selected.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Tip: ${selected.type.label}'),
                    if (selected.phone != null)
                      Text('Telefon: ${selected.phone}'),
                    Text('Rolunuz: ${selected.myRole.label}'),
                    Text('Uyelik Durumu: ${selected.myStatus.label}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_canManageInvites) ...<Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Form(
                    key: _inviteFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Kurye Davet Et',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _invitePhoneController,
                          keyboardType: TextInputType.phone,
                          validator: FormValidators.phone,
                          decoration: const InputDecoration(
                            labelText: 'Kurye Telefonu',
                            hintText: '05XXXXXXXXX',
                            prefixIcon: Icon(Icons.phone),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _isWorking ? null : _createInvite,
                          icon: const Icon(Icons.send),
                          label: const Text('Davet Olustur'),
                        ),
                      ],
                    ),
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
                      'Organizasyon Uyeleri (${_members.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_members.isEmpty)
                      const Text('Uye kaydi bulunmuyor.')
                    else
                      ..._members.map((OrganizationMemberModel member) {
                        final String memberStatus = member.status.label;
                        final String activeBadge =
                            member.isActive ? 'Aktif Hesap' : 'Pasif Hesap';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  member.fullName,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 4),
                                Text('${member.role.label} ($memberStatus)'),
                                Text(activeBadge),
                                if ((member.phone ?? '').isNotEmpty)
                                  Text('Telefon: ${member.phone}'),
                                if (_canManageInvites) ...<Widget>[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: <Widget>[
                                      if (member.status !=
                                          OrganizationMembershipStatus.active)
                                        OutlinedButton(
                                          onPressed: _isWorking
                                              ? null
                                              : () => _updateMemberStatus(
                                                    userId: member.userId,
                                                    status:
                                                        OrganizationMembershipStatus
                                                            .active,
                                                  ),
                                          child: const Text('Aktif Et'),
                                        ),
                                      if (member.status !=
                                          OrganizationMembershipStatus.pending)
                                        OutlinedButton(
                                          onPressed: _isWorking
                                              ? null
                                              : () => _updateMemberStatus(
                                                    userId: member.userId,
                                                    status:
                                                        OrganizationMembershipStatus
                                                            .pending,
                                                  ),
                                          child: const Text('Pending Yap'),
                                        ),
                                      if (member.role !=
                                          OrganizationRole.manager)
                                        OutlinedButton(
                                          onPressed: _isWorking
                                              ? null
                                              : () => _updateMemberRole(
                                                    userId: member.userId,
                                                    role: OrganizationRole
                                                        .manager,
                                                  ),
                                          child: const Text('Manager Yap'),
                                        ),
                                      if (member.role != OrganizationRole.staff)
                                        OutlinedButton(
                                          onPressed: _isWorking
                                              ? null
                                              : () => _updateMemberRole(
                                                    userId: member.userId,
                                                    role:
                                                        OrganizationRole.staff,
                                                  ),
                                          child: const Text('Staff Yap'),
                                        ),
                                      if (member.role != OrganizationRole.owner)
                                        OutlinedButton(
                                          onPressed: _isWorking
                                              ? null
                                              : () => _updateMemberRole(
                                                    userId: member.userId,
                                                    role:
                                                        OrganizationRole.owner,
                                                  ),
                                          child: const Text('Owner Yap'),
                                        ),
                                    ],
                                  ),
                                ],
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
                      'Davetler (${_invites.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_invites.isEmpty)
                      const Text('Davet kaydi bulunmuyor.')
                    else
                      ..._invites.map((OrganizationInviteModel invite) {
                        final String label = _inviteStatusLabel(invite.status);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(invite.phone),
                                const SizedBox(height: 4),
                                Text('Durum: $label'),
                                Text(
                                  'Olusturma: ${DateTimeFormatter.dateTime(invite.createdAt)}',
                                ),
                                Text(
                                  'Bitis: ${DateTimeFormatter.dateTime(invite.expiresAt)}',
                                ),
                                if (invite.inviteUrl != null &&
                                    invite.inviteUrl!.trim().isNotEmpty)
                                  SelectableText(invite.inviteUrl!),
                                if (_canManageInvites && invite.isPending)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton(
                                      onPressed: _isWorking
                                          ? null
                                          : () => _cancelInvite(invite.id),
                                      child: const Text('Iptal Et'),
                                    ),
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
          ],
        ),
      ),
    );
  }

  String _inviteStatusLabel(String raw) {
    switch (raw) {
      case 'accepted':
        return 'Kabul Edildi';
      case 'expired':
        return 'Suresi Doldu';
      case 'cancelled':
        return 'Iptal Edildi';
      default:
        return 'Bekliyor';
    }
  }
}
