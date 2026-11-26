import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/online/online_service.dart';
import '../../core/online/social_api.dart';
import '../../core/profile/profile_service.dart';
import '../../worlds/orbit_network/models/orbit_models.dart';
import '../../worlds/orbit_network/state/orbit_controller.dart';
import '../../worlds/orbit_network/ui/orbit_call_page.dart';
import '../../worlds/orbit_network/ui/orbit_chat_page.dart';
import '../kit/station_kit.dart';

// =====================================================================================================================
// CHAT world: GAPS (chat list), openChat (conversation), FR (friends), SG (send gift), VIEW (contacts) —
// nexora-social.js / nexora-screens.js on the real Orbit chats and the social API.
// =====================================================================================================================

String stationChatTitle(BuildContext context, OrbitChat c) => switch (c.kind) {
      OrbitChatKind.saved => stx(context, 'پیام‌های ذخیره‌شده', 'Saved messages'),
      OrbitChatKind.direct => (c.peerName ?? '').isNotEmpty ? c.peerName! : c.name,
      _ => c.name,
    };

String _hhmm(BuildContext context, DateTime t) {
  final DateTime l = t.toLocal();
  final DateTime n = DateTime.now();
  if (l.year == n.year && l.month == n.month && l.day == n.day) {
    final String z = stationFa(context) ? '۰' : '0';
    return '${nxNum(context, l.hour, group: false).padLeft(2, z)}:${nxNum(context, l.minute, group: false).padLeft(2, z)}';
  }
  if (n.difference(l).inDays < 2) return stx(context, 'دیروز', 'Yesterday');
  return '${nxNum(context, l.day)}/${nxNum(context, l.month)}';
}

String _preview(BuildContext context, OrbitMessage? m) {
  if (m == null) return '';
  return switch (m.kind) {
    OrbitMessageKind.text || OrbitMessageKind.system => m.text,
    OrbitMessageKind.invite => stx(context, '🎮 دعوت به بازی', '🎮 Game invite'),
    OrbitMessageKind.photo => stx(context, '📷 عکس', '📷 Photo'),
    OrbitMessageKind.audio => stx(context, '🎤 پیام صوتی', '🎤 Voice message'),
    OrbitMessageKind.call => stx(context, '📞 تماس', '📞 Call'),
    OrbitMessageKind.file => stx(context, '📎 فایل', '📎 File'),
    _ => m.text.isEmpty ? '✨' : m.text,
  };
}

/// `GAPS` — the chat list with search, unread badges and «＋ جدید».
class StationChatsScreen extends ConsumerStatefulWidget {
  const StationChatsScreen({super.key});

  @override
  ConsumerState<StationChatsScreen> createState() => _StationChatsScreenState();
}

