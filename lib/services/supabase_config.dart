class SupabaseConfig {
  const SupabaseConfig({
    this.url = const String.fromEnvironment('SUPABASE_URL'),
    this.anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY'),
    this.dataMode = const String.fromEnvironment(
      'DATA_MODE',
      defaultValue: 'local',
    ),
  });

  static const defaultConfig = SupabaseConfig();

  final String url;
  final String anonKey;
  final String dataMode;

  bool get isConfigured =>
      url.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  bool get wantsSupabase => dataMode.trim().toLowerCase() == 'supabase';

  bool get shouldUseSupabase => wantsSupabase && isConfigured;
}
