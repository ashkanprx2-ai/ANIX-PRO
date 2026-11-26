import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/companion/companion.dart';
import '../../core/online/cloud_profile_sync.dart';
import '../../core/online/online_service.dart';
import '../../core/profile/profile_service.dart';
import '../../core/settings/app_settings.dart';
import '../../worlds/legal/legal_texts.dart';
import '../kit/station_awards.dart';
import '../kit/station_kit.dart';
import '../widgets/companion_widgets.dart';

/// `#splash` — wordmark (skin logo), golden hairline and «Play · Connect · Enjoy», then continues to [next].
class StationSplash extends ConsumerStatefulWidget {
  const StationSplash({super.key, required this.next});
  final String next;

  @override
  ConsumerState<StationSplash> createState() => _StationSplashState();
}

class _StationSplashState extends ConsumerState<StationSplash> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 1600), _done);
  }

  void _done() {
    if (!mounted) return;
    ref.read(settingsProvider).introSeen = true;
    context.go(widget.next);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: GestureDetector(
        onTap: _done,
        child: StationBackdrop(
          image: p.hubImage,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1600),
              curve: kStationEase,
              builder: (BuildContext context, double v, _) => Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Image.asset(p.logo, width: MediaQuery.sizeOf(context).width * .8, fit: BoxFit.contain),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 120 * v,
                  height: 1,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: <Color>[p.gold.withValues(alpha: 0), p.gold, p.gold.withValues(alpha: 0)])),
                ),
                const SizedBox(height: 18),
                Opacity(opacity: .7 * v, child: Text('PLAY · CONNECT · ENJOY', style: StationText.lat(context, size: 11, color: p.gold2))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sign in / sign up (username + password, e-mail optional), **Sign in with Google** (Supabase OAuth) and guest
/// entry — in the Station look.
class StationAuthPage extends ConsumerStatefulWidget {
  const StationAuthPage({super.key});

  @override
  ConsumerState<StationAuthPage> createState() => _StationAuthPageState();
}

class _StationAuthPageState extends ConsumerState<StationAuthPage> {
  final TextEditingController _id = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final TextEditingController _user = TextEditingController();
  final TextEditingController _newPass = TextEditingController();
  final TextEditingController _email = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _show = false;
  String? _error;
  bool _accepted = false;
  bool _prefilled = false;

  /// Google button only when the auth project has the Google provider enabled (see OnlineService.googleSignInAvailable).
  bool _google0 = false;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(onlineProvider).googleSignInAvailable().then((bool v) {
      if (mounted && v != _google0) setState(() => _google0 = v);
    }));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final String? q = GoRouterState.of(context).uri.queryParameters['email'];
    if (q != null && q.isNotEmpty) _id.text = q;
    unawaited(OnlineService.lastUsername().then((String? u) {
      if (mounted && u != null && _id.text.isEmpty) setState(() => _id.text = u);
    }));
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[_id, _pass, _user, _newPass, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final OnlineService online = ref.read(onlineProvider);
    if (!online.configured) {
      setState(() => _error = stx(context, 'اتصال آنلاین تنظیم نشده است.', 'Online authentication is not configured.'));
      return;
    }
    String? err;
    if (_signUp) {
      if (!OnlineService.isValidUsername(_user.text)) {
        err = stx(context, 'نام کاربری: ۳ تا ۲۰ حرف انگلیسی کوچک، عدد، _ یا .', 'Username: 3–20 of a-z, 0-9, _ or .');
      } else if (_newPass.text.length < OnlineService.minPasswordLength) {
        err = stx(context, 'رمز حداقل ۸ نویسه باشد.', 'Password must be at least 8 characters.');
      } else if (_email.text.trim().isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
        err = stx(context, 'ایمیل معتبر نیست (اختیاری است؛ می‌توانی خالی بگذاری).', 'That email is not valid (it is optional).');
      } else if (!_accepted) {
        err = stx(context, 'برای ساخت حساب، شرایط استفاده و حریم خصوصی را بپذیر.', 'To create an account, accept the Terms of Use and Privacy Policy.');
      }
    } else if (_id.text.trim().isEmpty || _pass.text.isEmpty) {
      err = stx(context, 'نام کاربری (یا ایمیل) و رمز را وارد کن.', 'Enter your username (or email) and password.');
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final bool ok = _signUp
        ? await online.signUpUsername(_user.text, _newPass.text, email: _email.text, termsVersion: legalVersion)
        : await online.signInIdentifier(_id.text, _pass.text);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = _friendly(online.lastError);
      });
      return;
    }
    TextInput.finishAutofillContext();
    _afterSession(online, signUpName: _signUp ? OnlineService.normalizeUsername(_user.text) : null);
  }

  void _afterSession(OnlineService online, {String? signUpName}) {
    ref.read(settingsProvider).setAuthMode('email');
    ref.read(cloudSyncProvider).start();
    unawaited(online.gamesHello(force: true));
    final bool ready = ref.read(profileProvider).adoptAccountName(online.accountUsername ?? signUpName);
    if (ready) ref.read(settingsProvider).markOnboarded();
    context.go(ready ? '/hub' : '/onboarding');
  }

  /// Google sign-in: the browser opens Google; the app returns through nexora://login-callback and the router's
  /// session redirect finishes the job (also when this page is gone by then).
  Future<void> _google() async {
    final OnlineService online = ref.read(onlineProvider);
    if (!online.configured) {
      setState(() => _error = stx(context, 'اتصال آنلاین تنظیم نشده است.', 'Online authentication is not configured.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final bool opened = await online.signInWithGoogle();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!opened) _error = _friendly(online.lastError);
    });
    if (opened) {
      stationToast(context, stx(context, 'ورود با گوگل در مرورگر باز شد…', 'Google sign-in opened in the browser…'));
      void once() {
        if (online.user != null && !online.isGuest) {
          online.removeListener(once);
          if (mounted) _afterSession(online);
        }
      }

      online.addListener(once);
    }
  }

  String _friendly(String? value) => nxAuthError(context, value);
  void _continueGuest() {
    ref.read(settingsProvider).setAuthMode('guest');
    final bool hasIdentity = ref.read(profileProvider).hasIdentity;
    context.go(hasIdentity ? '/hub' : '/onboarding');
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool pass = false, Iterable<String>? hints, Key? key, int? max, List<TextInputFormatter>? fmt, TextInputType? kb}) {
    final StationPalette p = StationPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: key,
        controller: c,
        enabled: !_busy,
        obscureText: pass && !_show,
        textDirection: TextDirection.ltr,
        autocorrect: false,
        keyboardType: kb,
        maxLength: max,
        inputFormatters: fmt,
        autofillHints: hints,
        onSubmitted: pass ? (_) => _submit() : null,
        style: TextStyle(color: p.ink, fontFamily: kStationFont),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          prefixIcon: Icon(icon, color: p.gold2, size: 20),
          suffixIcon: pass
              ? IconButton(
                  icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: p.mute),
                  onPressed: () => setState(() => _show = !_show))
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: StationBackdrop(
        image: p.hubImage,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AutofillGroup(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                    SizedBox(height: 96, child: Image.asset(p.logo, fit: BoxFit.contain)),
                    const SizedBox(height: 10),
                    Text(
                      _signUp ? stx(context, 'ساخت حساب نکسورا', 'Create your NEXORA account') : stx(context, 'ورود به نکسورا', 'Log in to NEXORA'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: p.ink),
                    ),
                    const SizedBox(height: 14),
                    StationCard(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                        StationTabs(
                          labels: <String>[stx(context, 'ورود', 'Log in'), stx(context, 'ثبت‌نام', 'Sign up')],
                          index: _signUp ? 1 : 0,
                          onChanged: (int i) => _busy
                              ? null
                              : setState(() {
                                  _signUp = i == 1;
                                  _error = null;
                                }),
                        ),
                        if (!_signUp) ...<Widget>[
                          _field(_id, stx(context, 'نام کاربری یا ایمیل', 'Username or email'), Icons.person_outline_rounded,
                              key: const ValueKey<String>('auth-id'),
                              kb: TextInputType.emailAddress,
                              hints: const <String>[AutofillHints.username, AutofillHints.email]),
                          _field(_pass, stx(context, 'رمز عبور', 'Password'), Icons.lock_outline_rounded,
                              pass: true, hints: const <String>[AutofillHints.password]),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: GestureDetector(
                              key: const ValueKey<String>('auth-forgot'),
                              onTap: _busy
                                  ? null
                                  : () => context.push(Uri(path: '/forgot-password', queryParameters: <String, String>{
                                        if (_id.text.contains('@')) 'email': _id.text.trim(),
                                      }).toString()),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(stx(context, 'رمز را فراموش کرده‌ای؟', 'Forgot password?'),
                                    style: TextStyle(color: p.gold, fontSize: 12.5, fontFamily: kStationFont)),
                              ),
                            ),
                          ),
                        ] else ...<Widget>[
                          _field(_user, stx(context, 'نام کاربری (a-z، 0-9، _ و .)', 'Username (a-z, 0-9, _ .)'), Icons.alternate_email_rounded,
                              key: const ValueKey<String>('auth-user'),
                              max: 20,
                              fmt: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]'))],
                              hints: const <String>[AutofillHints.newUsername]),
                          _field(_newPass, stx(context, 'رمز عبور (حداقل ۸)', 'Password (min 8)'), Icons.lock_outline_rounded,
                              pass: true, hints: const <String>[AutofillHints.newPassword]),
                          _field(_email, stx(context, 'ایمیل (اختیاری، فقط برای بازیابی)', 'Email (optional, recovery only)'), Icons.email_outlined,
                              kb: TextInputType.emailAddress, hints: const <String>[AutofillHints.email]),
                          GestureDetector(
                            key: const ValueKey<String>('auth-accept-terms'),
                            onTap: _busy ? null : () => setState(() => _accepted = !_accepted),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(children: <Widget>[
                                StationToggle(value: _accepted, onChanged: (bool v) => _busy ? null : setState(() => _accepted = v)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    stx(context, 'حداقل ۱۳ سال دارم و شرایط استفاده و سیاست حریم خصوصی را می‌پذیرم.',
                                        'I am at least 13 and accept the Terms of Use and Privacy Policy.'),
                                    style: TextStyle(color: p.ink, fontSize: 12.5, height: 1.6, fontFamily: kStationFont),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                          Wrap(alignment: WrapAlignment.center, spacing: 14, children: <Widget>[
                            GestureDetector(
                                onTap: () => context.push('/legal/terms'),
                                child: Text(stx(context, 'شرایط استفاده', 'Terms of Use'), style: TextStyle(color: p.gold, fontSize: 12))),
                            GestureDetector(
                                onTap: () => context.push('/legal/privacy'),
                                child: Text(stx(context, 'حریم خصوصی', 'Privacy Policy'), style: TextStyle(color: p.gold, fontSize: 12))),
                          ]),
                          const SizedBox(height: 10),
                        ],
                        StationButton(
                          label: _signUp ? stx(context, 'ساخت حساب', 'Create account') : stx(context, 'ورود', 'Log in'),
                          icon: _signUp ? Icons.rocket_launch_rounded : Icons.login_rounded,
                          busy: _busy,
                          onTap: _busy ? null : _submit,
                        ),
                        if (_google0)
                        StationButton(
                          key: const ValueKey<String>('auth-google'),
                          label: stx(context, 'ورود با گوگل', 'Sign in with Google'),
                          icon: Icons.g_mobiledata_rounded,
                          ghost: true,
                          onTap: _busy ? null : _google,
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF5A6E), fontSize: 13)),
                          ),
                      ]),
                    ),
                    StationButton(
                      label: stx(context, 'ورود مهمان؛ فقط آفلاین', 'Continue as guest · offline only'),
                      icon: Icons.offline_bolt_rounded,
                      ghost: true,
                      onTap: _busy ? null : _continueGuest,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stx(context, 'مهمان به حساب آنلاین، چت، بازی آنلاین، تورنمنت و همگام‌سازی دسترسی ندارد.',
                          'Guest mode has no online account, chat, online games, tournaments, or cloud sync.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.mute, fontSize: 11, height: 1.6),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A guest opened an online-only section.
class StationSignInRequired extends StatelessWidget {
  const StationSignInRequired({super.key, required this.from});
  final String from;

  @override
  Widget build(BuildContext context) {
    final bool chat = from.startsWith('/social') || from.contains('orbit');
    return StationScreen(
      title: stx(context, 'ورود لازم است', 'Sign in required'),
      balance: false,
      onBack: () => context.canPop() ? context.pop() : context.go('/hub'),
      children: <Widget>[
        StationHero(
          icon: 'r4c2',
          title: chat
              ? stx(context, 'چت به حساب آنلاین نیاز دارد', 'Chat needs an online account')
              : stx(context, 'این بخش به حساب آنلاین نیاز دارد', 'This section needs an online account'),
          subtitle: stx(context, 'در حالت مهمان فقط بازی‌های آفلاین و پروفایل محلی در دسترس است. با ورود، پیشرفتت هم همگام می‌شود.',
              'Guest mode only has offline games and a local profile. Sign in and your progress syncs too.'),
        ),
        StationButton(label: stx(context, 'ورود / ثبت‌نام', 'Sign in / Sign up'), icon: Icons.login_rounded, onTap: () => context.go('/auth')),
        StationButton(
            label: stx(context, 'بازی‌های آفلاین', 'Offline games'),
            icon: Icons.sports_esports_rounded,
            ghost: true,
            onTap: () => context.pushReplacement('/s/games')),
      ],
    );
  }
}

/// Unknown route.
class StationNotFound extends StatelessWidget {
  const StationNotFound({super.key, required this.location});
  final String location;

  @override
  Widget build(BuildContext context) => StationScreen(
        title: stx(context, 'پیدا نشد', 'Not found'),
        balance: false,
        onBack: () => context.go('/hub'),
        children: <Widget>[
          StationEmpty(text: stx(context, 'این صفحه پیدا نشد\n$location', 'This page was not found\n$location'), icon: 'r1c4'),
          StationButton(label: stx(context, 'بازگشت به خانه', 'Back home'), onTap: () => context.go('/hub')),
        ],
      );
}

/// Identity setup (guests / accounts without a name): pick a display name and your companion.
class StationOnboarding extends ConsumerStatefulWidget {
  const StationOnboarding({super.key});

  @override
  ConsumerState<StationOnboarding> createState() => _StationOnboardingState();
}

class _StationOnboardingState extends ConsumerState<StationOnboarding> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final String name = _name.text.trim();
    if (name.length < 2) {
      stationToast(context, stx(context, 'نام کاربری حداقل ۲ حرف باشد', 'Username must be at least 2 characters'), error: true);
      return;
    }
    HapticFeedback.mediumImpact();
    final ProfileService p = ref.read(profileProvider);
    await p.createIdentity(name: name);
    final AwardOutcome outcome = p.award('identity.created', xp: 50, coins: 0);
    ref.read(settingsProvider).markOnboarded();
    if (ref.read(settingsProvider).authMode == 'email') {
      unawaited(ref.read(cloudSyncProvider).identityCreated());
    }
    if (!mounted) return;
    await showAwardOutcome(context, outcome);
    if (mounted) context.go('/hub');
  }

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return StationScreen(
      title: stx(context, 'هویت تو', 'Your identity'),
      back: false,
      balance: false,
      children: <Widget>[
        StationCard(
          hero: true,
          child: Column(children: <Widget>[
            Image.asset('assets/characters/duo.webp', height: 200, fit: BoxFit.contain),
            const SizedBox(height: 8),
            Text(stx(context, 'به نکسورا خوش اومدی!', 'Welcome to NEXORA!'), style: const TextStyle(fontSize: 22)),
            Text(stx(context, 'دو ذهن، یک دنیا — اوراکل و لونا منتظرتن', 'Two minds, one universe — ORACLE and LUNA are waiting'),
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: p.isLight ? const Color(0xFFD7E0FF) : p.mute)),
          ]),
        ),
        StationTitle(stx(context, 'نام نمایشی', 'Display name')),
        StationInput(controller: _name, hint: stx(context, 'مثلاً: آشکان', 'e.g. Ashkan'), maxLength: 24, onSubmitted: (_) => _finish()),
        const SizedBox(height: 12),
        StationTitle(stx(context, 'همراه هوش مصنوعی‌ات را انتخاب کن', 'Pick your AI companion')),
        const CompanionSelector(),
        StationButton(label: stx(context, 'شروع ماجرا', 'Start the adventure'), icon: Icons.rocket_launch_rounded, onTap: _finish),
        const SizedBox(height: 4),
        Center(
          child: Text(
            stx(context, 'همراهت را هر وقت خواستی در صفحه‌ی هوش مصنوعی عوض کن.', 'Switch companions any time on the AI page.'),
            style: TextStyle(fontSize: 11, color: p.mute),
          ),
        ),
        Consumer(builder: (BuildContext context, WidgetRef ref, _) {
          ref.watch(companionProvider);
          return const SizedBox.shrink();
        }),
      ],
    );
  }
}


