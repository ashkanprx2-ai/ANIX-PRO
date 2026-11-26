import 'package:flutter/material.dart';

import '../online/online_service.dart';
import '../settings/app_settings.dart';
import '../../ui/kit/station_compat.dart';


/// Report / block helpers shared by every surface (P0 #7): profiles, chat messages, posts, comments, stories,
/// communities, rooms and online match results.
/// Reports go to the existing moderation queue (`nx_report_user` -> admin panel "Reports" tab); blocks use
/// `nx_block_user` / `nx_unblock_user` and are enforced by the server (DMs, calls, invites).

/// Human text for the server's safety errors (blocked, banned, profanity and name rules, mute).
String? safetyErrorText(Object? error, bool fa) {
  final String m = '$error';
  if (m.contains('blocked')) {
    return fa ? 'امکان ارتباط با این کاربر وجود ندارد (مسدود است).' : 'You can\'t interact with this user (blocked).';
  }
  if (m.contains('banned')) return fa ? 'حساب تو مسدود شده است.' : 'Your account is banned.';
  if (m.contains('username_reserved')) {
    return fa ? 'این نام کاربری رزرو شده است؛ نام دیگری انتخاب کن.' : 'That username is reserved; pick another one.';
  }
  if (m.contains('username_profane') || m.contains('name_profane')) {
    return fa ? 'این نام شامل کلمه‌ی نامناسب است.' : 'That name contains an inappropriate word.';
  }
  if (m.contains('muted')) return fa ? 'فعلاً اجازه‌ی ارسال پیام نداری.' : 'You are muted for now.';
  if (m.contains('rate_limited')) return fa ? 'تلاش زیاد بود؛ کمی صبر کن.' : 'Too many attempts; wait a moment.';
  return null;
}

const List<(String, String, String)> _reasons = <(String, String, String)>[
  ('harassment', 'توهین یا آزار', 'Harassment or insults'),
  ('sexual', 'محتوای جنسی یا نامناسب', 'Sexual or inappropriate content'),
  ('hate', 'نفرت‌پراکنی یا تهدید', 'Hate or threats'),
  ('spam', 'اسپم یا تبلیغ', 'Spam or advertising'),
  ('impersonation', 'جعل هویت', 'Impersonation'),
  ('cheating', 'تقلب در بازی', 'Cheating'),
  ('other', 'دلیل دیگر', 'Something else'),
];

final RegExp _uuidRe = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

/// [id] when it is a server account id (uuid); null for local, guest or bot ids, which cannot be reported as a user.
String? reportableUserId(String? id) {
  final String v = (id ?? '').trim().toLowerCase();
  return _uuidRe.hasMatch(v) ? v : null;
}

/// The reason text sent with a report: the chosen reason (and details), plus up to 200 characters of [excerpt] so
/// moderators still see the content if it is deleted later. The server keeps at most 500 characters.
String composeReportReason(String reason, String? excerpt) {
  String full = reason;
  if (excerpt != null && excerpt.trim().isNotEmpty) {
    final String ex = excerpt.trim();
    full = '$reason | «${ex.length > 200 ? '${ex.substring(0, 200)}…' : ex}»';
  }
  return full.length > 500 ? full.substring(0, 500) : full;
}

/// Report one of the other players of an online match (game result screen). [players] are (account id, name) per
/// seat; [myId] is left out, as are bots and seats without an account id. With several opponents a picker opens first.
Future<void> reportMatchPlayer(
  BuildContext context, {
  required String matchId,
  required List<(String, String)> players,
  required String? myId,
  String? game,
}) async {
  final List<(String, String)> others = <(String, String)>[
    for (final (String id, String name) in players)
      if (reportableUserId(id) != null && reportableUserId(id) != reportableUserId(myId)) (reportableUserId(id)!, name),
  ];
  if (others.isEmpty) {
    luxeToast(context, context.tx('بازیکنی برای گزارش نیست.', 'No player to report.'), error: true);
    return;
  }
  (String, String)? pick = others.length == 1 ? others.first : null;
  pick ??= await showModalBottomSheet<(String, String)>(
    context: context,
    builder: (BuildContext ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(ctx.tx('کدام بازیکن را گزارش می‌کنی؟', 'Which player do you want to report?'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        for (final (String id, String name) in others)
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(name),
            onTap: () => Navigator.pop(ctx, (id, name)),
          ),
      ]),
    ),
  );
  if (pick == null || !context.mounted) return;
  await reportContent(context,
      targetUser: pick.$1,
      kind: 'match',
      targetId: matchId,
      label: pick.$2,
      excerpt: game == null ? null : context.tx('بازی: $game', 'Game: $game'));
}

