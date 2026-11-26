import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/backend_gateway.dart';
import '../safety/install_id.dart';
import 'online_config.dart';

/// Initialise Supabase once at startup (no network needed: the session is restored from disk).
Future<void> initOnline() async {
  if (!OnlineConfig.enabled) return;
  try {
    await Supabase.initialize(url: OnlineConfig.supabaseUrl, anonKey: OnlineConfig.supabaseAnonKey);
    OnlineService._ready = true;
    // Second client for the games project: no own auth, it sends the auth project's access token.
    if (OnlineConfig.gamesEnabled) {
      OnlineService._games = SupabaseClient(
        OnlineConfig.gamesUrl,
        OnlineConfig.gamesAnonKey,
        accessToken: _freshAccessToken,
      );
    }
    // Dedicated client for the social media project (when hosted on a distinct project URL; if pointed at the same
    // URL as core auth, reuse the primary client so Realtime shares a single socket).
    if (OnlineConfig.socialEnabled && OnlineConfig.socialUrl != OnlineConfig.supabaseUrl) {
      OnlineService._social = SupabaseClient(
        OnlineConfig.socialUrl,
        OnlineConfig.socialAnonKey,
        accessToken: _freshAccessToken,
      );
    }
  } catch (e) {
    debugPrint('ANIX online init failed: $e');
  }
}

/// Access token for the games / social clients (Third-Party Auth on those projects).
///
/// The auth client refreshes its session on a timer, but after the app resumes from the background the cached token
/// can already be expired; sending it makes PostgREST answer 401 (seen live: every 401 on the games project carried an
/// expired auth-project JWT). So refresh first when the token is expired or about to expire. gotrue de-duplicates
/// concurrent refreshes, and a failed refresh falls back to the cached token (the call then fails as before).
Future<String?> _freshAccessToken() async {
  final GoTrueClient auth = Supabase.instance.client.auth;
  final Session? s = auth.currentSession;
  if (s == null) return null;
  final int? exp = s.expiresAt;
  final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if (exp != null && exp - now > 30) return s.accessToken;
  try {
    final AuthResponse r = await auth.refreshSession();
    return r.session?.accessToken ?? auth.currentSession?.accessToken ?? s.accessToken;
  } catch (e) {
    debugPrint('ANIX token refresh failed: $e');
    return auth.currentSession?.accessToken ?? s.accessToken;
  }
}

/// Auth + connection state for the whole app.
///
/// * Guest = Supabase anonymous user (created silently once the explorer identity exists).
/// * A guest can upgrade to email + password and keeps the same account (same uid, same progress).
/// * Offline / no config: [status] stays [BackendStatus.offline] and every world keeps working locally.
class OnlineService extends ChangeNotifier {
  /// The app's online service (one per app; used outside the widget tree).
  static OnlineService? current;

  OnlineService() {
    current = this;
    if (!_ready) return;
    _sub = client!.auth.onAuthStateChange.listen((AuthState s) {
      _status = s.session != null ? BackendStatus.online : BackendStatus.offline;
      final String? tok = s.session?.accessToken;
      if (_games != null) unawaited(_games!.realtime.setAuth(tok));
      if (_social != null) unawaited(_social!.realtime.setAuth(tok));
      if (s.event == AuthChangeEvent.passwordRecovery) recoveryPending = true;
      if (s.event == AuthChangeEvent.signedOut) recoveryPending = false;
      if (s.session != null &&
          (s.event == AuthChangeEvent.signedIn || s.event == AuthChangeEvent.initialSession ||
              s.event == AuthChangeEvent.userUpdated)) {
        unawaited(gamesHello());
      }
      notifyListeners();
    }, onError: (Object e) => debugPrint('auth stream: $e'));
    if (client!.auth.currentSession != null) _status = BackendStatus.online;
  }

  static bool _ready = false;
  static SupabaseClient? _games;
  static SupabaseClient? _social;
  String? _helloFor;

  /// Games project client (rooms, matches, matchmaking, tournaments, leaderboards). Falls back to the auth client
  /// in builds without the games config so offline/dev builds keep working.
  SupabaseClient? get games => _ready ? (_games ?? Supabase.instance.client) : null;

  /// Social Media project client (Nova Gallery, Orbit Network DMs & calls, Social Station, follows & user directory).
  /// Isolated from the Games project (`games`) and falls back to the primary client when sharing the auth endpoint.
  SupabaseClient? get social => _ready ? (_social ?? Supabase.instance.client) : null;

