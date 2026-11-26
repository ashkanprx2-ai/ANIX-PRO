import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile/profile_service.dart';
import '../../games/arcade_kit/arcade_meta.dart';
import '../../games/game_registry.dart';
import '../../worlds/arcade/game_host_page.dart';
import '../../worlds/arcade/online/online_lobby_page.dart';
import '../kit/station_kit.dart';
import 'game_icons.dart';

/// `GAME(x)` — one game: hero, mode (bot / local / online), difficulty, players, stats, rules, daily challenge and the
/// start button. The launch screen plays, then the real game host (or the online lobby) opens.
class StationGameScreen extends ConsumerStatefulWidget {
  const StationGameScreen({super.key, required this.gameId});
  final String gameId;

  @override
  ConsumerState<StationGameScreen> createState() => _StationGameScreenState();
}

class _StationGameScreenState extends ConsumerState<StationGameScreen> {
  GameMode _mode = GameMode.vsBot;
  BotDifficulty _difficulty = BotDifficulty.normal;
  int _players = 2;
  bool _init = false;

  Future<void> _start(GameInfo g, {bool daily = false}) async {
    final String icon = stationGameIcon(g.id);
    await showStationLaunch(context, name: stationFa(context) ? g.nameFa : g.nameEn, icon: icon);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _mode == GameMode.online && !daily
          ? OnlineLobbyPage(gameId: g.id)
          : GameHostPage(
              game: g,
              mode: daily ? GameMode.vsBot : _mode,
              difficulty: daily ? BotDifficulty.normal : _difficulty,
              players: daily ? (g.solo ? 1 : g.defaultPlayers) : (g.solo ? 1 : _players),
              daily: daily,
            ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final GameInfo? g = gameById(widget.gameId);
    final StationPalette p = StationPalette.of(context);
    if (g == null) {
      return StationScreen(
        title: stx(context, 'بازی', 'Game'),
        children: <Widget>[StationEmpty(text: stx(context, 'این بازی پیدا نشد', 'Game not found'), icon: 'r1c4')],
      );
    }
    if (!_init) {
      _init = true;
      _players = g.defaultPlayers;
    }
    final bool fa = stationFa(context);
    final ProfileService prof = ref.watch(profileProvider);
    final GameStats? st = prof.stats[g.id];
    final List<(GameMode, String)> modes = <(GameMode, String)>[
      (GameMode.vsBot, stx(context, 'با ربات', 'vs bot')),
      if (g.supportsLocal) (GameMode.local, g.id == 'mafia' ? stx(context, 'حالت راوی', 'Narrator') : stx(context, 'با دوستان', 'With friends')),
      if (g.supportsOnline) (GameMode.online, stx(context, 'آنلاین', 'Online')),
    ];
    if (!modes.any(((GameMode, String) m) => m.$1 == _mode)) _mode = modes.first.$1;
    final ArcadeDef? def = kArcadeDefs[g.id];
    return StationScreen(
      title: fa ? g.nameFa : g.nameEn,
      latin: g.nameEn,
      tint: g.accent,
      children: <Widget>[
        StationHero(
          icon: stationGameIcon(g.id),
          title: fa ? g.nameFa : g.nameEn,
          latin: g.nameEn,
          subtitle: fa ? g.taglineFa : g.taglineEn,
          rarity: g.supportsOnline ? 4 : 3,
        ),
        if (!g.solo) ...<Widget>[
          StationTitle(stx(context, 'حالت بازی', 'Game mode')),
          StationSeg(
            labels: <String>[for (final (GameMode, String) m in modes) m.$2],
            index: modes.indexWhere(((GameMode, String) m) => m.$1 == _mode),
            onChanged: (int i) => setState(() => _mode = modes[i].$1),
          ),
          if (_mode == GameMode.vsBot) ...<Widget>[
            StationTitle(stx(context, 'سختی', 'Difficulty')),
            StationSeg(
              labels: <String>[stx(context, 'آسان', 'Easy'), stx(context, 'معمولی', 'Normal'), stx(context, 'سخت', 'Hard')],
              index: _difficulty.index,
              onChanged: (int i) => setState(() => _difficulty = BotDifficulty.values[i]),
            ),
          ],
          if (_mode == GameMode.online)
            StationCard(
              child: Text(
                stx(context, 'با بازیکنان واقعی: بازی سریع، اتاق خصوصی با کد، یا دعوت دوستان. ورودی سکه‌ای فقط در تورنمنت‌هاست.',
                    'Real players: quick match, private room by code, or invite friends. Coin entry fees are tournament-only.'),
                style: TextStyle(fontSize: 12.5, color: p.mute, height: 1.7),
              ),
            ),
          if (g.maxPlayers > 2 && _mode != GameMode.online) ...<Widget>[
            StationTitle(stx(context, 'تعداد بازیکن', 'Players')),
            StationSeg(
              labels: <String>[for (int n = g.minPlayers; n <= g.maxPlayers; n++) nxNum(context, n)],
              index: _players - g.minPlayers,
              onChanged: (int i) => setState(() => _players = g.minPlayers + i),
            ),
          ],
        ],
        StationStats(<(String, String)>[
          (nxNum(context, st?.won ?? 0), stx(context, 'برد', 'Wins')),
          (nxNum(context, st?.lost ?? 0), stx(context, 'باخت', 'Losses')),
          (nxNum(context, def != null ? ArcadeRecords.best(g.id, prof) : (st?.best ?? 0)), stx(context, 'بهترین رکورد', 'Best')),
        ]),
        if (def != null) _daily(context, g, def, prof),
        StationCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(stx(context, 'قوانین', 'Rules'), style: TextStyle(fontSize: 12.5, color: p.gold)),
            const SizedBox(height: 6),
            Text(fa ? g.rulesFa : g.rulesEn, style: TextStyle(fontSize: 13, height: 1.9, color: p.ink)),
          ]),
        ),
        StationButton(
          label: _mode == GameMode.online
              ? stx(context, 'ورود به لابی آنلاین', 'Enter online lobby')
              : g.solo
                  ? stx(context, 'شروع سریع', 'Quick start')
                  : stx(context, 'شروع بازی', 'Start game'),
          icon: _mode == GameMode.online ? Icons.public_rounded : Icons.play_arrow_rounded,
          onTap: () => _start(g),
        ),
        if (g.supportsOnline && g.id != 'mafia' && g.id != 'spy_mafia')
          StationButton(
            label: stx(context, 'تورنمنت‌های این بازی', 'Tournaments for this game'),
            icon: Icons.emoji_events_rounded,
            ghost: true,
            onTap: () => context.push('/tournaments?game=${g.id}'),
          ),
        StationButton(
          label: stx(context, 'رتبه‌بندی این بازی', 'Leaderboard for this game'),
          icon: Icons.leaderboard_rounded,
          ghost: true,
          onTap: () => context.push('/leaderboard?game=${g.id}'),
        ),
      ],
    );
  }

  Widget _daily(BuildContext context, GameInfo g, ArcadeDef def, ProfileService prof) {
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    final bool done = ArcadeRecords.dailyDone(g.id, prof);
    final int target = ArcadeDaily.target(g.id);
    final ArcadeMedal medal = def.medalFor(ArcadeRecords.best(g.id, prof));
    return StationCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        StationRow(
          first: true,
          leading: const StationIcon('r3c5', size: 40),
          title: stx(context, 'چالش روزانه', 'Daily challenge'),
          subtitle: g.solo
              ? (fa ? 'امروز به ${nxNum(context, target)} ${def.unitFa} برس · +۸۰ XP' : 'Reach $target ${def.unitEn} today · +80 XP')
              : stx(context, 'نقشه‌ی امروز: بات‌های سخت را ببر · +۸۰ XP', "Today's map: beat Hard bots · +80 XP"),
          trailing: done
              ? Text('✓', style: TextStyle(fontSize: 18, color: p.gold2))
              : StationButton(label: stx(context, 'شروع', 'Play'), small: true, expand: false, onTap: () => _start(g, daily: true)),
        ),
        if (g.solo)
          StationRow(
            leading: const StationIcon('r4c3', size: 40),
            title: fa ? 'مدال‌ها: برنز ${nxNum(context, def.bronze)} · نقره ${nxNum(context, def.silver)} · طلا ${nxNum(context, def.gold)}'
                : 'Medals: bronze ${def.bronze} · silver ${def.silver} · gold ${def.gold}',
            subtitle: switch (medal) {
              ArcadeMedal.gold => stx(context, 'مدال فعلی: طلا', 'Current medal: gold'),
              ArcadeMedal.silver => stx(context, 'مدال فعلی: نقره', 'Current medal: silver'),
              ArcadeMedal.bronze => stx(context, 'مدال فعلی: برنز', 'Current medal: bronze'),
              ArcadeMedal.none => stx(context, 'هنوز مدالی نگرفته‌ای', 'No medal yet'),
            },
          ),
      ]),
    );
  }
}