class _StationChatsScreenState extends ConsumerState<StationChatsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final OrbitController ctl = ref.watch(orbitControllerProvider);
    final StationPalette p = StationPalette.of(context);
    final List<OrbitChatSummary> list = ctl.summaries.where((OrbitChatSummary s) => _q.isEmpty || stationChatTitle(context, s.chat).contains(_q)).toList();
    return StationScreen(
      title: stx(context, 'گپ‌ها', 'Chats'),
      latin: 'GAPS',
      actions: <Widget>[
        StationRoundButton(icon: Icons.call_rounded, tooltip: stx(context, 'تماس‌ها و مخاطبین', 'Calls & contacts'), onTap: () => context.push('/world/orbit_network')),
      ],
      fab: StationFab(label: stx(context, 'جدید', 'New'), onTap: () => context.push('/s/friends')),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 110),
      children: <Widget>[
        StationInput(hint: stx(context, 'جست‌وجو در گپ‌ها…', 'Search chats…'), onChanged: (String v) => setState(() => _q = v.trim())),
        const SizedBox(height: 12),
        if (ctl.loading)
          StationEmpty(text: stx(context, 'در حال دریافت…', 'Loading…'), loading: true)
        else if (list.isEmpty)
          StationEmpty(
            text: stx(context, 'هنوز گفتگویی نداری. با یک دوست شروع کن!', 'No chats yet. Start one with a friend!'),
            icon: 'r3c3',
            action: stx(context, 'دوستان', 'Friends'),
            onAction: () => context.push('/s/friends'),
          )
        else
          StationRows(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), children: <Widget>[
            for (int k = 0; k < list.length; k++)
              StationRow(
                first: k == 0,
                onTap: () => context.push('/chat/${list[k].chat.id}'),
                leading: StationLetter(
                  stationChatTitle(context, list[k].chat),
                  square: true,
                  size: 46,
                  online: list[k].chat.kind == OrbitChatKind.direct && list[k].chat.peerOnlineAt != null &&
                      DateTime.now().toUtc().difference(list[k].chat.peerOnlineAt!.toUtc()).inMinutes < 3,
                  badge: list[k].chat.kind == OrbitChatKind.channel || list[k].chat.kind == OrbitChatKind.saved
                      ? Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: p.gold, border: Border.all(color: const Color(0xFF0C0D12), width: 2)),
                          child: const Text('✓', style: TextStyle(fontSize: 10, color: Color(0xFF1A1408))),
                        )
                      : null,
                ),
                title: stationChatTitle(context, list[k].chat),
                subtitle: _preview(context, list[k].last),
                trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
                  Text(list[k].last == null ? '' : _hhmm(context, list[k].last!.createdAt), style: TextStyle(fontSize: 11, color: p.mute)),
                  const SizedBox(height: 6),
                  if (list[k].unread > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(gradient: p.primary, borderRadius: BorderRadius.circular(10)),
                      child: Text(nxNum(context, list[k].unread), style: TextStyle(fontSize: 11, color: p.primaryInk)),
                    )
                  else
                    const Text('✓✓', style: TextStyle(fontSize: 11, color: Color(0xFF7BE0A4))),
                ]),
              ),
          ]),
      ],
    );
  }
}

/// `openChat` — a conversation: bubbles, the pinned input, voice/video call and the full tools (media, invites,
/// members) one tap away.
class StationChatScreen extends ConsumerStatefulWidget {
  const StationChatScreen({super.key, required this.chatId});
  final String chatId;

  @override
  ConsumerState<StationChatScreen> createState() => _StationChatScreenState();
}