  /// Registers this player on the games project (creates the profile mirror row, asks for a fresh wallet snapshot).
  /// Every games RPC needs the mirror row; called after each sign-in and before entering lobbies/tournaments.
  Future<void> gamesHello({bool force = false}) async {
    final SupabaseClient? g = _games;
    final String? id = uid;
    if (g == null || id == null || (!force && _helloFor == id)) return;
    try {
      await g.rpc('nx_g_hello');
      _helloFor = id;
    } catch (e) {
      debugPrint('games hello: $e');
    }
  }
  StreamSubscription<AuthState>? _sub;
  BackendStatus _status = BackendStatus.offline;
  String? lastError;
  bool busy = false;

  bool get configured => _ready;
  SupabaseClient? get client => _ready ? Supabase.instance.client : null;
  BackendStatus get status => _status;
  bool get isOnline => _status == BackendStatus.online && user != null;
  User? get user => client?.auth.currentUser;
  String? get uid => user?.id;
  bool get isGuest => user?.isAnonymous ?? true;
  String? get email => user?.email;

  /// Returns the existing authenticated session. Guest mode is local-only;
  /// this method never creates a Supabase anonymous account.
  Future<bool> ensureSession() async {
    final SupabaseClient? c = client;
    if (c == null) return false;
    if (c.auth.currentSession != null) {
      _status = BackendStatus.online;
      return true;
    }
    _status = BackendStatus.offline;
    lastError = 'email_login_required';
    notifyListeners();
    return false;
  }

  /// Deep link the e-mail's sign-in link opens (Android intent filter `nexora://login-callback`, added by CI).
  /// supabase_flutter exchanges the `?code=` itself, so a user whose e-mail carries only a link (no 6-digit code,
  /// e.g. while the project's Magic Link template lacks `{{ .Token }}`) can still sign in by tapping it on this phone.
  /// The URL must be in Supabase → Authentication → URL Configuration → Redirect URLs, otherwise the server falls
  /// back to the project's Site URL.
  static const String emailRedirect = 'nexora://login-callback';

  /// Last time a code was requested per e-mail (Supabase allows one request per address every 60 s).
  static final Map<String, DateTime> _otpSentAt = <String, DateTime>{};
  static const Duration otpCooldown = Duration(seconds: 60);

  /// Only send metadata accepted by the shared profiles.username constraint.
  /// Null lets the database trigger generate its safe default username.
  static String? signupUsername(String? username) {
    final String candidate = username?.trim() ?? '';
    final int length = candidate.runes.length;
    return length >= 3 && length <= 20 ? candidate : null;
  }

  static String normalizeEmailOtpDigits(String value) {
    const String fa = '۰۱۲۳۴۵۶۷۸۹', ar = '٠١٢٣٤٥٦٧٨٩';
    final StringBuffer b = StringBuffer();
    for (final int r in value.runes) {
      final String ch = String.fromCharCode(r);
      final int i = fa.indexOf(ch), j = ar.indexOf(ch);
      if (i >= 0) {
        b.write(i);
      } else if (j >= 0) {
        b.write(j);
      } else if (ch.trim().isNotEmpty) {
        b.write(ch);
      }
    }
    return b.toString();
  }

  static bool isSixDigitEmailOtp(String value) => RegExp(r'^\d{6}$').hasMatch(value);

  /// Seconds until another code may be requested for [email] (0 = now).
  int otpCooldownLeft(String email) {
    final DateTime? at = _otpSentAt[email.trim().toLowerCase()];
    if (at == null) return 0;
    final int left = otpCooldown.inSeconds - DateTime.now().difference(at).inSeconds;
    return left > 0 ? left : 0;
  }

  /// Seconds the server asked us to wait (parsed from its rate-limit message), if any.
  int? lastRetryAfter;

  Future<bool> sendEmailOtp(String email) async {
    final String e = email.trim();
    lastRetryAfter = null;
    final bool? ok = await _run<bool>((SupabaseClient c) async {
      await c.auth.signInWithOtp(email: e, shouldCreateUser: true, emailRedirectTo: emailRedirect);
      return true;
    });
    if (ok == true) _otpSentAt[e.toLowerCase()] = DateTime.now();
    return ok ?? false;
  }

  bool? _googleEnabled;

