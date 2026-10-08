// Build-time settings, passed with --dart-define.
class Config {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zasnnhnoyattlyioaarc.supabase.co',
  );

  // Publishable key: safe to ship in the app, access is enforced by the database.
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_IBClDZby5ZvfkUHYTOKoog_pJXYtmD4',
  );

  // Set only in the ads APK build, e.g.
  // utm_source=meta&utm_medium=paid_social&utm_campaign=apk_download
  static const apkReferrer = String.fromEnvironment('APK_REFERRER');

  static const policyVersion = 'v2';
  static const appName = 'NexVault';
  static const supportEmail = 'help.nexvault@gmail.com';
  static const website = '';
  static const maxUploadBytes = 50 * 1024 * 1024; // Supabase free plan limit

  static String publicUrl(String key) =>
      '$supabaseUrl/storage/v1/object/public/public/$key';
}
