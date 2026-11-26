import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/online/online_service.dart';
import '../../core/profile/profile_service.dart';
import '../../core/settings/app_settings.dart';
import '../../core/storage/local_store.dart';
import '../../ui/kit/station_compat.dart';


/// "Delete account" (store requirement, P0 #1).
///
/// Signed-in accounts are deleted on the server (`nx_delete_account`: profile, wallet, posts, chats membership,
/// game data on both projects, files; messages in other people's chats stay anonymised) after a confirmation that
/// asks to type the confirmation word and, when the account has one, the password. Guests (local-only play) just wipe
/// this phone. Both end with the local data cleared.
class DeleteAccountButton extends ConsumerWidget {
  const DeleteAccountButton({super.key});

  /// The word the user types to confirm (either language is accepted).
  static bool confirmWordOk(String typed) {
    final String t = typed.trim().toLowerCase();
    return t == 'delete' || t == 'حذف';
  }

  static String errorText(String? e, bool fa) {
    switch (e) {
      case 'wrong_password':
        return fa ? 'رمز عبور درست نیست.' : 'The password is not correct.';
      case 'owner_cannot_delete':
        return fa
            ? 'حساب مدیر اصلی قابل حذف نیست؛ اول مالکیت را منتقل کن.'
            : 'The main admin account cannot be deleted; transfer ownership first.';
      case 'rate_limited':
        return fa ? 'تلاش زیاد بود؛ چند دقیقه‌ی دیگر دوباره امتحان کن.' : 'Too many attempts; try again in a few minutes.';
      case 'network':
        return fa ? 'اتصال اینترنت برقرار نیست.' : 'No internet connection.';
      case 'not_signed_in':
        return fa ? 'برای حذف حساب باید وارد شده باشی.' : 'Sign in to delete your account.';
      default:
        return fa ? 'حذف حساب انجام نشد. دوباره امتحان کن.' : 'Could not delete the account. Please try again.';
    }
  }

  Future<void> _wipeLocal(WidgetRef ref) async {
    final LocalStore store = LocalStore.instance;
    for (final String k in store.prefs.getKeys().toList()) {
      if (!k.startsWith('settings.')) await store.remove(k);
    }
    await ref.read(profileProvider).resetAll();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnlineService online = ref.watch(onlineProvider);
    final bool account = online.user != null && !online.isGuest;
    return StationButton(
      key: const ValueKey<String>('delete_account'),
      danger: true,
      busy: online.busy,
      icon: Icons.delete_forever_rounded,
      label: account
          ? context.tx('حذف همیشگی حساب کاربری', 'Delete account permanently')
          : context.tx('پاک کردن همه‌ی داده‌های این گوشی', 'Erase all data on this phone'),
      onTap: online.busy ? null : () => account ? _deleteAccount(context, ref) : _wipeGuest(context, ref),
    );
  }

  Future<void> _wipeGuest(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AnixDialog(
        title: Text(ctx.tx('مطمئنی؟', 'Are you sure?')),
        content: Text(ctx.tx('همه‌ی پیشرفت، آیتم‌ها و پست‌ها روی همین دستگاه پاک می‌شوند. قابل بازگشت نیست.',
            'All progress, items and posts on this device will be erased. This cannot be undone.')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tx('انصراف', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NxColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tx('پاک کن', 'Erase')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _wipeLocal(ref);
    if (context.mounted) context.go('/onboarding');
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final _DeleteInput? input = await showDialog<_DeleteInput>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => const _DeleteAccountDialog(),
    );
    if (input == null || !context.mounted) return;
    final OnlineService online = ref.read(onlineProvider);
    final String? err = await online.deleteAccount(password: input.password);
    if (!context.mounted) return;
    final bool fa = context.isFa;
    if (err != null) {
      luxeToast(context, errorText(err, fa), error: true);
      return;
    }
    await _wipeLocal(ref);
    ref.read(settingsProvider).clearAuthMode();
    if (!context.mounted) return;
    luxeToast(context, fa ? 'حساب کاربری حذف شد.' : 'Your account was deleted.');
    context.go('/auth');
  }
}

class _DeleteInput {
  const _DeleteInput(this.password);
  final String password;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _word = TextEditingController();
  final TextEditingController _pw = TextEditingController();
  bool _hide = true;

  @override
  void dispose() {
    _word.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool ok = DeleteAccountButton.confirmWordOk(_word.text);
    return AnixDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: NxColors.danger, size: 36),
      title: Text(context.tx('حذف همیشگی حساب', 'Delete your account')),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Text(
            context.tx(
                'حساب، پروفایل، سکه و جم، آیتم‌ها، پست‌ها، دنبال‌کننده‌ها، سابقه‌ی بازی و فایل‌هایت برای همیشه پاک می‌شوند. '
                    'پیام‌هایی که در گفتگوی دیگران فرستاده‌ای بدون نام باقی می‌مانند. خریدهای انجام‌شده برگشت داده نمی‌شوند. این کار قابل بازگشت نیست.',
                'Your account, profile, coins and gems, items, posts, followers, match history and files are erased for good. '
                    'Messages you sent in other people\'s chats stay, without your name. Purchases are not refunded. This cannot be undone.'),
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          Text(context.tx('برای تأیید بنویس «حذف» (یا DELETE):', 'To confirm, type DELETE (or «حذف»):'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey<String>('delete_confirm_word'),
            controller: _word,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'DELETE'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('delete_password'),
            controller: _pw,
            obscureText: _hide,
            decoration: InputDecoration(
              labelText: context.tx('رمز عبور (اگر حسابت رمز دارد)', 'Password (if your account has one)'),
              suffixIcon: IconButton(
                icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ),
        ]),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tx('انصراف', 'Cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: NxColors.danger),
          onPressed: ok ? () => Navigator.pop(context, _DeleteInput(_pw.text)) : null,
          child: Text(context.tx('حذف همیشگی', 'Delete forever')),
        ),
      ],
    );
  }
}
