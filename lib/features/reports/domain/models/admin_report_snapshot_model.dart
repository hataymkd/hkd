class AdminReportSnapshotModel {
  const AdminReportSnapshotModel({
    required this.generatedAt,
    required this.activeUsers,
    required this.pendingUsers,
    required this.totalOrganizations,
    required this.pendingApplications,
    required this.openJobs,
    required this.pendingInvoices,
    required this.overdueInvoices,
    required this.totalDueAmount,
    required this.outstandingAmount,
    required this.unreadNotifications,
  });

  final DateTime generatedAt;
  final int activeUsers;
  final int pendingUsers;
  final int totalOrganizations;
  final int pendingApplications;
  final int openJobs;
  final int pendingInvoices;
  final int overdueInvoices;
  final double totalDueAmount;
  final double outstandingAmount;
  final int unreadNotifications;

  factory AdminReportSnapshotModel.empty() {
    return AdminReportSnapshotModel(
      generatedAt: DateTime.now(),
      activeUsers: 0,
      pendingUsers: 0,
      totalOrganizations: 0,
      pendingApplications: 0,
      openJobs: 0,
      pendingInvoices: 0,
      overdueInvoices: 0,
      totalDueAmount: 0,
      outstandingAmount: 0,
      unreadNotifications: 0,
    );
  }
}
