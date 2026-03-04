import 'package:flutter/material.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/utils/date_time_formatter.dart';
import 'package:hkd/core/utils/error_message_mapper.dart';
import 'package:hkd/core/validation/form_validators.dart';
import 'package:hkd/core/widgets/empty_state_view.dart';
import 'package:hkd/core/widgets/error_state_view.dart';
import 'package:hkd/core/widgets/loading_state_view.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/auth/domain/models/user_role.dart';
import 'package:hkd/features/jobs/domain/models/courier_profile_model.dart';
import 'package:hkd/features/jobs/domain/models/job_post_model.dart';
import 'package:hkd/features/organizations/domain/models/organization_model.dart';

class JobsMarketplacePage extends StatefulWidget {
  const JobsMarketplacePage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<JobsMarketplacePage> createState() => _JobsMarketplacePageState();
}

class _JobsMarketplacePageState extends State<JobsMarketplacePage> {
  static const String _cancelApplicationToken = '__cancel_application__';

  final TextEditingController _jobSearchController = TextEditingController();
  final TextEditingController _jobCityController = TextEditingController();
  final TextEditingController _courierSearchController =
      TextEditingController();
  final TextEditingController _courierCityController = TextEditingController();

  bool _isLoadingJobs = false;
  bool _isLoadingCouriers = false;
  bool _isWorking = false;
  String? _jobsError;
  String? _couriersError;

