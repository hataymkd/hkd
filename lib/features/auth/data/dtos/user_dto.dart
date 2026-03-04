import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/auth/domain/models/user_role.dart';

class UserDto {
  const UserDto({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.isActive,
    required this.createdAt,
    required this.roleKeys,
  });

  final String id;
  final String fullName;
  final String phone;
  final bool isActive;
  final String createdAt;
  final List<String> roleKeys;

  factory UserDto.fromMap(
    Map<String, dynamic> map, {
    required List<String> roleKeys,
  }) {
    return UserDto(
      id: map['id'] as String,
      fullName: (map['full_name'] as String?) ?? '',
      phone: map['phone'] as String,
      isActive: (map['is_active'] as bool?) ?? true,
      createdAt: map['created_at'] as String,
      roleKeys: roleKeys,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }
}

extension UserDtoMapper on UserDto {
  UserModel toDomain() {
    return UserModel(
      id: id,
      name: fullName.trim().isEmpty ? 'Isimsiz Uye' : fullName.trim(),
      phone: _displayPhone(phone),
      role: _parseRole(roleKeys),
      isActive: isActive,
      createdAt: DateTime.parse(createdAt),
    );
  }

  UserRole _parseRole(List<String> rawRoles) {
    if (rawRoles.contains('president')) {
      return UserRole.president;
    }
    if (rawRoles.contains('admin') || rawRoles.contains('manager')) {
      return UserRole.manager;
    }
    return UserRole.member;
  }

  String _displayPhone(String rawPhone) {
    if (rawPhone.startsWith('+90') && rawPhone.length == 13) {
      return '0${rawPhone.substring(3)}';
    }
    return rawPhone;
  }
}

extension UserModelMapper on UserModel {
  UserDto toDto() {
    return UserDto(
      id: id,
      fullName: name,
      phone: _normalizePhone(phone),
      isActive: isActive,
      createdAt: createdAt.toIso8601String(),
      roleKeys: _roleKeys(role),
    );
  }

  List<String> _roleKeys(UserRole role) {
    switch (role) {
      case UserRole.president:
        return <String>['president'];
      case UserRole.manager:
        return <String>['admin'];
      case UserRole.member:
        return <String>['member'];
    }
  }

  String _normalizePhone(String rawPhone) {
    final String value = rawPhone.replaceAll(RegExp(r'\s+'), '');
    if (value.startsWith('+')) {
      return value;
    }
    if (value.startsWith('0') && value.length == 11) {
      return '+90${value.substring(1)}';
    }
    return value;
  }
}
