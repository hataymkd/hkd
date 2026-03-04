import 'package:hkd/features/jobs/domain/models/courier_profile_model.dart';
import 'package:hkd/features/jobs/domain/models/job_application_model.dart';
import 'package:hkd/features/jobs/domain/models/job_post_model.dart';

abstract class JobRepository {
  Future<List<JobPostModel>> fetchOpenJobs({
    String? query,
    String? city,
  });

  Future<JobPostModel?> fetchJobById(String jobId);

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
  });

  Future<void> updateJobStatus({
    required String jobId,
    required JobPostStatus status,
  });

  Future<List<JobApplicationModel>> fetchMyApplications();

  Future<void> applyToJob({
    required String jobId,
    String? note,
  });

  Future<List<CourierProfileModel>> searchCouriers({
    String? query,
    String? city,
    JobVehicleType? vehicleType,
  });

  Future<CourierProfileModel?> fetchMyCourierProfile();

  Future<void> upsertMyCourierProfile({
    String? headline,
    String? bio,
    String? city,
    String? district,
    required JobVehicleType vehicleType,
    required int yearsExperience,
    required bool isAvailable,
  });
}
