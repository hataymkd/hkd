import 'package:flutter/material.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/utils/date_time_formatter.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/auth/domain/models/user_role.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final UserModel? currentUser = dependencies.sessionController.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Oturum bulunamadi.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: CircleAvatar(
                    radius: 34,
                    child: Text(
                      currentUser.name.substring(0, 1),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _ProfileRow(label: 'Uye No', value: currentUser.id),
                _ProfileRow(label: 'Ad Soyad', value: currentUser.name),
                _ProfileRow(label: 'Telefon', value: currentUser.phone),
                _ProfileRow(label: 'Rol', value: currentUser.role.label),
                _ProfileRow(
                  label: 'Durum',
                  value: currentUser.isActive ? 'Aktif' : 'Pasif',
                ),
                _ProfileRow(
                  label: 'Kayit Tarihi',
                  value: DateTimeFormatter.date(currentUser.createdAt),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
