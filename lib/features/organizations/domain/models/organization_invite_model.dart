class OrganizationInviteModel {
  const OrganizationInviteModel({
    required this.id,
    required this.orgId,
    required this.phone,
    required this.token,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.inviteUrl,
    this.acceptedUserId,
    this.acceptedAt,
  });

  final String id;
  final String orgId;
  final String phone;
  final String token;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String? inviteUrl;
  final String? acceptedUserId;
  final DateTime? acceptedAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
}