class _StationChatScreenState extends ConsumerState<StationChatScreen> {
  final TextEditingController _in = TextEditingController();
  final ScrollController _sc = ScrollController();
  late final OrbitController _ctl = ref.read(orbitControllerProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_ctl.openChat(widget.chatId).then((_) => _end()));
  }

  @override
  void dispose() {
    _ctl.closeChat(widget.chatId);
    _in.dispose();
    _sc.dispose();
    super.dispose();
  }

  void _end() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) _sc.animateTo(_sc.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: kStationEase);
    });
  }

  Future<void> _send() async {
    final String t = _in.text.trim();
    if (t.isEmpty) return;
    _in.clear();
    await _ctl.send(widget.chatId, authorName: ref.read(profileProvider).username, text: t);
    _end();
  }

  void _call(OrbitChat chat, bool video) {
    if (!chat.online) {
      stationToast(context, stx(context, 'تماس فقط با حساب آنلاین ممکن است', 'Calls need an online account'));
      return;
    }
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (BuildContext c) => OrbitCallPage(chatId: chat.id, title: stationChatTitle(c, chat), video: video),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final OrbitController ctl = ref.watch(orbitControllerProvider);
    final StationPalette p = StationPalette.of(context);
    final OrbitChat? chat = ctl.chatById(widget.chatId);
    final List<OrbitMessage> msgs = ctl.messagesOf(widget.chatId).where((OrbitMessage m) => !m.deleted).toList();
    final String me = ctl.ownerId;
    return StationScreen(
      title: chat == null ? stx(context, 'گفتگو', 'Chat') : stationChatTitle(context, chat),
      latin: 'CHAT',
      balance: false,
      actions: <Widget>[
        if (chat != null && chat.kind != OrbitChatKind.saved) ...<Widget>[
          StationRoundButton(icon: Icons.call_rounded, onTap: () => _call(chat, false), tooltip: stx(context, 'تماس صوتی', 'Voice call')),
          StationRoundButton(icon: Icons.videocam_rounded, onTap: () => _call(chat, true), tooltip: stx(context, 'تماس تصویری', 'Video call')),
        ],
        StationRoundButton(
          icon: Icons.more_horiz_rounded,
          tooltip: stx(context, 'ابزارهای گفتگو', 'Chat tools'),
          onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => OrbitChatPage(chatId: widget.chatId))),
        ),
      ],
      bottom: Container(
        padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 12),
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[p.bg.withValues(alpha: 0), p.bg], stops: const <double>[0, .35])),
        child: Row(children: <Widget>[
          Expanded(child: StationInput(controller: _in, hint: stx(context, 'پیام…', 'Message…'), onSubmitted: (_) => _send(), maxLines: 4)),
          const SizedBox(width: 8),
          StationRoundButton(icon: Icons.send_rounded, size: 46, active: true, onTap: _send),
        ]),
      ),
      child: msgs.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: StationEmpty(text: stx(context, 'اولین پیام را بفرست 👋', 'Send the first message 👋'), icon: 'r3c3'),
            )
          : ListView.builder(
              controller: _sc,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              itemCount: msgs.length,
              itemBuilder: (BuildContext context, int i) {
                final OrbitMessage m = msgs[i];
                final bool mine = m.authorId == me;
                final bool showName = !mine && chat != null && chat.kind != OrbitChatKind.direct;
                return Align(
                  alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: mine ? p.primary : (p.isLight ? null : p.glass),
                      color: mine ? null : (p.isLight ? Colors.white : null),
                      border: mine ? null : Border.all(color: p.isLight ? const Color(0xFFD19A22) : p.line, width: p.isLight ? 2 : 1),
                      borderRadius: BorderRadiusDirectional.only(
                        topStart: const Radius.circular(18),
                        topEnd: const Radius.circular(18),
                        bottomStart: Radius.circular(mine ? 4 : 18),
                        bottomEnd: Radius.circular(mine ? 18 : 4),
                      ),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
                      if (showName) Text(m.authorName, style: TextStyle(fontSize: 11, color: p.gold)),
                      Text(_preview(context, m), style: TextStyle(fontSize: 13.5, color: mine ? p.primaryInk : p.ink, height: 1.6)),
                      Text(_hhmm(context, m.createdAt),
                          style: TextStyle(fontSize: 10, color: (mine ? p.primaryInk : p.mute).withValues(alpha: .7))),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

/// Shared loader for the social API (signed-in only).
SocialApi? _api(WidgetRef ref) {
  final OnlineService o = ref.read(onlineProvider);
  final SupabaseClient? c = o.client;
  if (c == null || c.auth.currentSession == null) return null;
  return SocialApi(c, userId: o.uid);
}

/// `FR` — friends with search (people directory), online dots, «پیام» and «بازی».
class StationFriendsScreen extends ConsumerStatefulWidget {
  const StationFriendsScreen({super.key});

  @override
  ConsumerState<StationFriendsScreen> createState() => _StationFriendsScreenState();
}

class _StationFriendsScreenState extends ConsumerState<StationFriendsScreen> {
  List<NxUser>? _friends;
  List<NxUser> _found = const <NxUser>[];
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _deb?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final SocialApi? api = _api(ref);
    List<NxUser> f = const <NxUser>[];
    try {
      if (api != null) f = await api.friends();
    } catch (_) {}
    if (mounted) setState(() => _friends = f);
  }

  void _search(String q) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 350), () async {
      final SocialApi? api = _api(ref);
      if (api == null || q.trim().length < 2) {
        if (mounted) setState(() => _found = const <NxUser>[]);
        return;
      }
      try {
        final List<NxUser> r = await api.search(q.trim());
        if (mounted) setState(() => _found = r);
      } catch (_) {}
    });
  }

  Future<void> _message(NxUser u) async {
    final String? id = await ref.read(orbitControllerProvider).openDirect(u.id);
    if (!mounted) return;
    if (id == null) {
      stationToast(context, stx(context, 'پیام فقط با حساب آنلاین ممکن است', 'Messaging needs an online account'));
      return;
    }
    context.push('/chat/$id');
  }

  Widget _row(BuildContext context, NxUser u, bool first) => StationRow(
        first: first,
        leading: StationLetter(u.displayName ?? u.username, imageUrl: u.avatarUrl, online: u.isOnlineNow),
        title: u.displayName?.isNotEmpty == true ? u.displayName! : u.username,
        subtitle: u.isOnlineNow ? stx(context, 'آنلاین', 'Online') : '@${u.username}',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          StationButton(label: stx(context, 'پیام', 'Message'), small: true, ghost: true, expand: false, onTap: () => _message(u)),
          const SizedBox(width: 6),
          StationButton(label: stx(context, 'بازی', 'Play'), small: true, expand: false, onTap: () => context.push('/rooms')),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final List<NxUser>? f = _friends;
    final bool online = _api(ref) != null;
    return StationScreen(
      title: stx(context, 'دوستان', 'Friends'),
      children: <Widget>[
        StationInput(hint: stx(context, 'جست‌وجوی دوستان…', 'Search people…'), onChanged: _search),
        const SizedBox(height: 12),
        if (!online)
          StationEmpty(
            text: stx(context, 'دوستان و پیام‌ها به حساب آنلاین نیاز دارند.', 'Friends and messages need an online account.'),
            icon: 'r3c4',
            action: stx(context, 'ورود', 'Sign in'),
            onAction: () => context.push('/auth'),
          )
        else ...<Widget>[
          if (_found.isNotEmpty) ...<Widget>[
            StationTitle(stx(context, 'نتیجه‌ی جست‌وجو', 'Search results')),
            StationRows(children: <Widget>[for (int k = 0; k < _found.length; k++) _row(context, _found[k], k == 0)]),
          ],
          StationTitle(stx(context, 'دوستان من', 'My friends')),
          if (f == null)
            StationEmpty(text: stx(context, 'در حال دریافت…', 'Loading…'), loading: true)
          else if (f.isEmpty)
            StationEmpty(text: stx(context, 'هنوز دوستی نداری؛ بالا اسم یک نفر را جست‌وجو کن.', 'No friends yet — search for someone above.'), icon: 'r3c4')
          else
            StationRows(children: <Widget>[for (int k = 0; k < f.length; k++) _row(context, f[k], k == 0)]),
        ],
      ],
    );
  }
}

