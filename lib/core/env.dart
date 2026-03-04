enum AppEnvironment {
  dev,
  prod,
}

class Env {
  static const String appEnvRaw = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String updateManifestUrl = String.fromEnvironment(
    'HKD_UPDATE_MANIFEST_URL',
    defaultValue: '',
  );

  static AppEnvironment get appEnvironment {
    switch (appEnvRaw.toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      default:
        return AppEnvironment.dev;
    }
  }

  static bool get isProd => appEnvironment == AppEnvironment.prod;

  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static bool get hasUpdateManifestUrl => updateManifestUrl.trim().isNotEmpty;

  static void validate() {
    if (!isConfigured) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY are required. '
        'Provide them via --dart-define.',
      );
    }
  }
}
