import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/online/online_service.dart';
import '../../core/profile/profile_service.dart';
import '../../games/arcade_kit/arcade_meta.dart';
import '../../games/game_registry.dart';
import '../kit/station_kit.dart';
import 'game_icons.dart';

/// `BOARD` — leaderboard with the podium (2 · 1 · 3), ranks 4+ and your own row: global XP, per-game rating, and the
/// server-validated solo arcade boards (all-time / today).
class StationBoardScreen extends ConsumerStatefulWidget {
  const StationBoardScreen({super.key, this.initialGame});
  final String? initialGame;

  @override
  ConsumerState<StationBoardScreen> createState() => _StationBoardScreenState();
}

class _StationBoardScreenState extends ConsumerState<StationBoardScreen> {
  late String? _game = widget.initialGame;
  bool _daily = false;
  List<Map<String, dynamic>>? _rows;
  String? _error;

  bool get _solo => _game != null && kArcadeDefs.containsKey(_game) && (gameById(_game!)?.solo ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _rows = null;
      _error = null;
    });
    final OnlineService o = ref.read(onlineProvider);
    try {
      if (!o.isOnline) await o.ensureSession();
      await o.gamesHello();
      final SupabaseClient? c = o.games;
      if (c == null) throw StateError('offline');
      List<Map<String, dynamic>> rows;
      if (_solo) {
        rows = await ArcadeOnline.top(o, _game!, daily: _daily);
      } else {
        final List<dynamic> r = _game == null
            ? await c.from('nx_leaderboard_global').select().order('xp', ascending: false).limit(50)
            : await c.from('nx_leaderboard').select().eq('game', _game!).order('rating', ascending: false).order('won', ascending: false).limit(50);
        rows = r.map((dynamic e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (mounted) setState(() => _rows = rows);
    } catch (_) {
      if (mounted) {
        setState(() {
          _rows = const <Map<String, dynamic>>[];
          _error = 'offline';
        });
      }
    }
  }

  String _score(Map<String, dynamic> r) {
    if (_game == null) return 'XP ${nxNum(context, (r['xp'] as num?)?.toInt() ?? 0)}';
    if (_solo) return nxNum(context, (r['score'] as num?)?.toInt() ?? 0);
    return nxNum(context, (r['rating'] as num?)?.toInt() ?? 1000);
  }

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final ProfileService prof = ref.watch(profileProvider);
    final String? me = ref.watch(onlineProvider).uid;
    final bool fa = stationFa(context);
    final List<Map<String, dynamic>>? rows = _rows;
    final List<GameInfo> games = kGames.where((GameInfo g) => g.supportsOnline || kArcadeDefs.containsKey(g.id)).toList();
    Widget podium(int i, String place, double h) {
      if (rows == null || rows.length <= i) return const Expanded(child: SizedBox.shrink());
      final Map<String, dynamic> r = rows[i];
      final String name = '${r['username'] ?? 'Pilot'}';
      return Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          StationLetter(name, size: 54, imageUrl: r['avatar_url'] as String?),
          const SizedBox(height: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Text(_score(r), style: TextStyle(fontSize: 12, color: p.gold2)),
          const SizedBox(height: 6),
          Container(
            height: h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[p.gold.withValues(alpha: .4), p.gold.withValues(alpha: .04)]),
            ),
            child: Text(place, style: TextStyle(fontFamily: kStationLatin, fontSize: 22, fontWeight: FontWeight.w600, color: p.gold2)),
          ),
        ]),
      );
    }

    return StationScreen(
      title: stx(context, 'برترین‌ها', 'Leaderboard'),
      latin: 'RANKING',
      children: <Widget>[
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6, bottom: 8),
              child: StationPill(label: stx(context, 'همه (XP)', 'All (XP)'), on: _game == null, onTap: () {
                _game = null;
                _load();
              }),
            ),
            for (final GameInfo g in games)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6, bottom: 8),
                child: StationPill(label: fa ? g.nameFa : g.nameEn, on: _game == g.id, onTap: () {
                  _game = g.id;
                  _load();
                }),
              ),
          ]),
        ),
        if (_solo)
          StationSeg(
            labels: <String>[stx(context, 'کل', 'All time'), stx(context, 'امروز', 'Today')],
            index: _daily ? 1 : 0,
            onChanged: (int i) {
              _daily = i == 1;
              _load();
            },
          ),
        if (rows == null)
          StationEmpty(text: stx(context, 'در حال دریافت…', 'Loading…'), loading: true)
        else if (_error != null || rows.isEmpty)
          StationEmpty(
            text: _error != null
                ? stx(context, 'رتبه‌بندی جهانی به اتصال آنلاین نیاز دارد.', 'The global ranking needs an online connection.')
                : stx(context, 'هنوز کسی در این جدول نیست؛ اولین نفر باش!', 'Nobody on this board yet — be the first!'),
            icon: _game == null ? 'r2c6' : stationGameIcon(_game!),
          )
        else ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
              podium(1, '2', 92),
              const SizedBox(width: 10),
              podium(0, '1', 124),
              const SizedBox(width: 10),
              podium(2, '3', 70),
            ]),
          ),
          StationRows(children: <Widget>[
            for (int k = 3; k < rows.length; k++)
              StationRow(
                first: k == 3,
                leading: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  SizedBox(width: 30, child: Text(nxNum(context, k + 1), style: TextStyle(color: p.gold, fontWeight: FontWeight.w500))),
                  StationLetter('${rows[k]['username'] ?? 'P'}', size: 38, imageUrl: rows[k]['avatar_url'] as String?),
                ]),
                title: '${rows[k]['username'] ?? 'Pilot'}${rows[k]['user_id'] == me ? stx(context, ' (تو)', ' (you)') : ''}',
                trailing: Text(_score(rows[k]), style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
            if (me != null && !rows.any((Map<String, dynamic> r) => r['user_id'] == me))
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: <Color>[p.gold.withValues(alpha: .16), p.gold.withValues(alpha: 0)]),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: StationRow(
                  leading: StationRingAvatar(name: prof.username, size: 38, imageUrl: prof.avatarUrl, portrait: prof.portrait),
                  title: stx(context, 'شما', 'You'),
                  trailing: Text(_game == null ? 'XP ${nxNum(context, prof.xp)}' : '—', style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
              ),
          ]),
        ],
      ],
    );
  }
}
