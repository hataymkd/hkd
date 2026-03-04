import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hkd/core/navigation/app_deep_link_service.dart';
import 'package:hkd/core/supabase_client.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  await AppSupabaseClient.init();
  await AppDeepLinkService.instance.initialize();
  runApp(const HKDApp());
}
