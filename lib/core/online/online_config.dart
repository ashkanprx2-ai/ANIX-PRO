/// Online configuration injected at build time (never hard-coded secrets).
///
/// CI passes the public project URL + publishable (anon) key:
///   flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// Without them the app runs fully offline exactly like before.
class OnlineConfig {
  const OnlineConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String liveKitUrl =
      String.fromEnvironment('LIVEKIT_URL', defaultValue: 'wss://nexora-space-xzjzlfyl.livekit.cloud');

  /// Region of the core project. Edge Functions are pinned to it so their DB / auth calls stay in-region
  /// (otherwise the nearest edge region answers and every DB read crosses continents).
  static const String functionsRegion = String.fromEnvironment('SUPABASE_FUNCTIONS_REGION', defaultValue: 'eu-central-1');

  /// Games project (rooms, matchmaking, matches, tournaments). It trusts this app's auth JWTs (Third-Party Auth),
  /// so the same signed-in user is `auth.uid()` on both projects.
  static const String gamesUrl = String.fromEnvironment('GAMES_SUPABASE_URL');
  static const String gamesAnonKey = String.fromEnvironment('GAMES_SUPABASE_ANON_KEY');

  /// Dedicated Social Media project (profiles directory, follows, Nova Gallery feed/stories, Orbit Network DMs/calls,
  /// Social Station communities). Shares the same signed-in user JWT across projects under the organization.
  static const String socialUrl = String.fromEnvironment('SOCIAL_SUPABASE_URL');
  static const String socialAnonKey = String.fromEnvironment('SOCIAL_SUPABASE_ANON_KEY');

  /// Google "Web application" OAuth client id of the auth project (Supabase → Auth → Providers → Google → Client ID).
  /// Public by design. Native Android sign-in passes it as `serverClientId`, so Google mints an ID token whose
  /// audience is this id, which Supabase accepts in signInWithIdToken. The Android OAuth client (package
  /// com.nexora.nexora + signing SHA-1) only has to exist in the same Google Cloud project; its id is not used here.
  static const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID',
      defaultValue: '983052501224-ifvb7oamk4rs3qo9qmj1rcsg314olhu2.apps.googleusercontent.com');

  static bool get enabled => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get gamesEnabled => gamesUrl.isNotEmpty && gamesAnonKey.isNotEmpty;
  static bool get socialEnabled => socialUrl.isNotEmpty && socialAnonKey.isNotEmpty;
}
