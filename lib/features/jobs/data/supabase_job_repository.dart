import 'dart:collection';

import 'package:hkd/features/jobs/data/dtos/courier_profile_dto.dart';
import 'package:hkd/features/jobs/data/dtos/job_application_dto.dart';
import 'package:hkd/features/jobs/data/dtos/job_post_dto.dart';
import 'package:hkd/features/jobs/domain/models/courier_profile_model.dart';
import 'package:hkd/features/jobs/domain/models/job_application_model.dart';
import 'package:hkd/features/jobs/domain/models/job_post_model.dart';
import 'package:hkd/features/jobs/domain/repositories/job_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseJobRepository implements JobRepository {
  SupabaseJobRepository({
    required SupabaseClient client,
  }) : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<JobPostModel>> fetchOpenJobs({
    String? query,
    String? city,
  }) async {
    final dynamic raw = await _client
        .from('job_posts')
        .select(
          'id, org_id, created_by, title, description, city, district, '
          'employment_type, vehicle_type, salary_min, salary_max, currency, '
          'status, contact_phone, expires_at, created_at, updated_at, '
          'organizations(name)',
        )
        .eq('status', 'open')
        .order('created_at', ascending: false);

    final List<JobPostModel> items = (raw as List<dynamic>)
        .map(
          (dynamic item) =>
              JobPostDto.fromMap((item as Map).cast<String, dynamic>())
                  .toDomain(),
        )
        .toList();

    final String normalizedQuery = _normalize(query);
    final String normalizedCity = _normalize(city);

    final Iterable<JobPostModel> filtered = items.where((JobPostModel item) {
      if (normalizedCity.isNotEmpty) {
        final String cityPayload = _normalize('${item.city} ${item.district}');
        if (!cityPayload.contains(normalizedCity)) {
          return false;
        }
      }

      if (normalizedQuery.isNotEmpty) {
        final String payload = _normalize(
          '${item.title} ${item.description} ${item.city} '
          '${item.district ?? ''} ${item.organizationName ?? ''}',
        );
        if (!payload.contains(normalizedQuery)) {
          return false;
        }
      }

      return true;
    });

    return List<JobPostModel>.unmodifiable(filtered.toList());
  }

  @override
  Future<JobPostModel?> fetchJobById(String jobId) async {
    final dynamic raw = await _client
        .from('job_posts')
        .select(
          'id, org_id, created_by, title, description, city, district, '
          'employment_type, vehicle_type, salary_min, salary_max, currency, '
          'status, contact_phone, expires_at, created_at, updated_at, '
          'organizations(name)',
        )
        .eq('id', jobId)
        .maybeSingle();

    if (raw == null) {
      return null;
    }

    return JobPostDto.fromMap((raw as Map).cast<String, dynamic>()).toDomain();
  }

  @override
  Future<void> createJob({
    String? organizationId,
    required String title,
    required String description,
    required String city,
    String? district,
    JobEmploymentType employmentType = JobEmploymentType.fullTime,
    JobVehicleType vehicleType = JobVehicleType.motorcycle,
    double? salaryMin,
    double? salaryMax,
    String? contactPhone,
    DateTime? expiresAt,
  }) async {
    final String userId = _requireCurrentUserId();
    await _client.from('job_posts').insert(
      <String, dynamic>{
        'org_id': organizationId,
        'created_by': userId,
        'title': title.trim(),
        'description': description.trim(),
        'city': city.trim(),
        'district': _nullableTrim(district),
        'employment_type': employmentType.dbKey,
        'vehicle_type': vehicleType.dbKey,
        'salary_min': salaryMin,
        'salary_max': salaryMax,
        'currency': 'TRY',
        'status': 'open',
        'contact_phone': _normalizePhone(contactPhone),
        'expires_at': expiresAt?.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<void> updateJobStatus({
    required String jobId,
    required JobPostStatus status,
  }) async {
    await _client.from('job_posts').update(
      <String, dynamic>{
        'status': status.dbKey,
      },
    ).eq('id', jobId);
  }

  @override
  Future<List<JobApplicationModel>> fetchMyApplications() async {
    final String userId = _requireCurrentUserId();
    final dynamic raw = await _client
        .from('job_applications')
        .select(
          'id, job_id, applicant_user_id, note, status, reviewed_by, '
          'reviewed_at, created_at, '
          'job_posts!inner(title, organizations(name))',
        )
        .eq('applicant_user_id', userId)
        .order('created_at', ascending: false);

    final List<JobApplicationModel> items = (raw as List<dynamic>)
        .map(
          (dynamic item) =>
              JobApplicationDto.fromMap((item as Map).cast<String, dynamic>())
                  .toDomain(),
        )
        .toList();
    return List<JobApplicationModel>.unmodifiable(items);
  }

  @override
  Future<void> applyToJob({
    required String jobId,
    String? note,
  }) async {
    final String userId = _requireCurrentUserId();
    await _client.from('job_applications').insert(
      <String, dynamic>{
        'job_id': jobId,
        'applicant_user_id': userId,
        'note': _nullableTrim(note),
        'status': 'pending',
        'reviewed_by': null,
        'reviewed_at': null,
      },
    );
  }

  @override
  Future<List<CourierProfileModel>> searchCouriers({
    String? query,
    String? city,
    JobVehicleType? vehicleType,
  }) async {
    dynamic request = _client.from('courier_profiles').select(
          'user_id, headline, bio, city, district, vehicle_type, '
          'years_experience, is_available, created_at, updated_at, '
          'profiles!inner(full_name, phone)',
        );
    request = request.eq('is_available', true);
    if (vehicleType != null && vehicleType != JobVehicleType.any) {
      request = request.eq('vehicle_type', vehicleType.dbKey);
    }

    final dynamic raw = await request.order('updated_at', ascending: false);
    final List<CourierProfileModel> items = (raw as List<dynamic>)
        .map(
          (dynamic item) =>
              CourierProfileDto.fromMap((item as Map).cast<String, dynamic>())
                  .toDomain(),
        )
        .toList();

    final String normalizedQuery = _normalize(query);
    final String normalizedCity = _normalize(city);

    final Iterable<CourierProfileModel> filtered =
        items.where((CourierProfileModel item) {
      if (normalizedCity.isNotEmpty) {
        final String cityPayload = _normalize('${item.city} ${item.district}');
        if (!cityPayload.contains(normalizedCity)) {
          return false;
        }
      }

      if (normalizedQuery.isNotEmpty) {
        final String payload = _normalize(
          '${item.fullName} ${item.headline ?? ''} ${item.bio ?? ''} '
          '${item.city ?? ''} ${item.district ?? ''} ${item.phone}',
        );
        if (!payload.contains(normalizedQuery)) {
          return false;
        }
      }

      return true;
    });

    return UnmodifiableListView<CourierProfileModel>(filtered);
  }

  @override
  Future<CourierProfileModel?> fetchMyCourierProfile() async {
    final String userId = _requireCurrentUserId();
    final dynamic raw = await _client
        .from('courier_profiles')
        .select(
          'user_id, headline, bio, city, district, vehicle_type, '
          'years_experience, is_available, created_at, updated_at, '
          'profiles!inner(full_name, phone)',
        )
        .eq('user_id', userId)
        .maybeSingle();

    if (raw == null) {
      return null;
    }

    return CourierProfileDto.fromMap((raw as Map).cast<String, dynamic>())
        .toDomain();
  }

  @override
  Future<void> upsertMyCourierProfile({
    String? headline,
    String? bio,
    String? city,
    String? district,
    required JobVehicleType vehicleType,
    required int yearsExperience,
    required bool isAvailable,
  }) async {
    final String userId = _requireCurrentUserId();
    await _client.from('courier_profiles').upsert(
      <String, dynamic>{
        'user_id': userId,
        'headline': _nullableTrim(headline),
        'bio': _nullableTrim(bio),
        'city': _nullableTrim(city),
        'district': _nullableTrim(district),
        'vehicle_type': vehicleType.dbKey,
        'years_experience': yearsExperience < 0 ? 0 : yearsExperience,
        'is_available': isAvailable,
      },
      onConflict: 'user_id',
    );
  }

  String _requireCurrentUserId() {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('Oturum bulunamadi. Lutfen yeniden giris yapin.');
    }
    return userId;
  }

  String _normalize(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  String? _nullableTrim(String? value) {
    final String cleaned = (value ?? '').trim();
    if (cleaned.isEmpty) {
      return null;
    }
    return cleaned;
  }

  String? _normalizePhone(String? rawPhone) {
    final String cleaned = _nullableTrim(rawPhone) ?? '';
    if (cleaned.isEmpty) {
      return null;
    }
    final String value = cleaned.replaceAll(RegExp(r'\s+'), '');
    if (value.startsWith('+')) {
      return value;
    }
    if (value.startsWith('0') && value.length == 11) {
      return '+90${value.substring(1)}';
    }
    return value;
  }
}
