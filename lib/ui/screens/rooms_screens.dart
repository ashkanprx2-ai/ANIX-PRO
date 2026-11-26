import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/online/online_service.dart';
import '../../core/online/room_capacity.dart';
import '../../games/game_registry.dart';
import '../kit/station_kit.dart';
import 'game_icons.dart';

// =====================================================================================================================
// ROOMS (`HOME` / `CREATE` / `LIS` of nexora-social.js): live talk rooms + open game rooms from the games project,
// quick play, create a room, join as a listener. The live room itself is TalkRoomPage (LiveKit stage + chat).
// =====================================================================================================================

class _RoomsData {
  List<Map<String, dynamic>> talk = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> games = <Map<String, dynamic>>[];
  bool loading = true;
  bool offline = false;
}

Future<void> _loadRooms(WidgetRef ref, _RoomsData d) async {
  final OnlineService o = ref.read(onlineProvider);
  try {
    if (!o.isOnline) await o.ensureSession();
    final SupabaseClient? c = o.games;
    if (c == null || o.client?.auth.currentSession == null) {
      d
        ..loading = false
        ..offline = true;
      return;
    }
    final List<dynamic> rows = await c
        .from('nx_rooms')
        .select('id, code, game, seats, host, created_at, nx_room_players(count)')
        .eq('status', 'lobby')
        .eq('is_private', false)
        .eq('quick', false)
        .eq('kind', 'game')
        .gte('updated_at', DateTime.now().toUtc().subtract(const Duration(minutes: 20)).toIso8601String())
        .order('created_at', ascending: false)
        .limit(40);
    List<dynamic> talk = const <dynamic>[];
    try {
      talk = (await c.rpc('nx_talk_rooms')) as List<dynamic>? ?? const <dynamic>[];
    } catch (_) {}
    d
      ..talk = talk.map((dynamic r) => Map<String, dynamic>.from(r as Map)).toList()
      ..games = rows.map((dynamic r) => Map<String, dynamic>.from(r as Map)).toList()
      ..loading = false
      ..offline = false;
  } catch (_) {
    d
      ..loading = false
      ..offline = true;
  }
}

int _count(Map<String, dynamic> r) {
  final Object? p = r['nx_room_players'];
  if (p is List && p.isNotEmpty && p.first is Map) return ((p.first as Map)['count'] as num?)?.toInt() ?? 0;
  return 0;
}

/// Opens a conversation room (voice + chat; the game is picked inside) and enters it.
Future<void> stationCreateTalkRoom(BuildContext context, WidgetRef ref, {String? title}) async {
  final String? name = title ??
      await showStationPrompt(
        context,
        title: stx(context, 'ساخت جمع', 'New room'),
        message: stx(context, 'یک نام برای جمع انتخاب کن؛ بعد از ساخت می‌توانی بازی را عوض کنی.', 'Name the room; you can change the game inside.'),
        hint: stx(context, 'مثلاً: دورهمی شبانه', 'e.g. Night hangout'),
        confirm: stx(context, 'ساخت و ورود', 'Create & enter'),
        maxLength: 60,
      );
  if (name == null || !context.mounted) return;
  final OnlineService o = ref.read(onlineProvider);
  try {
    await o.gamesHello();
    final dynamic r = await o.games!.rpc('nx_room_open', params: <String, dynamic>{'p_title': name});
    if (!context.mounted) return;
    await context.push('/room/${(r as Map)['room_id']}');
  } catch (_) {
    if (context.mounted) {
      stationToast(context, stx(context, 'ساخت جمع ممکن نشد. وارد حساب شده‌ای؟', 'Could not create the room. Are you signed in?'), error: true);
    }
  }
}

