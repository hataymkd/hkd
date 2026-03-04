import 'package:flutter/material.dart';
import 'package:hkd/core/di/app_dependencies.dart';
import 'package:hkd/core/navigation/app_deep_link_service.dart';
import 'package:hkd/core/navigation/app_router.dart';
import 'package:hkd/core/navigation/app_routes.dart';
import 'package:hkd/core/theme/app_theme.dart';

class HKDApp extends StatefulWidget {
  const HKDApp({super.key});

  @override
  State<HKDApp> createState() => _HKDAppState();
}

class _HKDAppState extends State<HKDApp> {
  final AppDependencies _dependencies = AppDependencies.live();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    AppDeepLinkService.instance.attachNavigatorKey(_navigatorKey);
  }

  @override
  void dispose() {
    AppDeepLinkService.instance.detachNavigatorKey();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HAMOKDER',
      theme: AppTheme.lightTheme,
      navigatorKey: _navigatorKey,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter(dependencies: _dependencies).onGenerateRoute,
    );
  }
}
