class InviteAcceptResultModel {
  const InviteAcceptResultModel({
    required this.ok,
    required this.status,
    this.userId,
  });

  final bool ok;
  final String status;
  final String? userId;
}