/// Game picker for quick play / a new game room.
Future<void> stationPickOnlineGame(BuildContext context, String action) async {
  final List<GameInfo> games = kGames.where((GameInfo g) => g.supportsOnline).toList();
  final bool fa = stationFa(context);
  final GameInfo? g = await showStationSheet<GameInfo>(
    context,
    title: action == 'quick' ? stx(context, 'بازی سریع — کدام بازی؟', 'Quick play — which game?') : stx(context, 'ساخت اتاق — کدام بازی؟', 'Create room — which game?'),
    scroll: true,
    child: Builder(
      builder: (BuildContext ctx) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: .86,
        children: <Widget>[
          for (final GameInfo x in games)
            StationTile(
              icon: stationGameIcon(x.id),
              title: fa ? x.nameFa : x.nameEn,
              subtitle: '${capacityOf(x.id).min}–${capacityOf(x.id).max}',
              onTap: () => Navigator.of(ctx).pop(x),
            ),
        ],
      ),
    ),
  );
  if (g == null || !context.mounted) return;
  await context.push('/online/${g.id}?action=$action');
}

/// `HOME` — «جمع‌ها»: hot rooms (talk rooms with listeners / speakers, open game rooms) and «اکیپ».
class StationRoomsScreen extends ConsumerStatefulWidget {
  const StationRoomsScreen({super.key, this.listenOnly = false});

  /// «گوش دادن»: only rooms that are live right now, joined as a listener.
  final bool listenOnly;

  @override
  ConsumerState<StationRoomsScreen> createState() => _StationRoomsScreenState();
}