  /// Whether the auth project actually has the Google provider switched on (public GET /auth/v1/settings →
  /// external.google). The integration's working sign-in paths are username / e-mail + password (nx-login) and the
  /// e-mail code; Google is offered only when the server can complete it, so the button never leads to
  /// "provider is not enabled". Cached for the session; false when offline / not configured.
  Future<bool> googleSignInAvailable() async {
    if (_googleEnabled != null) return _googleEnabled!;
    if (!configured || kIsWeb) return false;
    try {
      final HttpClient h = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final HttpClientRequest rq = await h.getUrl(Uri.parse('${OnlineConfig.supabaseUrl}/auth/v1/settings'));
      rq.headers.set('apikey', OnlineConfig.supabaseAnonKey);
      final HttpClientResponse rs = await rq.close().timeout(const Duration(seconds: 8));
      final String body = await rs.transform(utf8.decoder).join();
      h.close();
      final dynamic j = jsonDecode(body);
      _googleEnabled = j is Map && j['external'] is Map && (j['external'] as Map)['google'] == true;
    } catch (e) {
      debugPrint('auth settings: $e');
      return false;
    }
    return _googleEnabled!;
  }

  /// "Sign in with Google": Supabase OAuth (Google provider) in the system browser; Google returns to
  /// [emailRedirect] (`nexora://login-callback`, the Android intent filter CI adds), supabase_flutter exchanges the
  /// code and the session listener + router redirect take the user on. Returns true when the browser was opened.
  Future<bool> signInWithGoogle() async {
    final bool? ok = await _run<bool>((SupabaseClient c) async {
      return c.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: emailRedirect,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    });
    return ok ?? false;
  }

  Future<bool> verifyEmailOtp(String email, String token) async {
    final bool? ok = await _run<bool>((SupabaseClient c) async {
      await c.auth.verifyOTP(email: email.trim(), token: token.trim(), type: OtpType.email);
      return c.auth.currentSession != null;
    });
    return ok ?? false;
  }