/// Human text for an [OnlineService.lastError] code (sign-in, sign-up, password recovery).
String nxAuthError(BuildContext context, String? value) {
    switch (value) {
      case 'network':
        return stx(context, 'اتصال اینترنت را بررسی کن.', 'Check your internet connection.');
      case 'invalid_login':
        return stx(context, 'نام کاربری/ایمیل یا رمز نادرست است.', 'Wrong username/email or password.');
      case 'username_taken':
        return stx(context, 'این نام کاربری گرفته شده یا مجاز نیست.', 'That username is taken or not allowed.');
      case 'banned':
        return stx(context, 'این حساب یا این دستگاه به‌خاطر نقض قوانین مسدود شده است.', 'This account or this device is banned for breaking the rules.');
      case 'otp_invalid':
        return stx(context, 'کد نادرست است یا منقضی شده.', 'The code is wrong or has expired.');
      case 'smtp':
        return stx(context, 'ارسال ایمیل از سرور فعلاً ممکن نیست؛ بعداً امتحان کن.', 'The server cannot send email right now; try again later.');
      case 'bad_username':
        return stx(context, 'نام کاربری: ۳ تا ۲۰ حرف انگلیسی کوچک، عدد، _ یا .', 'Username: 3–20 of a-z, 0-9, _ or .');
      case 'email_taken':
        return stx(context, 'این ایمیل قبلاً ثبت شده؛ با آن وارد شو.', 'That email already has an account; log in with it.');
      case 'weak_password':
        return stx(context, 'رمز ضعیف است (حداقل ۸ نویسه).', 'Password too weak (at least 8 characters).');
      case 'rate_limit':
        return stx(context, 'تلاش زیاد بود؛ کمی صبر کن.', 'Too many attempts; wait a moment.');
      case 'signup_disabled':
        return stx(context, 'ثبت‌نام حساب تازه روی سرور بسته است.', 'New sign-ups are disabled on the server.');
      case 'not_configured':
        return stx(context, 'اتصال آنلاین تنظیم نشده است.', 'Online authentication is not configured.');
      case null:
        return stx(context, 'انجام نشد. دوباره تلاش کن.', 'That did not work. Try again.');
      default:
        return stx(context, 'خطای سرور: $value', 'Server error: $value');
    }
}