class _StationRoomsScreenState extends ConsumerState<StationRoomsScreen> {
  final _RoomsData _d = _RoomsData();
  Timer? _poll;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  Future<void> _refresh() async {
    await _loadRooms(ref, _d);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Widget _talkCard(BuildContext context, Map<String, dynamic> r) {
    final StationPalette p = StationPalette.of(context);
    final GameInfo? g = gameById('${r['game']}');
    final int members = (r['members'] as num?)?.toInt() ?? 0;
    final int speakers = (r['speakers'] as num?)?.toInt() ?? (members > 0 ? 1 : 0);
    final bool playing = r['status'] == 'playing';
    final String title = '${r['title'] ?? r['host_name'] ?? 'NEXORA'}';
    return StationCard(
      onTap: () async {
        await context.push('/room/${r['id']}');
        unawaited(_refresh());
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Row(children: <Widget>[
          Stack(clipBehavior: Clip.none, children: <Widget>[
            StationLetter(title, square: true, size: 56),
            if (g != null) PositionedDirectional(end: -6, bottom: -6, child: StationIcon(stationGameIcon(g.id), size: 30, radius: 9)),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Wrap(spacing: 10, children: <Widget>[
                Text('👁 ${nxNum(context, members)} ${stx(context, 'نفر', 'in room')}', style: TextStyle(fontSize: 11.5, color: p.mute)),
                Text('🎙 ${nxNum(context, speakers)} ${stx(context, 'گوینده', 'speaking')}', style: TextStyle(fontSize: 11.5, color: p.mute)),
                if (r['locked'] == true) Text('🔒', style: TextStyle(fontSize: 11.5, color: p.mute)),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 9),
            decoration: BoxDecoration(color: p.isLight ? Colors.white : p.ink, borderRadius: BorderRadius.circular(99),
                border: p.isLight ? Border.all(color: const Color(0xFFD9A93A), width: 2) : null),
            child: Text(playing ? stx(context, 'تماشا', 'Watch') : stx(context, 'پیوستن', 'Join'),
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: p.isLight ? p.ink : const Color(0xFF14110A))),
          ),
          const Spacer(),
          if (g != null) Text(stationFa(context) ? g.nameFa : g.nameEn, style: TextStyle(fontSize: 12, color: p.gold2)),
        ]),
      ]),
    );
  }

  Widget _gameRow(BuildContext context, Map<String, dynamic> r, bool first) {
    final GameInfo? g = gameById('${r['game']}');
    final int n = _count(r), seats = (r['seats'] as num?)?.toInt() ?? 2;
    return StationRow(
      first: first,
      onTap: () async {
        await context.push('/online/${r['game']}?room=${r['id']}');
        unawaited(_refresh());
      },
      leading: StationIcon(stationGameIcon('${r['game']}'), size: 44, radius: 14),
      title: g == null ? '${r['game']}' : (stationFa(context) ? g.nameFa : g.nameEn),
      subtitle: '${stx(context, 'کد', 'CODE')} ${r['code']} · ${nxNum(context, capacityOf('${r['game']}').min)}–${nxNum(context, capacityOf('${r['game']}').max)} ${stx(context, 'بازیکن', 'players')}',
      trailing: StationButton(label: '${nxNum(context, n)}/${nxNum(context, seats)}', small: true, expand: false, onTap: () => context.push('/online/${r['game']}?room=${r['id']}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final List<Map<String, dynamic>> talk = widget.listenOnly ? _d.talk.where((Map<String, dynamic> r) => ((r['members'] as num?) ?? 0) > 0).toList() : _d.talk;
    return StationScreen(
      title: widget.listenOnly ? stx(context, 'گوش دادن', 'Listen') : stx(context, 'روم‌ها', 'Rooms'),
      latin: 'ROOMS',
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 110),
      fab: widget.listenOnly || _d.offline ? null : StationFab(label: stx(context, 'ساخت جمع', 'New room'), onTap: () => stationCreateTalkRoom(context, ref).then((_) => _refresh())),
      children: <Widget>[
        if (!widget.listenOnly)
          StationTabs(labels: <String>[stx(context, 'جمع‌ها', 'Rooms'), stx(context, 'اکیپ', 'Crews')], index: _tab, onChanged: (int i) => setState(() => _tab = i)),
        if (_tab == 1 && !widget.listenOnly) ...<Widget>[
          StationHero(
            icon: 'r3c4',
            title: stx(context, 'اکیپ‌ها و جامعه‌ها', 'Crews & communities'),
            subtitle: stx(context, 'به یک اکیپ بپیوند، رویداد بساز و با هم تورنمنت برو.', 'Join a crew, host events and enter cups together.'),
          ),
          StationButton(label: stx(context, 'دیدن اکیپ‌ها', 'Browse crews'), onTap: () => context.push('/world/social_station')),
        ] else if (_d.loading)
          StationEmpty(text: stx(context, 'در حال دریافت روم‌ها…', 'Loading rooms…'), loading: true)
        else if (_d.offline) ...<Widget>[
          StationEmpty(
            text: stx(context, 'روم‌های زنده به حساب آنلاین نیاز دارند. تا آن موقع با ربات تمرین کن!', 'Live rooms need an online account. Practise with bots meanwhile!'),
            icon: 'r3c1',
            action: stx(context, 'ورود', 'Sign in'),
            onAction: () => context.go('/auth'),
          ),
          StationButton(label: stx(context, 'همه‌ی بازی‌ها (آفلاین)', 'All games (offline)'), ghost: true, onTap: () => context.go('/station/0')),
        ] else ...<Widget>[
          if (!widget.listenOnly)
            Row(children: <Widget>[
              Expanded(child: StationButton(label: stx(context, 'بازی سریع', 'Quick play'), icon: Icons.bolt_rounded, onTap: () => stationPickOnlineGame(context, 'quick'))),
              const SizedBox(width: 10),
              Expanded(
                  child: StationButton(
                      label: stx(context, 'اتاق بازی', 'Game room'), icon: Icons.add_rounded, ghost: true, onTap: () => stationPickOnlineGame(context, 'create'))),
            ]),
          StationTitle(
            stx(context, 'جمع‌های داغ', 'Hot rooms'),
            trailing: Text('(${nxNum(context, talk.length)})', style: TextStyle(fontSize: 12, color: p.mute)),
          ),
          if (talk.isEmpty)
            StationEmpty(
              text: widget.listenOnly
                  ? stx(context, 'الان رومی در حال پخش نیست.', 'No room is live right now.')
                  : stx(context, 'هنوز جمعی باز نیست؛ اولین جمع را تو بساز!', 'No rooms yet — be the first to open one!'),
              icon: 'r3c2',
            )
          else
            for (final Map<String, dynamic> r in talk) _talkCard(context, r),
          if (!widget.listenOnly && _d.games.isNotEmpty) ...<Widget>[
            StationTitle(stx(context, 'اتاق‌های بازی باز', 'Open game rooms')),
            StationRows(children: <Widget>[for (int k = 0; k < _d.games.length; k++) _gameRow(context, _d.games[k], k == 0)]),
          ],
        ],
      ],
    );
  }
}
