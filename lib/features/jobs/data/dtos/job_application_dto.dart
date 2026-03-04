import 'package:hkd/features/jobs/domain/models/job_application_model.dart';

class JobApplicationDto {
  const JobApplicationDto({
    required this.id,
    required this.jobId,
    required this.applicantUserId,
    required this.note,
    required this.status,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.createdAt,
    required this.jobTitle,
    required this.organizationName,
  });

  final String id;
  final String jobId;
  final String applicantUserId;
  final String? note;
  final String status;
  final String? reviewedBy;
  final String? reviewedAt;
  final String createdAt;
  final String? jobTitle;
  final String? organizationName;

  factory JobApplicationDto.fromMap(Map<String, dynamic> map) {
    final dynamic jobRaw = map['job_posts'];
    String? jobTitle;
    String? organizationName;
    if (jobRaw is Map) {
      jobTitle = jobRaw['title'] as String?;
      final dynamic orgRaw = jobRaw['organizations'];
      if (orgRaw is Map) {
        organizationName = orgRaw['name'] as String?;
      }
    }

    return JobApplicationDto(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      applicantUserId: map['applicant_user_id'] as String,
      note: map['note'] as String?,
      status: (map['status'] as String?) ?? 'pending',
      reviewedBy: map['reviewed_by'] as String?,
      reviewedAt: map['reviewed_at'] as String?,
      createdAt: map['created_at'] as String,
      jobTitle: jobTitle,
      organizationName: organizationName,
    );
  }
}

extension JobApplicationDtoMapper on JobApplicationDto {
  JobApplicationModel toDomain() {
    return JobApplicationModel(
      id: id,
      jobId: jobId,
      applicantUserId: applicantUserId,
      note: note?.trim(),
      status: parseJobApplicationStatus(status),
      reviewedBy: reviewedBy,
      reviewedAt: reviewedAt == null ? null : DateTime.parse(reviewedAt!),
      createdAt: DateTime.parse(createdAt),
      jobTitle: jobTitle?.trim(),
      organizationName: organizationName?.trim(),
    );
  }
}
