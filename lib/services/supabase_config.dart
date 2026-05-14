class SupabaseConfig {
  const SupabaseConfig({
    this.url = const String.fromEnvironment('SUPABASE_URL'),
    this.anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY'),
  });

  static const defaultConfig = SupabaseConfig();

  final String url;
  final String anonKey;

  bool get isConfigured =>
      url.trim().isNotEmpty && anonKey.trim().isNotEmpty;
}