/// `SG` — send a gift: pick a friend and a gift sticker; it arrives in your chat with them.
class StationSendGiftScreen extends ConsumerStatefulWidget {
  const StationSendGiftScreen({super.key});

  @override
  ConsumerState<StationSendGiftScreen> createState() => _StationSendGiftScreenState();
}

class _StationSendGiftScreenState extends ConsumerState<StationSendGiftScreen> {
  List<NxUser>? _friends;
  int _f = 0, _g = 0;
  bool _busy = false;

  static const List<(String, String, String, String)> kGifts = <(String, String, String, String)>[
    ('r3c6', '🎁', 'گل', 'Flower'),
    ('r4c3', '🏅', 'مدال', 'Medal'),
    ('r2c5', '🏆', 'جام', 'Cup'),
    ('r4c4', '👑', 'تاج', 'Crown'),
  ];

  @override
  void initState() {
    super.initState();
    final SocialApi? api = _api(ref);
    (api == null ? Future<List<NxUser>>.value(const <NxUser>[]) : api.friends().catchError((_) => const <NxUser>[])).then((List<NxUser> l) {
      if (mounted) setState(() => _friends = l);
    });
  }

  Future<void> _send() async {
    final List<NxUser> f = _friends ?? const <NxUser>[];
    if (f.isEmpty) return;
    setState(() => _busy = true);
    final NxUser to = f[_f];
    final bool fa = stationFa(context);
    final OrbitController ctl = ref.read(orbitControllerProvider);
    final String? chat = await ctl.openDirect(to.id);
    final (String, String, String, String) gift = kGifts[_g];
    if (chat != null) {
      await ctl.send(chat,
          authorName: ref.read(profileProvider).username, text: '${gift.$2} ${fa ? 'یک ${gift.$3} برایت فرستادم!' : 'I sent you a ${gift.$4}!'}');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (chat == null) {
      stationToast(context, stx(context, 'ارسال ممکن نشد', 'Could not send'), error: true);
      return;
    }
    await showStationModal(context, big: gift.$2, title: stx(context, 'ارسال شد', 'Sent'), text: stationFa(context) ? 'هدیه به ${to.username} رسید' : 'Your gift reached ${to.username}');
  }

  @override
  Widget build(BuildContext context) {
    final List<NxUser>? f = _friends;
    final bool fa = stationFa(context);
    return StationScreen(
      title: stx(context, 'ارسال هدیه', 'Send gift'),
      children: <Widget>[
        StationTitle(stx(context, 'گیرنده', 'Recipient')),
        if (f == null)
          StationEmpty(text: stx(context, 'در حال دریافت…', 'Loading…'), loading: true)
        else if (f.isEmpty)
          StationEmpty(
            text: stx(context, 'برای هدیه دادن اول یک دوست اضافه کن (حساب آنلاین لازم است).', 'Add a friend first to send gifts (online account needed).'),
            icon: 'r3c6',
            action: stx(context, 'دوستان', 'Friends'),
            onAction: () => context.push('/s/friends'),
          )
        else
          StationSeg(labels: <String>[for (final NxUser u in f) u.username], index: _f, onChanged: (int i) => setState(() => _f = i)),
        StationTitle(stx(context, 'هدیه', 'Gift')),
        StationGrid(children: <Widget>[
          for (int k = 0; k < kGifts.length; k++)
            StationTile(
              icon: kGifts[k].$1,
              title: fa ? kGifts[k].$3 : kGifts[k].$4,
              subtitle: stx(context, 'هدیه‌ی دوستانه', 'Friendly gift'),
              on: k == _g,
              onTap: () => setState(() => _g = k),
            ),
        ]),
        StationButton(label: stx(context, 'ارسال هدیه', 'Send gift'), busy: _busy, onTap: (f?.isNotEmpty ?? false) ? _send : null),
      ],
    );
  }
}

/// `VIEW` — «کی منو دیده؟ / مخاطبین»: people who follow you and people you follow (the server has no profile-view
/// log, so the page shows your real audience instead of invented visits).
class StationViewersScreen extends ConsumerStatefulWidget {
  const StationViewersScreen({super.key});