/// Asks for a reason and files a report. [kind]: user, profile, message, post, comment, story, community, room, match.
/// [excerpt] (e.g. the message text) is attached so moderators see it even if it is deleted later.
Future<void> reportContent(
  BuildContext context, {
  String? targetUser,
  required String kind,
  String? targetId,
  required String label,
  String? excerpt,
}) async {
  final OnlineService? o = OnlineService.current;
  if (o == null || !o.isOnline || o.isGuest) {
    luxeToast(context, context.tx('برای گزارش باید وارد شده باشی.', 'Sign in to report.'), error: true);
    return;
  }
  final String? reason = await showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => _ReportDialog(label: label),
  );
  if (reason == null || !context.mounted) return;
  final String full = composeReportReason(reason, excerpt);
  final bool fa = context.isFa;
  try {
    final dynamic r = await o.rpc('nx_report_user', <String, dynamic>{
      'p_target': targetUser,
      'p_kind': kind,
      'p_target_id': targetId,
      'p_reason': full,
    });
    if (!context.mounted) return;
    if (r is Map && r['ok'] == true) {
      luxeToast(context, fa ? 'گزارش برای مدیران فرستاده شد. ممنون!' : 'Report sent to the moderators. Thank you!');
    } else {
      final String err = r is Map ? '${r['error']}' : 'failed';
      luxeToast(context, safetyErrorText(err, fa) ?? (fa ? 'گزارش ثبت نشد.' : 'Could not send the report.'),
          error: true);
    }
  } catch (e) {
    if (context.mounted) {
      luxeToast(context, safetyErrorText(e, fa) ?? (fa ? 'گزارش ثبت نشد.' : 'Could not send the report.'), error: true);
    }
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.label});
  final String label;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _reason;
  final TextEditingController _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool fa = context.isFa;
    return AnixDialog(
      title: Text(context.tx('گزارش ${widget.label}', 'Report ${widget.label}')),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
            for (final (String id, String faL, String enL) in _reasons)
              ChoiceChip(
                label: Text(fa ? faL : enL),
                selected: _reason == id,
                onSelected: (_) => setState(() => _reason = id),
              ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _details,
            maxLength: 250,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(hintText: context.tx('توضیح (اختیاری)', 'Details (optional)')),
          ),
        ]),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tx('انصراف', 'Cancel'))),
        FilledButton(
          onPressed: _reason == null
              ? null
              : () => Navigator.pop(context, '$_reason${_details.text.trim().isEmpty ? '' : ': ${_details.text.trim()}'}'),
          child: Text(context.tx('ارسال گزارش', 'Send report')),
        ),
      ],
    );
  }
}

/// Block or unblock [userId] after a confirmation. Returns the new state (true = blocked), or null if nothing changed.
Future<bool?> toggleBlockUser(
  BuildContext context, {
  required String userId,
  required String username,
  required bool currentlyBlocked,
}) async {
  final OnlineService? o = OnlineService.current;
  if (o == null || !o.isOnline || o.isGuest) return null;
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AnixDialog(
      title: Text(currentlyBlocked
          ? ctx.tx('رفع مسدودی $username؟', 'Unblock $username?')
          : ctx.tx('مسدود کردن $username؟', 'Block $username?')),
      content: Text(currentlyBlocked
          ? ctx.tx('دوباره می‌تواند به تو پیام بدهد، تماس بگیرد و دعوتت کند.',
              'They will be able to message, call and invite you again.')
          : ctx.tx('دیگر نمی‌تواند به تو پیام بدهد، تماس بگیرد یا به اتاق دعوتت کند. خبرش به او داده نمی‌شود.',
              'They won\'t be able to message, call or invite you. They are not notified.')),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tx('انصراف', 'Cancel'))),
        FilledButton(
          style: currentlyBlocked ? null : FilledButton.styleFrom(backgroundColor: NxColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(currentlyBlocked ? ctx.tx('رفع مسدودی', 'Unblock') : ctx.tx('مسدود کن', 'Block')),
        ),
      ],
    ),
  );
  if (yes != true || !context.mounted) return null;
  final bool fa = context.isFa;
  try {
    final dynamic r =
        await o.rpc(currentlyBlocked ? 'nx_unblock_user' : 'nx_block_user', <String, dynamic>{'p_user': userId});
    if (r is Map && r['ok'] == true) {
      if (context.mounted) {
        luxeToast(context, currentlyBlocked ? (fa ? 'مسدودی برداشته شد' : 'Unblocked') : (fa ? 'مسدود شد' : 'Blocked'));
      }
      return !currentlyBlocked;
    }
    if (context.mounted) {
      luxeToast(context, safetyErrorText(r is Map ? r['error'] : r, fa) ?? (fa ? 'انجام نشد.' : 'That did not work.'),
          error: true);
    }
  } catch (e) {
    if (context.mounted) {
      luxeToast(context, safetyErrorText(e, fa) ?? (fa ? 'انجام نشد.' : 'That did not work.'), error: true);
    }
  }
  return null;
}

/// Whether the signed-in user blocked [userId] (false when unknown).
Future<bool> isBlockedByMe(String userId) async {
  try {
    final dynamic r = await OnlineService.current?.rpc('nx_block_state', <String, dynamic>{'p_user': userId});
    return r is Map && r['blocked_by_me'] == true;
  } catch (_) {
    return false;
  }
}
