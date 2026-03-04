enum JobApplicationStatus {
  pending,
  shortlisted,
  rejected,
  hired,
  withdrawn,
}

extension JobApplicationStatusX on JobApplicationStatus {
  String get dbKey {
    switch (this) {
      case JobApplicationStatus.pending:
        return 'pending';
      case JobApplicationStatus.shortlisted:
        return 'shortlisted';
      case JobApplicationStatus.rejected:
        return 'rejected';
      case JobApplicationStatus.hired:
        return 'hired';
      case JobApplicationStatus.withdrawn:
        return 'withdrawn';
    }
  }

  String get label {
    switch (this) {
      case JobApplicationStatus.pending:
        return 'Bekliyor';
      case JobApplicationStatus.shortlisted:
        return 'On Liste';
      case JobApplicationStatus.rejected:
        return 'Reddedildi';
      case JobApplicationStatus.hired:
        return 'Ise Alindi';
      case JobApplicationStatus.withdrawn:
        return 'Geri Cekildi';
    }
  }
}

JobApplicationStatus parseJobApplicationStatus(String? raw) {
  switch (raw) {
    case 'shortlisted':
      return JobApplicationStatus.shortlisted;
    case 'rejected':
      return JobApplicationStatus.rejected;
    case 'hired':
      return JobApplicationStatus.hired;
    case 'withdrawn':
      return JobApplicationStatus.withdrawn;
    default:
      return JobApplicationStatus.pending;
  }
}

class JobApplicationModel {
  const JobApplicationModel({
    required this.id,
    required this.jobId,
    required this.applicantUserId,
    required this.status,
    required this.createdAt,
    this.note,
    this.reviewedBy,
    this.reviewedAt,
    this.jobTitle,
    this.organizationName,
  });

  final String id;
  final String jobId;
  final String applicantUserId;
  final String? note;
  final JobApplicationStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final String? jobTitle;
  final String? organizationName;
}