  @override
  ConsumerState<StationViewersScreen> createState() => _StationViewersScreenState();
}

class _StationViewersScreenState extends ConsumerState<StationViewersScreen> {
  List<NxUser>? _following;
  List<NxUser>? _friends;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    final SocialApi? api = _api(ref);
    if (api == null) {
      _following = const <NxUser>[];
      _friends = const <NxUser>[];
      return;
    }
    api.following().then((List<NxUser> l) {
      if (mounted) setState(() => _following = l);
    }).catchError((_) {
      if (mounted) setState(() => _following = const <NxUser>[]);
    });
    api.friends().then((List<NxUser> l) {
      if (mounted) setState(() => _friends = l);
    }).catchError((_) {
      if (mounted) setState(() => _friends = const <NxUser>[]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final List<NxUser>? list = _tab == 0 ? _friends : _following;
    return StationScreen(
      title: stx(context, 'مخاطبین', 'Contacts'),
      latin: 'VIEWERS',
      children: <Widget>[
        StationCard(
          child: Column(children: <Widget>[
            Text(stx(context, 'چه کسانی با تو در ارتباطند؟', 'Who is connected with you?'),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
            const SizedBox(height: 6),
            Text(stx(context, 'دوستان و کسانی که دنبالشان می‌کنی', 'Your friends and the people you follow'),
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: p.mute)),
          ]),
        ),
        StationTabs(labels: <String>[stx(context, 'دوستان', 'Friends'), stx(context, 'دنبال‌شده‌ها', 'Following')], index: _tab, onChanged: (int i) => setState(() => _tab = i)),
        if (list == null)
          StationEmpty(text: stx(context, 'در حال دریافت…', 'Loading…'), loading: true)
        else if (list.isEmpty)
          StationEmpty(text: stx(context, 'هنوز کسی اینجا نیست.', 'Nobody here yet.'), icon: 'r3c4')
        else
          for (final NxUser u in list)
            StationCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(children: <Widget>[
                StationLetter(u.username, square: true, imageUrl: u.avatarUrl, online: u.isOnlineNow),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(u.displayName?.isNotEmpty == true ? u.displayName! : u.username, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('@${u.username} · ${stx(context, 'سطح', 'Lv')} ${nxNum(context, u.level)}', style: TextStyle(fontSize: 11, color: p.mute)),
                  ]),
                ),
              ]),
            ),
      ],
    );
  }
}
