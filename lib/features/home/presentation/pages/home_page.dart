import 'package:flutter/material.dart';
import 'package:hkd/core/authorization/app_permission.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/navigation/app_routes.dart';
import 'package:hkd/core/widgets/error_state_view.dart';
import 'package:hkd/features/auth/domain/models/user_model.dart';
import 'package:hkd/features/auth/domain/models/user_role.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final UserModel? currentUser = dependencies.sessionController.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: ErrorStateView(
          title: 'Oturum Bulunamadi',
          message: 'Lutfen yeniden giris yapin.',
        ),
      );
    }

    final List<_DashboardItem> items = _buildDashboardItems(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HAMOKDER Ana Sayfa'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Bildirimler',
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.notifications);
            },
          ),
          IconButton(
            tooltip: 'Cikis',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await dependencies.sessionController.logout();
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login,
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int crossAxisCount = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 600
                    ? 2
                    : 1;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Hos geldiniz, ${currentUser.name}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text('Rol: ${currentUser.role.label}'),
                        const SizedBox(height: 6),
                        Text(
                          currentUser.isActive
                              ? 'Durum: Aktif uye'
                              : 'Durum: Pasif uye',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: crossAxisCount == 1 ? 3.5 : 1.35,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final _DashboardItem item = items[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: item.onTap,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(item.icon, size: 28),
                              const SizedBox(height: 10),
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(item.subtitle),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<_DashboardItem> _buildDashboardItems(BuildContext context) {
    final UserModel currentUser = dependencies.sessionController.currentUser!;

    final List<_DashboardItem> items = <_DashboardItem>[
      _DashboardItem(
        title: 'Duyurular',
        subtitle: 'Tum duyurulari goruntuleyin',
        icon: Icons.campaign,
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.announcements);
        },
      ),
      _DashboardItem(
        title: 'Etkinlikler',
        subtitle: 'Toplanti ve etkinlik takvimi',
        icon: Icons.event,
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.events);
        },
      ),
      _DashboardItem(
        title: 'Profil',
        subtitle: 'Kisisel bilgilerinizi gorun',
        icon: Icons.person,
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.profile);
        },
      ),
      _DashboardItem(
        title: 'Aidat Durumu',
        subtitle: 'Odeme durumunu kontrol edin',
        icon: Icons.payments,
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.paymentStatus);
        },
      ),
      _DashboardItem(
        title: 'Bildirimler',
        subtitle: 'Sistem bildirimlerinizi takip edin',
        icon: Icons.notifications_active,
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.notifications);
        },
      ),
      _DashboardItem(
        title: 'Destek Merkezi',
        subtitle: 'Talep acin veya SOS kaydi olusturun',
        icon: Icons.support_agent,
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.supportCenter);
        },
      ),
      _DashboardItem(
        title: 'Is Pazari',
        subtitle: 'Is ilanlari ve kurye havuzu',
        icon: Icons.work_outline,
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.jobsMarketplace);
        },
      ),
      _DashboardItem(
        title: 'Organizasyon',
        subtitle: 'Davet ve org uye islemleri',
        icon: Icons.apartment,
        onTap: () {
          Navigator.of(context).pushNamed(AppRoutes.organizationPanel);
        },
      ),
    ];

    if (dependencies.authorizationService.can(
      user: currentUser,
      permission: AppPermission.openManagementPanel,
    )) {
      items.add(
        _DashboardItem(
          title: 'Yonetim Paneli',
          subtitle: 'Rol bazli yonetim islemleri',
          icon: Icons.admin_panel_settings,
          onTap: () {
            Navigator.of(context).pushNamed(AppRoutes.management);
          },
        ),
      );
    }

    return items;
  }
}

class _DashboardItem {
  const _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}