/// `GAMES()` — all games as `.gcard`s (all / popular / newest) and the «رکوردها» records list.
class StationGamesScreen extends ConsumerStatefulWidget {
  const StationGamesScreen({super.key, this.records = false});
  final bool records;

  @override
  ConsumerState<StationGamesScreen> createState() => _StationGamesScreenState();
}

class _StationGamesScreenState extends ConsumerState<StationGamesScreen> {
  late int _md = widget.records ? 1 : 0;
  int _f = 0;

  @override
  Widget build(BuildContext context) {
    final ProfileService prof = ref.watch(profileProvider);
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    List<GameInfo> list = List<GameInfo>.from(kGames);
    if (_f == 1) {
      list.sort((GameInfo a, GameInfo b) => (prof.stats[b.id]?.played ?? 0).compareTo(prof.stats[a.id]?.played ?? 0));
    } else if (_f == 2) {
      list = list.where((GameInfo g) => g.isNew).toList();
      if (list.isEmpty) list = kGames.reversed.take(8).toList();
    }
    return StationScreen(
      title: stx(context, 'بازی‌ها', 'Games'),
      latin: 'GAMES',
      children: <Widget>[
        StationSeg(
          labels: <String>[stx(context, 'بازی‌ها', 'Games'), stx(context, 'رکوردها', 'Records')],
          index: _md,
          onChanged: (int i) => setState(() => _md = i),
        ),
        if (_md == 1)
          StationRows(children: <Widget>[
            for (int k = 0; k < kGames.length; k++)
              Builder(builder: (BuildContext context) {
                final GameInfo g = kGames[k];
                final GameStats? s = prof.stats[g.id];
                final int best = kArcadeDefs.containsKey(g.id) ? ArcadeRecords.best(g.id, prof) : (s?.best ?? 0);
                final double wr = (s == null || s.played == 0) ? 0 : s.won / s.played;
                return StationRow(
                  first: k == 0,
                  onTap: () => context.push('/arcade/${g.id}'),
                  leading: StationIcon(stationGameIcon(g.id), size: 40, radius: 14),
                  title: fa ? g.nameFa : g.nameEn,
                  subtitle: fa
                      ? 'بهترین امتیاز ${nxNum(context, best)} · ${nxNum(context, (wr * 100).round())}٪ برد · ${nxNum(context, s?.played ?? 0)} بازی'
                      : 'Best $best · ${(wr * 100).round()}% wins · ${s?.played ?? 0} games',
                  trailing: Text('#${nxNum(context, k + 1)}', style: TextStyle(color: p.gold2, fontWeight: FontWeight.w500)),
                  child: StationBar(wr),
                );
              }),
          ])
        else ...<Widget>[
          StationSeg(
            labels: <String>[stx(context, 'همه', 'All'), stx(context, 'محبوب‌ترین‌ها', 'Most played'), stx(context, 'جدیدترین‌ها', 'Newest')],
            index: _f,
            onChanged: (int i) => setState(() => _f = i),
          ),
          StationGrid(
            gap: 14,
            children: <Widget>[
              for (int k = 0; k < list.length; k++)
                StationGameCard(
                  title: fa ? list[k].nameFa : list[k].nameEn,
                  icon: stationGameIcon(list[k].id),
                  color: p.worldColor(k),
                  meta: <String>[
                    list[k].supportsOnline
                        ? (fa ? '👥 آنلاین ${nxNum(context, list[k].onlineMinPlayers)}–${nxNum(context, list[k].onlineMaxPlayers)}' : '👥 online ${list[k].onlineMinPlayers}–${list[k].onlineMaxPlayers}')
                        : (list[k].solo ? stx(context, 'تک‌نفره', 'Solo') : stx(context, 'آفلاین', 'Offline')),
                  ],
                  onTap: () => context.push('/arcade/${list[k].id}'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
