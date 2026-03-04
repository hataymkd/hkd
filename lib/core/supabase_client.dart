import 'package:hkd/core/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabaseClient {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) {
      return;
    }

    Env.validate();

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );

    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