  /// Normalised error keys for the UI (see AuthPage): network, rate_limit, otp_invalid, smtp, signup_disabled,
  /// invalid_login, email_taken, weak_password, or the server message.
  String _friendly(Object e) {
    if (e is AuthException) {
      final String m = e.message.toLowerCase();
      final String code = (e.code ?? '').toLowerCase();
      if (e.statusCode == '429' || code.contains('rate_limit') || m.contains('rate limit') ||
          m.contains('security purposes') || m.contains('too many')) {
        final RegExpMatch? s = RegExp(r'after (\d+) second').firstMatch(m);
        lastRetryAfter = s != null ? int.tryParse(s.group(1)!) : null;
        return 'rate_limit';
      }
      if (code == 'otp_expired' || m.contains('token has expired') || (m.contains('otp') && m.contains('invalid'))) {
        return 'otp_invalid';
      }
      if (code == 'email_address_not_authorized' || m.contains('not authorized') || m.contains('error sending') ||
          m.contains('smtp')) {
        return 'smtp';
      }
      if (code == 'signup_disabled' || m.contains('signups not allowed')) return 'signup_disabled';
      if (code == 'user_banned' || m == 'banned' || m.contains('user is banned')) return 'banned';
      if (code == 'invalid_credentials' || m.contains('invalid login')) return 'invalid_login';
      if (m.contains('already') || m.contains('registered')) return 'email_taken';
      if (m.contains('password')) return 'weak_password';
      return e.message;
    }
    if (e is FunctionException) {
      if (e.status == 429) return 'rate_limit';
      if (e.status == 403) return 'banned';
      if (e.status == 400 || e.status == 401) return 'invalid_login';
    }
    final String s = '$e';
    if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('ClientException') ||
        s.contains('TimeoutException')) {
      return 'network';
    }
    return s;
  }

  Future<T?> _run<T>(Future<T> Function(SupabaseClient c) f) async {
    final SupabaseClient? c = client;
    if (c == null) {
      lastError = 'not_configured';
      return null;
    }
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final T r = await f(c);
      return r;
    } catch (e) {
      lastError = _friendly(e);
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Guest → permanent account (same uid, all progress kept). Without a guest: new account.
  Future<bool> registerEmail(String email, String password, {String? username}) async {
    final String? safeUsername = signupUsername(username);
    final String? install = await InstallId.get();
    final bool? ok = await _run<bool>((SupabaseClient c) async {
      final User? u = c.auth.currentUser;
      if (u != null && u.isAnonymous) {
        await c.auth.updateUser(UserAttributes(
            email: email.trim(),
            password: password,
            data: install == null ? null : <String, dynamic>{'nx_install': install}));
      } else {
        await c.auth.signUp(
          email: email.trim(),
          password: password,
          data: <String, dynamic>{
            if (safeUsername != null) 'username': safeUsername,
            if (install != null) 'nx_install': install,
          },
        );
      }
      return true;
    });
    if (ok == true && !await _installCleared()) return false;
    return ok ?? false;
  }

  /// Username logins (no «@», e.g. the default main admin `admin`) map to an internal e-mail that never receives mail.
  /// Their stored password is the typed one with a fixed prefix, so short admin passwords still satisfy the project's
  /// 6-character minimum for real e-mail accounts (which is unchanged).
  static const String internalDomain = 'users.nexora.invalid';
  static bool isUsernameLogin(String id) => !id.trim().contains('@');
  static String loginEmail(String id) =>
      isUsernameLogin(id) ? '${id.trim().toLowerCase()}@$internalDomain' : id.trim();
  static String loginPassword(String id, String password) => isUsernameLogin(id) ? 'nx#$password' : password;
  bool get isInternalAccount => (email ?? '').endsWith('@$internalDomain');

  /// The username this account signed up with (auth metadata, or the local part of an internal username account).
  /// Null for guests, signed-out phones and accounts that never chose one.
  String? get accountUsername {
    final User? u = user;
    if (u == null || u.isAnonymous) return null;
    final dynamic meta = u.userMetadata?['username'];
    if (meta is String && meta.trim().length >= 2) return meta.trim();
    final String mail = u.email ?? '';
    if (mail.endsWith('@$internalDomain')) {
      final String local = mail.substring(0, mail.length - internalDomain.length - 1);
      if (local.length >= 2) return local;
    }
    return null;
  }

  // ------------------------------------------------------------------ username + password accounts
  /// Usernames: 3-20 of a-z 0-9 _ . (lower case; what nx-login and the profiles constraint accept).
  static final RegExp usernamePattern = RegExp(r'^[a-z0-9_.]{3,20}$');
  static String normalizeUsername(String u) => u.trim().toLowerCase();
  static bool isValidUsername(String u) => usernamePattern.hasMatch(normalizeUsername(u));
  static const int minPasswordLength = 8;
  static const String _kLastUsername = 'nx.auth.lastUsername';

  /// The last username (or e-mail) that signed in on this phone; kept after sign-out to pre-fill the login form.
  static Future<String?> lastUsername() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_kLastUsername);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _rememberUsername(String id) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_kLastUsername, id.trim());
    } catch (_) {}
  }

  /// Whether [username] is free (never reveals who owns a taken name). Null = server not reachable.
  Future<bool?> isUsernameFree(String username) async {
    final SupabaseClient? c = client;
    if (c == null) return null;
    try {
      final dynamic r = await c.rpc('nx_username_available', params: <String, dynamic>{'p_username': normalizeUsername(username)});
      return r == true;
    } catch (_) {
      return null;
    }
  }

  /// New account with a username and password; the e-mail is optional (only for recovery, never shown to others).
  /// No codes: the session starts right away and persists on the phone until sign-out.
  Future<bool> signUpUsername(String username, String password, {String? email, String? termsVersion}) async {
    final String u = normalizeUsername(username);
    final String? mail = (email ?? '').trim().isEmpty ? null : email!.trim();
    if (!usernamePattern.hasMatch(u)) {
      lastError = 'bad_username';
      notifyListeners();
      return false;
    }
    if (password.length < minPasswordLength) {
      lastError = 'weak_password';
      notifyListeners();
      return false;
    }
    final bool? free = await isUsernameFree(u);
    if (free == false) {
      lastError = 'username_taken';
      notifyListeners();
      return false;
    }
    final String? install = await InstallId.get();
    final bool? ok = await _run<bool>((SupabaseClient c) async {
      final AuthResponse r = await c.auth.signUp(
        email: mail ?? '$u@$internalDomain',
        password: mail == null ? 'nx#$password' : password,
        data: <String, dynamic>{
          'username': u,
          // install id for the ban-evasion check; the server reads it and never stores it in the account
          if (install != null) 'nx_install': install,
          if (termsVersion != null) 'terms_version': termsVersion,
          if (termsVersion != null) 'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (r.session == null) {
        // Projects that require e-mail confirmation return no session; sign in right away instead.
        await c.auth.signInWithPassword(email: mail ?? '$u@$internalDomain', password: mail == null ? 'nx#$password' : password);
      }
      return true;
    });
    if (ok == true && !await _installCleared()) return false;
    if (ok == true) await _rememberUsername(u);
    return ok ?? false;
  }

  /// Login with a username or an e-mail plus password. Usernames go through the nx-login Edge Function, which finds the
  /// account server-side (internal username account, or the e-mail account owning that username) without ever
  /// sending an e-mail address to the phone.
  Future<bool> signInIdentifier(String identifier, String password) async {
    final String id = identifier.trim();
    final String? install = await InstallId.get();
    final bool? ok = await _run<bool>((SupabaseClient c) async {
      if (id.contains('@')) {
        await c.auth.signInWithPassword(email: id, password: password);
        return true;
      }
      final FunctionResponse r = await c.functions
          .invoke('nx-login', body: <String, dynamic>{
            'username': normalizeUsername(id),
            'password': password,
            if (install != null) 'install': install,
          });
      final dynamic d = r.data;
      final String? refresh = d is Map ? d['refresh_token'] as String? : null;
      if (refresh == null) throw const AuthException('Invalid login credentials', code: 'invalid_credentials');
      await c.auth.setSession(refresh);
      return true;
    });
    if (ok == true && !await _installCleared()) return false;
    if (ok == true) await _rememberUsername(id);
    return ok ?? false;
  }

  Future<bool> signInEmail(String email, String password) async {
    final bool? ok = await _run<bool>((SupabaseClient c) async {
      await c.auth.signInWithPassword(email: loginEmail(email), password: loginPassword(email, password));
      return true;
    });
    if (ok == true && !await _installCleared()) return false;
    return ok ?? false;
  }

  /// Ban-evasion hold (P0 #7c): after a successful sign-in / sign-up, asks the server whether this install is held
  /// because a banned account was deleted on it. If so the fresh session is dropped and [lastError] becomes 'banned'.
  /// Returns true when the session may stay (also when the server cannot answer: the server-side checks still apply).
  Future<bool> _installCleared() async {
    final SupabaseClient? c = client;
    final String? install = await InstallId.get();
    if (c == null || install == null) return true;
    try {
      final dynamic held = await c.rpc('nx_install_held', params: <String, dynamic>{'p_install': install});
      if (held != true) return true;
    } catch (_) {
      return true;
    }
    try {
      await c.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    lastError = 'banned';
    notifyListeners();
    return false;
  }

  /// Change the signed-in account's password (same prefix rule for username accounts), then refresh the token so the
  /// server-side "must change password" flag (cleared by a trigger on the password change) leaves the JWT claims too.
  Future<bool> changePassword(String newPassword) async {
    final bool? ok = await _run<bool>((SupabaseClient c) async {
      final String pw = isInternalAccount ? 'nx#$newPassword' : newPassword;
      await c.auth.updateUser(UserAttributes(password: pw));
      await c.auth.refreshSession();
      return true;
    });
    return ok ?? false;
  }

  // ------------------------------------------------------------------ password reset (P0 #2)
  /// Deep link of the recovery e-mail (`nexora://login-callback/reset?code=…`). It must be listed in Supabase →
  /// Authentication → URL Configuration → Redirect URLs. supabase_flutter exchanges the code for a session; the router
  /// sees the `/reset` path and opens the set-new-password screen.
  static const String recoveryRedirect = 'nexora://login-callback/reset';

  /// True between a recovery sign-in (e-mail link or recovery code) and the new password being saved; the router keeps
  /// the user on `/reset-password` until then.
  bool recoveryPending = false;

  void markRecovery() {
    if (recoveryPending) return;
    recoveryPending = true;
    notifyListeners();
  }

  /// Sends the recovery e-mail (link + 6-digit code when the template has `{{ .Token }}`).
  Future<bool> resetPassword(String email) async {
    final String e = email.trim();
    lastRetryAfter = null;
    final bool? ok = await _run<bool>((SupabaseClient c) async {
      await c.auth.resetPasswordForEmail(e, redirectTo: recoveryRedirect);
      return true;
    });
    if (ok == true) _otpSentAt['reset:${e.toLowerCase()}'] = DateTime.now();
    return ok ?? false;
  }

  /// Seconds until another recovery e-mail may be requested for [email].
  int resetCooldownLeft(String email) => otpCooldownLeft('reset:${email.trim()}');

  /// Verifies the recovery code from the e-mail; on success the user is signed in for the reset only.
  Future<bool> verifyRecoveryCode(String email, String code) async {
    final String token = normalizeEmailOtpDigits(code);
    if (!RegExp(r'^\d{6,10}$').hasMatch(token)) {
      lastError = 'otp_invalid';
      notifyListeners();
      return false;
    }
    final bool? ok = await _run<bool>((SupabaseClient c) async {
      await c.auth.verifyOTP(email: email.trim(), token: token, type: OtpType.recovery);
      return c.auth.currentSession != null;
    });
    if (ok == true) markRecovery();
    return ok ?? false;
  }

  /// Saves the new password of a recovery session (e-mail accounts store the password as typed).
  Future<bool> completeRecovery(String newPassword) async {
    if (newPassword.length < minPasswordLength) {
      lastError = 'weak_password';
      notifyListeners();
      return false;
    }
    final bool? ok = await _run<bool>((SupabaseClient c) async {
      if (c.auth.currentSession == null) throw const AuthException('Auth session missing', code: 'session_missing');
      final String pw = isInternalAccount ? 'nx#$newPassword' : newPassword;
      await c.auth.updateUser(UserAttributes(password: pw));
      return true;
    });
    if (ok == true) recoveryPending = false;
    notifyListeners();
    return ok ?? false;
  }

  // ------------------------------------------------------------------ account deletion (P0 #1)
  /// Permanently deletes the signed-in account on the server (`nx_delete_account`, both projects through the bridge).
  ///
  /// [password] is the account password when it has one (username accounts store it with the `nx#` prefix, added
  /// here). Returns null on success, otherwise an error key: confirm_required, wrong_password, owner_cannot_delete,
  /// rate_limited, not_signed_in, network or the server message.
  /// Order: validate (dry run) -> remove own storage files through the Storage API -> delete for real -> local sign-out.
  Future<String?> deleteAccount({String? password}) async {
    final SupabaseClient? c = client;
    if (c == null || c.auth.currentSession == null || isGuest) return 'not_signed_in';
    final String? pw = (password == null || password.isEmpty) ? null : (isInternalAccount ? 'nx#$password' : password);
    final String? install = await InstallId.get();
    Future<String?> call(bool dry) async {
      final dynamic r = await c.rpc('nx_delete_account', params: <String, dynamic>{
        'p_confirm': 'DELETE',
        'p_password': pw,
        'p_dry_run': dry,
        // only used by the server when the account is banned (ban-evasion hold, kept as a keyed hash)
        if (install != null) 'p_install': install,
      });
      if (r is Map && r['ok'] == true) return null;
      return r is Map ? (r['error'] as String? ?? 'failed') : 'failed';
    }

    busy = true;
    notifyListeners();
    try {
      final String? check = await call(true);
      if (check != null) return check;
      try {
        final dynamic files = await c.rpc('nx_my_storage_objects');
        final Map<String, List<String>> byBucket = <String, List<String>>{};
        if (files is List) {
          for (final dynamic f in files) {
            if (f is Map && f['bucket'] is String && f['path'] is String) {
              byBucket.putIfAbsent(f['bucket'] as String, () => <String>[]).add(f['path'] as String);
            }
          }
        }
        for (final MapEntry<String, List<String>> e in byBucket.entries) {
          try {
            await c.storage.from(e.key).remove(e.value);
          } catch (err) {
            debugPrint('delete account storage ${e.key}: $err');
          }
        }
      } catch (err) {
        debugPrint('delete account storage list: $err');
      }
      final String? done = await call(false);
      if (done != null) return done;
      try {
        await c.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
      _helloFor = null;
      return null;
    } catch (e) {
      final String m = '$e';
      if (m.contains('rate_limited')) return 'rate_limited';
      return _friendly(e);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Sign out. Guest mode is local-only and never creates an anonymous session.
  Future<void> signOut({bool continueAsGuest = false}) async {
    await _run<bool>((SupabaseClient c) async {
      await c.auth.signOut();
      return true;
    });
    if (continueAsGuest) await ensureSession();
  }

  /// RPC on the games project.
  Future<dynamic> grpc(String fn, [Map<String, dynamic>? params]) async {
    final SupabaseClient? g = games;
    if (g == null || client?.auth.currentSession == null) return null;
    await gamesHello();
    return g.rpc(fn, params: params);
  }

  /// Small helper for RPC calls that should never throw into the UI.
  Future<dynamic> rpc(String fn, [Map<String, dynamic>? params]) async {
    final SupabaseClient? c = client;
    if (c == null || c.auth.currentSession == null) return null;
    return c.rpc(fn, params: params);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final onlineProvider = ChangeNotifierProvider<OnlineService>((ref) => OnlineService());
