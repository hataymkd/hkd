import 'package:hkd/features/auth/domain/models/user_role.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