  List<JobPostModel> _jobs = <JobPostModel>[];
  Set<String> _appliedJobIds = <String>{};
  List<CourierProfileModel> _couriers = <CourierProfileModel>[];
  List<OrganizationModel> _manageableOrganizations = <OrganizationModel>[];
  CourierProfileModel? _myCourierProfile;
  JobVehicleType _courierVehicleFilter = JobVehicleType.any;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _jobSearchController.dispose();
    _jobCityController.dispose();
    _courierSearchController.dispose();
    _courierCityController.dispose();
    super.dispose();
  }

  UserModel? get _currentUser =>
      widget.dependencies.sessionController.currentUser;

  bool get _isAdminRole {
    final UserRole? role = _currentUser?.role;
    return role == UserRole.president || role == UserRole.manager;
  }

  bool get _canCreateJob {
    final UserModel? user = _currentUser;
    if (user == null || !user.isActive) {
      return false;
    }
    return _isAdminRole || _manageableOrganizations.isNotEmpty;
  }

  Future<void> _loadInitialData() async {
    await _loadManageableOrganizations();
    await Future.wait(<Future<void>>[
      _loadJobs(),
      _loadCouriers(),
    ]);
  }

  Future<void> _loadManageableOrganizations() async {
    try {
      final List<OrganizationModel> organizations = await widget
          .dependencies.organizationRepository
          .fetchMyOrganizations();
      final List<OrganizationModel> manageable = organizations.where(
        (OrganizationModel item) {
          if (item.myStatus != OrganizationMembershipStatus.active) {
            return false;
          }
          return item.myRole == OrganizationRole.owner ||
              item.myRole == OrganizationRole.manager;
        },
      ).toList();

      if (!mounted) {
        return;
      }
      setState(() {
        _manageableOrganizations = manageable;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _manageableOrganizations = <OrganizationModel>[];
      });
    }
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoadingJobs = true;
      _jobsError = null;
    });

    try {
      final List<JobPostModel> jobs =
          await widget.dependencies.jobRepository.fetchOpenJobs(
        query: _jobSearchController.text,
        city: _jobCityController.text,
      );
      final Set<String> appliedIds =
          (await widget.dependencies.jobRepository.fetchMyApplications())
              .map((item) => item.jobId)
              .toSet();

      if (!mounted) {
        return;
      }
      setState(() {
        _jobs = jobs;
        _appliedJobIds = appliedIds;
        _isLoadingJobs = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingJobs = false;
        _jobsError = ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Is ilanlari yuklenemedi.',
        );
      });
    }
  }

  Future<void> _loadCouriers() async {
    setState(() {
      _isLoadingCouriers = true;
      _couriersError = null;
    });

    try {
      final List<CourierProfileModel> couriers =
          await widget.dependencies.jobRepository.searchCouriers(
        query: _courierSearchController.text,
        city: _courierCityController.text,
        vehicleType: _courierVehicleFilter == JobVehicleType.any
            ? null
            : _courierVehicleFilter,
      );
      final CourierProfileModel? myProfile =
          await widget.dependencies.jobRepository.fetchMyCourierProfile();

      if (!mounted) {
        return;
      }
      setState(() {
        _couriers = couriers;
        _myCourierProfile = myProfile;
        _isLoadingCouriers = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingCouriers = false;
        _couriersError = ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Kurye profilleri yuklenemedi.',
        );
      });
    }
  }

  Future<void> _applyToJob(JobPostModel job) async {
    if (_appliedJobIds.contains(job.id)) {
      _showMessage('Bu ilana zaten basvuru yaptiniz.');
      return;
    }

    final String? note = await _promptApplicationNote();
    if (note == _cancelApplicationToken) {
      return;
    }

    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.jobRepository.applyToJob(
        jobId: job.id,
        note: note?.trim().isEmpty ?? true ? null : note,
      );
      await _loadJobs();
      _showMessage('Basvurunuz alindi.');
    } catch (error) {
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Basvuru gonderilemedi.',
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

  Future<String?> _promptApplicationNote() async {
    final TextEditingController noteController = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Basvuru Notu'),
          content: TextField(
            controller: noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Opsiyonel not',
              hintText: 'Calisma saatleri veya deneyim bilgisi ekleyin',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_cancelApplicationToken),
              child: const Text('Vazgec'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(noteController.text),
              child: const Text('Gonder'),
            ),
          ],
        );
      },
    );
    noteController.dispose();
    return result?.trim();
  }

  Future<void> _createJob() async {
    if (!_canCreateJob) {
      _showMessage('Is ilani olusturma yetkiniz bulunmuyor.');
      return;
    }

    final _JobCreatePayload? payload = await _promptCreateJobPayload();
    if (payload == null) {
      return;
    }

    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.jobRepository.createJob(
        organizationId: payload.organizationId,
        title: payload.title,
        description: payload.description,
        city: payload.city,
        district: payload.district,
        employmentType: payload.employmentType,
        vehicleType: payload.vehicleType,
        salaryMin: payload.salaryMin,
        salaryMax: payload.salaryMax,
        contactPhone: payload.contactPhone,
      );
      await _loadJobs();
      _showMessage('Is ilani olusturuldu.');
    } catch (error) {
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Is ilani olusturulamadi.',
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

  Future<_JobCreatePayload?> _promptCreateJobPayload() async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController cityController = TextEditingController();
    final TextEditingController districtController = TextEditingController();
    final TextEditingController salaryMinController = TextEditingController();
    final TextEditingController salaryMaxController = TextEditingController();
    final TextEditingController contactPhoneController =
        TextEditingController();

    JobEmploymentType selectedEmploymentType = JobEmploymentType.fullTime;
    JobVehicleType selectedVehicleType = JobVehicleType.motorcycle;
    String? selectedOrganizationId = _manageableOrganizations.isNotEmpty
        ? _manageableOrganizations.first.id
        : null;
    String? validationError;

    final _JobCreatePayload? payload = await showDialog<_JobCreatePayload>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Is Ilani Olustur'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_isAdminRole || _manageableOrganizations.isNotEmpty)
                        DropdownButtonFormField<String?>(
                          initialValue: selectedOrganizationId,
                          decoration: const InputDecoration(
                            labelText: 'Organizasyon',
                          ),
                          items: <DropdownMenuItem<String?>>[
                            if (_isAdminRole)
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Dernek Genel Ilani'),
                              ),
                            ..._manageableOrganizations.map(
                              (OrganizationModel item) =>
                                  DropdownMenuItem<String?>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            ),
                          ],
                          onChanged: (String? value) {
                            setDialogState(() {
                              selectedOrganizationId = value;
                              validationError = null;
                            });
                          },
                        ),
                      TextFormField(
                        controller: titleController,
                        validator: (String? value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Baslik zorunludur.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Ilan Basligi',
                        ),
                      ),
                      TextFormField(
                        controller: descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        validator: (String? value) {
                          if ((value ?? '').trim().length < 10) {
                            return 'Aciklama en az 10 karakter olmali.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Aciklama',
                        ),
                      ),
                      TextFormField(
                        controller: cityController,
                        validator: (String? value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Sehir bilgisi zorunludur.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Sehir',
                        ),
                      ),
                      TextFormField(
                        controller: districtController,
                        decoration: const InputDecoration(
                          labelText: 'Ilce (opsiyonel)',
                        ),
                      ),
                      DropdownButtonFormField<JobEmploymentType>(
                        initialValue: selectedEmploymentType,
                        decoration: const InputDecoration(
                          labelText: 'Calisma Tipi',
                        ),
                        items: JobEmploymentType.values
                            .map(
                              (JobEmploymentType type) =>
                                  DropdownMenuItem<JobEmploymentType>(
                                value: type,
                                child: Text(type.label),
                              ),
                            )
                            .toList(),
                        onChanged: (JobEmploymentType? value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            selectedEmploymentType = value;
                          });
                        },
                      ),
                      DropdownButtonFormField<JobVehicleType>(
                        initialValue: selectedVehicleType,
                        decoration: const InputDecoration(
                          labelText: 'Arac Tipi',
                        ),
                        items: JobVehicleType.values
                            .where((JobVehicleType type) =>
                                type != JobVehicleType.any)
                            .map(
                              (JobVehicleType type) =>
                                  DropdownMenuItem<JobVehicleType>(
                                value: type,
                                child: Text(type.label),
                              ),
                            )
                            .toList(),
                        onChanged: (JobVehicleType? value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            selectedVehicleType = value;
                          });
                        },
                      ),
                      TextFormField(
                        controller: salaryMinController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min Ucret (TL, opsiyonel)',
                        ),
                      ),
                      TextFormField(
                        controller: salaryMaxController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Ucret (TL, opsiyonel)',
                        ),
                      ),
                      TextFormField(
                        controller: contactPhoneController,
                        keyboardType: TextInputType.phone,
                        validator: (String? value) {
                          if ((value ?? '').trim().isEmpty) {
                            return null;
                          }
                          return FormValidators.phone(value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Iletisim Telefonu (opsiyonel)',
                          hintText: '05XXXXXXXXX',
                        ),
                      ),
                      if (validationError != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          validationError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Vazgec'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    if (!_isAdminRole && selectedOrganizationId == null) {
                      setDialogState(() {
                        validationError = 'Organizasyon secimi zorunludur.';
                      });
                      return;
                    }

                    final double? salaryMin = _parseSalary(
                      salaryMinController.text,
                    );
                    final double? salaryMax = _parseSalary(
                      salaryMaxController.text,
                    );

                    if (salaryMin != null &&
                        salaryMax != null &&
                        salaryMax < salaryMin) {
                      setDialogState(() {
                        validationError =
                            'Max ucret min ucretten kucuk olamaz.';
                      });
                      return;
                    }

                    Navigator.of(context).pop(
                      _JobCreatePayload(
                        organizationId: selectedOrganizationId,
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        city: cityController.text.trim(),
                        district: districtController.text.trim(),
                        employmentType: selectedEmploymentType,
                        vehicleType: selectedVehicleType,
                        salaryMin: salaryMin,
                        salaryMax: salaryMax,
                        contactPhone: contactPhoneController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Olustur'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    cityController.dispose();
    districtController.dispose();
    salaryMinController.dispose();
    salaryMaxController.dispose();
    contactPhoneController.dispose();
    return payload;
  }

  Future<void> _editMyCourierProfile() async {
    final _CourierProfilePayload? payload =
        await _promptCourierProfilePayload();
    if (payload == null) {
      return;
    }

    setState(() {
      _isWorking = true;
    });
    try {
      await widget.dependencies.jobRepository.upsertMyCourierProfile(
        headline: payload.headline,
        bio: payload.bio,
        city: payload.city,
        district: payload.district,
        vehicleType: payload.vehicleType,
        yearsExperience: payload.yearsExperience,
        isAvailable: payload.isAvailable,
      );
      await _loadCouriers();
      _showMessage('Kurye profiliniz guncellendi.');
    } catch (error) {
      _showMessage(
        ErrorMessageMapper.toFriendlyTurkish(
          error,
          fallback: 'Kurye profili guncellenemedi.',
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

  Future<_CourierProfilePayload?> _promptCourierProfilePayload() async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController headlineController = TextEditingController(
      text: _myCourierProfile?.headline ?? '',
    );
    final TextEditingController bioController = TextEditingController(
      text: _myCourierProfile?.bio ?? '',
    );
    final TextEditingController cityController = TextEditingController(
      text: _myCourierProfile?.city ?? '',
    );
    final TextEditingController districtController = TextEditingController(
      text: _myCourierProfile?.district ?? '',
    );
    final TextEditingController yearsController = TextEditingController(
      text: (_myCourierProfile?.yearsExperience ?? 0).toString(),
    );

    JobVehicleType selectedVehicleType =
        _myCourierProfile?.vehicleType ?? JobVehicleType.motorcycle;
    bool isAvailable = _myCourierProfile?.isAvailable ?? true;

    final _CourierProfilePayload? payload =
        await showDialog<_CourierProfilePayload>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Kurye Profili'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: headlineController,
                        decoration: const InputDecoration(
                          labelText: 'Kisa Baslik',
                          hintText: 'Orn: A2 ehliyetli tecrubeli kurye',
                        ),
                      ),
                      TextFormField(
                        controller: bioController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Aciklama',
                        ),
                      ),
                      TextFormField(
                        controller: cityController,
                        decoration: const InputDecoration(
                          labelText: 'Sehir',
                        ),
                      ),
                      TextFormField(
                        controller: districtController,
                        decoration: const InputDecoration(
                          labelText: 'Ilce',
                        ),
                      ),
                      DropdownButtonFormField<JobVehicleType>(
                        initialValue: selectedVehicleType,
                        decoration: const InputDecoration(
                          labelText: 'Arac Tipi',
                        ),
                        items: JobVehicleType.values
                            .where((JobVehicleType type) =>
                                type != JobVehicleType.any)
                            .map(
                              (JobVehicleType type) =>
                                  DropdownMenuItem<JobVehicleType>(
                                value: type,
                                child: Text(type.label),
                              ),
                            )
                            .toList(),
                        onChanged: (JobVehicleType? value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            selectedVehicleType = value;
                          });
                        },
                      ),
                      TextFormField(
                        controller: yearsController,
                        keyboardType: TextInputType.number,
                        validator: (String? value) {
                          final int? parsed =
                              int.tryParse((value ?? '').trim());
                          if (parsed == null || parsed < 0) {
                            return 'Deneyim yilini 0 veya daha buyuk giriniz.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Deneyim (yil)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isAvailable,
                        onChanged: (bool value) {
                          setDialogState(() {
                            isAvailable = value;
                          });
                        },
                        title: const Text('Is teklifine acigim'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Vazgec'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    Navigator.of(context).pop(
                      _CourierProfilePayload(
                        headline: headlineController.text.trim(),
                        bio: bioController.text.trim(),
                        city: cityController.text.trim(),
                        district: districtController.text.trim(),
                        vehicleType: selectedVehicleType,
                        yearsExperience: int.parse(yearsController.text.trim()),
                        isAvailable: isAvailable,
                      ),
                    );
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    headlineController.dispose();
    bioController.dispose();
    cityController.dispose();
    districtController.dispose();
    yearsController.dispose();
    return payload;
  }

  double? _parseSalary(String raw) {
    final String cleaned = raw.replaceAll(',', '.').trim();
    if (cleaned.isEmpty) {
      return null;
    }
    return double.tryParse(cleaned);
  }

  void _showJobDetail(JobPostModel job) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(job.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if ((job.organizationName ?? '').isNotEmpty)
                  Text('Isveren: ${job.organizationName}'),
                Text(
                  'Konum: ${job.city}${job.district == null ? '' : ' / ${job.district}'}',
                ),
                Text('Calisma: ${job.employmentType.label}'),
                Text('Arac: ${job.vehicleType.label}'),
                Text('Ucret: ${job.salaryLabel}'),
                if (job.contactPhone != null)
                  Text('Iletisim: ${job.contactPhone}'),
                if (job.expiresAt != null)
                  Text('Son Tarih: ${DateTimeFormatter.date(job.expiresAt!)}'),
                const SizedBox(height: 12),
                Text(job.description),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Is Pazari'),
          bottom: const TabBar(
            tabs: <Tab>[
              Tab(icon: Icon(Icons.work_outline), text: 'Is Bul'),
              Tab(icon: Icon(Icons.people_outline), text: 'Kurye Ara'),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Yenile',
              onPressed: _isWorking
                  ? null
                  : () async {
                      await _loadInitialData();
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: TabBarView(
          children: <Widget>[
            _buildJobsTab(),
            _buildCouriersTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsTab() {
    if (_isLoadingJobs) {
      return const LoadingStateView(message: 'Is ilanlari yukleniyor...');
    }

    if (_jobsError != null) {
      return ErrorStateView(
        title: 'Hata',
        message: _jobsError!,
        onRetry: _loadJobs,
      );
    }

    if (_jobs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildJobsFilters(),
          if (_canCreateJob) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isWorking ? null : _createJob,
                icon: const Icon(Icons.add),
                label: const Text('Ilan Ver'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const EmptyStateView(
            title: 'Ilan Bulunamadi',
            message: 'Filtreye uygun aktif is ilani bulunmuyor.',
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJobs,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildJobsFilters(),
          if (_canCreateJob) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isWorking ? null : _createJob,
                icon: const Icon(Icons.add),
                label: const Text('Ilan Ver'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ..._jobs.map((JobPostModel job) {
            final bool applied = _appliedJobIds.contains(job.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(job.organizationName ?? 'Dernek Ilani'),
                    Text(
                      '${job.city}${job.district == null ? '' : ' / ${job.district}'}',
                    ),
                    Text(
                        '${job.employmentType.label} - ${job.vehicleType.label}'),
                    Text('Ucret: ${job.salaryLabel}'),
                    if (job.expiresAt != null)
                      Text(
                        'Son Tarih: ${DateTimeFormatter.date(job.expiresAt!)}',
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        OutlinedButton(
                          onPressed: () => _showJobDetail(job),
                          child: const Text('Detay'),
                        ),
                        ElevatedButton(
                          onPressed: applied || _isWorking
                              ? null
                              : () => _applyToJob(job),
                          child: Text(applied ? 'Basvuruldu' : 'Basvur'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCouriersTab() {
    if (_isLoadingCouriers) {
      return const LoadingStateView(message: 'Kurye profilleri yukleniyor...');
    }

    if (_couriersError != null) {
      return ErrorStateView(
        title: 'Hata',
        message: _couriersError!,
        onRetry: _loadCouriers,
      );
    }

    if (_couriers.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildCourierFilters(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isWorking ? null : _editMyCourierProfile,
              icon: const Icon(Icons.edit),
              label: const Text('Profil Duzenle'),
            ),
          ),
          const SizedBox(height: 12),
          const EmptyStateView(
            title: 'Kurye Bulunamadi',
            message: 'Filtreye uygun acik kurye profili bulunmuyor.',
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCouriers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildCourierFilters(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isWorking ? null : _editMyCourierProfile,
              icon: const Icon(Icons.edit),
              label: const Text('Profil Duzenle'),
            ),
          ),
          const SizedBox(height: 12),
          if (_myCourierProfile != null)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: const Color(0xFFF8F4F4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Profil Durumunuz: ${_myCourierProfile!.isAvailable ? 'Acil' : 'Kapali'}',
                ),
              ),
            ),
          ..._couriers.map((CourierProfileModel profile) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      profile.fullName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if ((profile.headline ?? '').isNotEmpty)
                      Text(profile.headline!),
                    if ((profile.city ?? '').isNotEmpty)
                      Text(
                        'Konum: ${profile.city}${profile.district == null ? '' : ' / ${profile.district}'}',
                      ),
                    Text('Arac: ${profile.vehicleType.label}'),
                    Text('Deneyim: ${profile.yearsExperience} yil'),
                    if (profile.phone.trim().isNotEmpty)
                      Text('Telefon: ${profile.phone}'),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildJobsFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _jobSearchController,
              decoration: const InputDecoration(
                labelText: 'Ilan Ara',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _loadJobs(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _jobCityController,
              decoration: const InputDecoration(
                labelText: 'Sehir/Ilce',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              onSubmitted: (_) => _loadJobs(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isLoadingJobs ? null : _loadJobs,
                icon: const Icon(Icons.filter_alt_outlined),
                label: const Text('Filtrele'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourierFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _courierSearchController,
              decoration: const InputDecoration(
                labelText: 'Kurye Ara',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _loadCouriers(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _courierCityController,
              decoration: const InputDecoration(
                labelText: 'Sehir/Ilce',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              onSubmitted: (_) => _loadCouriers(),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<JobVehicleType>(
              initialValue: _courierVehicleFilter,
              decoration: const InputDecoration(
                labelText: 'Arac Filtresi',
              ),
              items: JobVehicleType.values
                  .map(
                    (JobVehicleType type) => DropdownMenuItem<JobVehicleType>(
                      value: type,
                      child: Text(type.label),
                    ),
                  )
                  .toList(),
              onChanged: (JobVehicleType? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _courierVehicleFilter = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isLoadingCouriers ? null : _loadCouriers,
                icon: const Icon(Icons.filter_alt_outlined),
                label: const Text('Filtrele'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCreatePayload {
  const _JobCreatePayload({
    required this.organizationId,
    required this.title,
    required this.description,
    required this.city,
    required this.district,
    required this.employmentType,
    required this.vehicleType,
    required this.salaryMin,
    required this.salaryMax,
    required this.contactPhone,
  });

  final String? organizationId;
  final String title;
  final String description;
  final String city;
  final String? district;
  final JobEmploymentType employmentType;
  final JobVehicleType vehicleType;
  final double? salaryMin;
  final double? salaryMax;
  final String? contactPhone;
}

class _CourierProfilePayload {
  const _CourierProfilePayload({
    required this.headline,
    required this.bio,
    required this.city,
    required this.district,
    required this.vehicleType,
    required this.yearsExperience,
    required this.isAvailable,
  });

  final String? headline;
  final String? bio;
  final String? city;
  final String? district;
  final JobVehicleType vehicleType;
  final int yearsExperience;
  final bool isAvailable;
}
