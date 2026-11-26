import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/online/online_service.dart';
import '../../core/settings/app_settings.dart';
import '../../ui/kit/station_compat.dart';

import '../../ui/screens/auth_screens.dart' show nxAuthError;

/// Password recovery, step 1 (P0 #2): send the recovery e-mail, then either type the code from it here or tap its
/// link on this phone (`nexora://login-callback/reset`). Both sign the user in for the reset only and lead to
/// [ResetPasswordPage]. Needs a working mail sender (custom SMTP) on the auth project.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.email});
  final String? email;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  late final TextEditingController _email = TextEditingController(text: widget.email ?? '');
  final TextEditingController _code = TextEditingController();
  bool _sent = false;
  String? _error;
  String? _info;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _sent) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _emailOk => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _send() async {
    if (!_emailOk) {
      setState(() => _error = context.tx('ایمیل حسابت را درست وارد کن.', 'Enter your account email.'));
      return;
    }
    final OnlineService o = ref.read(onlineProvider);
    final bool ok = await o.resetPassword(_email.text);
    if (!mounted) return;
    setState(() {
      _sent = ok || _sent;
      _error = ok ? null : nxAuthError(context, o.lastError);
      _info = ok
          ? context.tx('اگر این ایمیل حساب داشته باشد، کد و لینک بازیابی برایش فرستاده شد. پوشه‌ی اسپم را هم ببین.',
              'If this email has an account, a recovery code and link were sent to it. Check the spam folder too.')
          : null;
    });
  }

  Future<void> _verify() async {
    final OnlineService o = ref.read(onlineProvider);
    final bool ok = await o.verifyRecoveryCode(_email.text, _code.text);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = nxAuthError(context, o.lastError));
      return;
    }
    context.go('/reset-password');
  }

  @override
  Widget build(BuildContext context) {
    final OnlineService o = ref.watch(onlineProvider);
    final NxThemeColors visual = NxThemeColors.of(context);
    final int wait = o.resetCooldownLeft(_email.text);
    return StationScreen(
      title: context.tx('بازیابی رمز عبور', 'Reset password'),
      balance: false,
      onBack: () => context.canPop() ? context.pop() : context.go('/auth'),
      child: NxBrandBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  SizedBox(height: 84, child: Image.asset(StationPalette.of(context).logo, fit: BoxFit.contain)),
                  const SizedBox(height: 14),
                  Text(
                    context.tx(
                        'ایمیلی که با آن ثبت‌نام کرده‌ای را بزن. حساب‌هایی که فقط نام کاربری دارند (بدون ایمیل) از این راه بازیابی نمی‌شوند؛ با پشتیبانی تماس بگیر.',
                        'Enter the email you signed up with. Username-only accounts (no email) cannot be recovered this way; contact support.'),
                    style: TextStyle(color: visual.muted, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const ValueKey<String>('reset-email'),
                    controller: _email,
                    enabled: !o.busy,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const <String>[AutofillHints.email],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                        labelText: context.tx('ایمیل', 'Email'), prefixIcon: const Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: o.busy || wait > 0 ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(wait > 0
                        ? context.tx('ارسال دوباره تا $wait ثانیه', 'Resend in ${wait}s')
                        : _sent
                            ? context.tx('ارسال دوباره', 'Send again')
                            : context.tx('ارسال کد بازیابی', 'Send recovery code')),
                  ),
                  if (_sent) ...<Widget>[
                    const SizedBox(height: 18),
                    TextField(
                      key: const ValueKey<String>('reset-code'),
                      controller: _code,
                      enabled: !o.busy,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.number,
                      autofillHints: const <String>[AutofillHints.oneTimeCode],
                      maxLength: 10,
                      decoration: InputDecoration(
                          labelText: context.tx('کد داخل ایمیل', 'Code from the email'),
                          prefixIcon: const Icon(Icons.pin_rounded)),
                    ),
                    FilledButton.icon(
                      onPressed: o.busy ? null : _verify,
                      icon: const Icon(Icons.verified_rounded),
                      label: Text(context.tx('تأیید کد', 'Verify code')),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tx('یا لینک داخل ایمیل را روی همین گوشی باز کن.', 'Or open the link in the email on this phone.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: visual.muted, fontSize: 12),
                    ),
                  ],
                  if (o.busy) ...<Widget>[const SizedBox(height: 12), const LinearProgressIndicator()],
                  if (_info != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(_info!, textAlign: TextAlign.center, style: const TextStyle(color: NxColors.gold)),
                  ],
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: NxColors.danger, fontWeight: FontWeight.w700)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Password recovery, step 2: choose the new password (the recovery session from the code or the e-mail link is
/// already active). Until it is saved the router keeps the user here.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final TextEditingController _pw = TextEditingController();
  final TextEditingController _pw2 = TextEditingController();
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_pw.text.length < OnlineService.minPasswordLength) {
      setState(() => _error = context.tx('رمز حداقل ۸ نویسه باشد.', 'Password must be at least 8 characters.'));
      return;
    }
    if (_pw.text != _pw2.text) {
      setState(() => _error = context.tx('دو رمز یکسان نیستند.', 'The two passwords do not match.'));
      return;
    }
    final OnlineService o = ref.read(onlineProvider);
    final bool ok = await o.completeRecovery(_pw.text);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = nxAuthError(context, o.lastError));
      return;
    }
    ref.read(settingsProvider).setAuthMode('email');
    luxeToast(context, context.tx('رمز تازه ذخیره شد ✓', 'New password saved ✓'));
    context.go('/hub');
  }

  Future<void> _cancel() async {
    final OnlineService o = ref.read(onlineProvider);
    o.recoveryPending = false;
    await o.signOut();
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final OnlineService o = ref.watch(onlineProvider);
    final NxThemeColors visual = NxThemeColors.of(context);
    final bool ready = o.user != null && !o.isGuest;
    return StationScreen(
      title: context.tx('رمز عبور تازه', 'New password'),
      balance: false,
      back: false,
      child: NxBrandBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: !ready
                    ? Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 14),
                        Text(context.tx('در حال باز کردن لینک بازیابی…', 'Opening your recovery link…'),
                            style: TextStyle(color: visual.text)),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () => context.go('/forgot-password'),
                          child: Text(context.tx('وارد کردن کد به‌جای لینک', 'Enter the code instead')),
                        ),
                      ])
                    : AutofillGroup(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                          Text(o.email != null && !o.isInternalAccount ? o.email! : '',
                              textAlign: TextAlign.center, style: TextStyle(color: visual.muted)),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey<String>('reset-new-pass'),
                            controller: _pw,
                            obscureText: !_show,
                            textDirection: TextDirection.ltr,
                            autofillHints: const <String>[AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: context.tx('رمز تازه (حداقل ۸)', 'New password (min 8)'),
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                                onPressed: () => setState(() => _show = !_show),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            key: const ValueKey<String>('reset-new-pass2'),
                            controller: _pw2,
                            obscureText: !_show,
                            textDirection: TextDirection.ltr,
                            onSubmitted: (_) => _save(),
                            decoration: InputDecoration(
                              labelText: context.tx('تکرار رمز تازه', 'Repeat new password'),
                              prefixIcon: const Icon(Icons.lock_reset_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: o.busy ? null : _save,
                            icon: const Icon(Icons.check_rounded),
                            label: Text(context.tx('ذخیره‌ی رمز تازه', 'Save new password')),
                          ),
                          TextButton(
                            onPressed: o.busy ? null : _cancel,
                            child: Text(context.tx('انصراف و خروج', 'Cancel and sign out')),
                          ),
                          if (o.busy) const LinearProgressIndicator(),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: NxColors.danger, fontWeight: FontWeight.w700)),
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
