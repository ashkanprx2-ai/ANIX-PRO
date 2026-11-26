import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/audio/music_service.dart';
import '../../../core/audio/sfx_service.dart';
import '../../../core/backend/backend_gateway.dart';
import '../../../core/online/cloud_profile_sync.dart';
import '../../../core/online/match_link.dart';
import '../../../core/economy/victory_fx.dart';
import '../../../core/online/match_rematch.dart';
import '../../../core/online/match_resume.dart';
import '../../../core/online/online_service.dart';
import '../../../core/online/room_voice.dart';
import '../../../core/online/social_api.dart';
import '../../../core/safety/safety_actions.dart';

import '../../../core/profile/profile_service.dart';
import '../../../core/settings/app_settings.dart';
import '../../../ui/kit/station_compat.dart';
import '../../../games/game_registry.dart';
import '../../oracle_core/persona/oracle_persona.dart';
import '../../oracle_core/persona/oracle_persona_widgets.dart';


/// Hosts one online match: opens the move link, builds the game in online mode,
/// rebuilds + replays the log on reconnect/resync, reports the result and shows it.
class OnlineMatchPage extends ConsumerStatefulWidget {
  const OnlineMatchPage(
      {super.key,
      required this.matchId,
      required this.gameId,
      this.tournamentMatchId,
      this.spectate = false});
  final String matchId;
  final String gameId;

  /// RS-01: watch read-only (room member / invited by a player). The game is drawn from seat 0's side, touches are
  /// ignored, nothing is sent, reported, recorded or rewarded, and leaving is free.
  final bool spectate;

  /// Set when this game belongs to a tournament match: the result is also reported to the tournament
  /// (nx_t_report — both players' reports must agree, otherwise it becomes a dispute).
  final String? tournamentMatchId;

  @override
  ConsumerState<OnlineMatchPage> createState() => _OnlineMatchPageState();
}

class _OnlineMatchPageState extends ConsumerState<OnlineMatchPage>
    with WidgetsBindingObserver {
  SupabaseMatchLink? _link;
  String? _error;
  int _generation = 0;
  bool _finished = false;
  GameResult? _result;
  String? _oracleLine;
  String? _resultNoteFa;
  String? _resultNoteEn;
  bool _recorded = false;
  bool _graceStarted = false;

  /// Rematch on the result screen for every game but finger soccer (which offers it on its own score table).
  MatchRematchController? _rematch;

  bool get _watching => _link?.isSpectator ?? false;

  /// The game id from the caller, or (resume route without one) from the match row.
  String get _gameId => widget.gameId.isNotEmpty ? widget.gameId : (_link?.game ?? '');

  @override
  void initState() {
    super.initState();
    MusicService.instance.enterGame();
    WidgetsBinding.instance.addObserver(this);
    OpenMatchTracker.openMatchId.value = widget.matchId;
    unawaited(_open());
  }

  Future<void> _open() async {
    final OnlineService o = ref.read(onlineProvider);
    final client = o.games;
    final String? uid = o.uid;
    if (client == null || uid == null) {
      setState(() => _error = 'offline');
      return;
    }
    if (_error != null) setState(() => _error = null);
    // The match row is read once to build the game: a single network blip used to leave the player on
    // "Could not open the match" with no way back in while the others waited. Retry with back-off first.
    Object? last;
    for (int attempt = 0; attempt < 4; attempt++) {
      try {
        final SupabaseMatchLink link =
            await SupabaseMatchLink.open(client, widget.matchId, uid: uid, spectate: widget.spectate);
        if (!mounted) {
          link.dispose();
          return;
        }
        if (link.mySeat < 0 || (link.isSpectator && !isSpectatableGame(link.game))) {
          link.dispose();
          unawaited(ActiveMatchStore.maybeInstance?.clear(matchId: widget.matchId));
          setState(() => _error = 'not_player');
          return;
        }
        link.addListener(_onLinkChanged);
        link.resyncRequests.addListener(_onResync);
        setState(() => _link = link);
        if (link.isOver) {
          _onLinkChanged();
        } else if (!link.isSpectator) {
          _rememberMatch(uid, link);
        }
        return;
      } catch (e) {
        last = e;
        if (widget.spectate && e is PostgrestException && e.code == 'PGRST116') {
          // RLS hid the row: not allowed to watch (not a member / not invited / blocked / ended)
          setState(() => _error = 'not_player');
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 700 * (attempt + 1)));
        if (!mounted) return;
      }
    }
    if (mounted) setState(() => _error = '$last');
  }

  /// Keeps this live match on the device so the player can come back into it after the app was killed
  /// (MatchResumeWatcher asks the server on the next start whether it is still on).
  void _rememberMatch(String uid, SupabaseMatchLink link) {
    final ActiveMatchStore? store = ActiveMatchStore.maybeInstance;
    if (store == null) return;
    unawaited(store.save(ActiveMatchRecord(
      matchId: widget.matchId,
      gameId: _gameId.isNotEmpty ? _gameId : link.game,
      uid: uid,
      tournamentMatchId: widget.tournamentMatchId,
    )));
  }

  void _forgetMatch() => unawaited(ActiveMatchStore.maybeInstance?.clear(matchId: widget.matchId));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from background: rebuild from the server log so this phone catches up exactly.
    if (state == AppLifecycleState.resumed && _link != null && !_finished) {
      _onResync();
    }
  }

  void _onResync() {
    if (!mounted || _finished) return;
    setState(() => _generation++);
  }

  void _onLinkChanged() {
    final SupabaseMatchLink? l = _link;
    if (l == null || !mounted) return;
    final MatchEnd? end = l.end;
    if (l.isSpectator) {
      if (end != null && !_finished) _finishWatching(l, end);
      setState(() {});
      return;
    }
    if (end != null) _forgetMatch();
    if (end != null && !_finished && end.isAbandoned) {
      // The match was called off before it began (a player backed out of matchmaking at the same instant), or the
      // server closed it after nothing happened for a long time (_nx_match_sweep): no result, no rewards — straight
      // back to the lobby, which looks for a new match.
      _finished = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(l.hasLog
              ? context.tx('بازی به‌خاطر عدم فعالیت بسته شد', 'The match was closed after a long time with no play')
              : context.tx('حریف قبل از شروع خارج شد؛ بازی لغو شد',
                  'A player left before the start — match cancelled'))));
      Navigator.of(context).pop('abandoned');
      return;
    }
    if (end != null && !_finished && !end.isForfeit && !_graceStarted) {
      // Another phone reported the normal end first: our deterministic game ends the same way in a moment.
      _graceStarted = true;
      Future<void>.delayed(const Duration(seconds: 8), () {
        if (mounted && !_finished) _onLinkChanged();
      });
      setState(() {});
      return;
    }
    if (end != null && !_finished) {
      // Ended on the server without our game finishing (forfeit / opponent left).
      final bool won = end.winners.contains(l.mySeat);
      final bool draw = end.winners.isEmpty;
      final int? fs = end.forfeitSeat;
      final String who =
          fs != null && fs >= 0 && fs < l.names.length ? l.names[fs] : '';
      _resultNoteFa = fs == l.mySeat
          ? 'از بازی خارج شدی'
          : (fs != null ? '$who از بازی خارج شد' : null);
      _resultNoteEn = fs == l.mySeat
          ? 'You left the match'
          : (fs != null ? '$who left the match' : null);
      _finish(
          GameResult(
            outcome: draw
                ? GameOutcome.draw
                : (won ? GameOutcome.win : GameOutcome.loss),
            summaryFa: _resultNoteFa ?? '',
            summaryEn: _resultNoteEn ?? '',
          ),
          report: false);
    } else {
      setState(() {});
    }
  }

  List<int> _winnersFor(GameResult r, SupabaseMatchLink l) {
    if (r.winnerSeats != null) return r.winnerSeats!;
    if (r.outcome == GameOutcome.draw) return <int>[];
    if (r.outcome == GameOutcome.win) return <int>[l.mySeat];
    return <int>[
      for (int s = 0; s < l.seatCount; s++)
        if (s != l.mySeat) s
    ];
  }

  void _onGameFinish(GameResult r) {
    final SupabaseMatchLink? l = _link;
    if (l != null && l.isSpectator) {
      // the watcher's copy of the game reached its end: wait for the server's result (never report)
      if (l.end != null) _finishWatching(l, l.end!);
      return;
    }
    _finish(r, report: true);
  }

  /// Spectator: the match is over on the server. Shows who won; nothing is recorded or rewarded.
  void _finishWatching(SupabaseMatchLink l, MatchEnd end) {
    if (_finished) return;
    _finished = true;
    final String who = end.winners.where((int s) => s >= 0 && s < l.names.length).map((int s) => l.names[s]).join('، ');
    unawaited(Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _result = GameResult(
            outcome: GameOutcome.draw,
            summaryFa: end.winners.isEmpty ? 'بازی مساوی شد' : 'برنده: $who',
            summaryEn: end.winners.isEmpty ? 'The match ended in a draw' : 'Winner: $who',
          ));
    }));
  }

  /// Generic rematch (match_rematch.dart) for the result screen: room matches, not tournaments, not finger soccer.
  void _startRematchOffer() {
    if (_rematch != null || _watching || _gameId == 'finger_soccer' || widget.tournamentMatchId != null) return;
    final MatchRematchController? c =
        MatchRematchController.forLink(_link, tournamentMatchId: widget.tournamentMatchId, onGo: _goRematch);
    if (c == null) return;
    c.tableDone(); // no score table here: the result overlay is already up
    _rematch = c;
  }

  /// Everyone accepted and the new match exists: leave this page; the room page opens the new match as usual.
  void _goRematch(String matchId) {
    if (!mounted) return;
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    final NavigatorState? nav = Navigator.maybeOf(context);
    if (route == null || nav == null) return;
    if (route.isCurrent) {
      nav.pop('rematch');
    } else {
      nav.removeRoute(route);
    }
  }

  void _finish(GameResult r, {required bool report}) {
    if (_finished) return;
    _finished = true;
    if (r.endsMatch) _forgetMatch();
    if (r.outcome != GameOutcome.draw) NxSfx.instance.play(r.outcome == GameOutcome.win ? 'win' : 'lose');
    final SupabaseMatchLink? l = _link;
    if (ref.read(settingsProvider).haptics) HapticFeedback.heavyImpact();
    if (l != null && report && r.endsMatch) {
      unawaited(l
          .report(_winnersFor(r, l), r.scores)
          .then((_) => ref.read(cloudSyncProvider).refreshWallet()));
      if (widget.tournamentMatchId != null) unawaited(_reportTournament(r, l));
    } else {
      unawaited(ref.read(cloudSyncProvider).refreshWallet());
    }
    if (!_recorded) {
      _recorded = true;
      _oracleLine = OraclePersona.instance.resultReaction(
          outcome: switch (r.outcome) { GameOutcome.win => 'win', GameOutcome.loss => 'loss', GameOutcome.draw => 'draw' },
          myScore: r.score,
          oppScore: r.opponentScore);
      final GameInfo? g = gameById(_gameId);
      ref.read(profileProvider).recordOnlineGame(
            gameId: _gameId,
            gameNameFa: g?.nameFa ?? _gameId,
            gameNameEn: g?.nameEn ?? _gameId,
            outcome: switch (r.outcome) {
              GameOutcome.win => 'win',
              GameOutcome.loss => 'loss',
              GameOutcome.draw => 'draw'
            },
            score: r.score,
          );
    }
    final Future<void> hold = Future<void>.delayed(Duration(milliseconds: report ? (r.holdMs ?? 900) : 200));
    // a game may keep its end screen up a little longer (GameResult.holdUntil, e.g. a pending rematch request);
    // capped so the result overlay always comes up
    final Future<void>? extra = report ? r.holdUntil?.timeout(const Duration(seconds: 90), onTimeout: () {}).catchError((Object _) {}) : null;
    unawaited((extra == null ? hold : Future.wait(<Future<void>>[hold, extra])).then((_) {
      if (!mounted) return;
      _startRematchOffer();
      setState(() => _result = r);
    }));
  }

  /// Tournament: this phone's own report of the game (seat 0 = home). Retries a few times on bad network.
  Future<void> _reportTournament(GameResult r, SupabaseMatchLink l) async {
    final List<int> winners = _winnersFor(r, l);
    final int winnerSeat = winners.length == 1 ? winners.first : -1;
    final List<int> s = List<int>.filled(l.seatCount < 2 ? 2 : l.seatCount, 0);
    final List<int>? scores = r.scores;
    if (scores != null && scores.length >= 2) {
      s[0] = scores[0];
      s[1] = scores[1];
    } else if (l.mySeat >= 0 && l.mySeat < 2) {
      s[l.mySeat] = r.score;
      s[1 - l.mySeat] = r.opponentScore;
    }
    // keep the report consistent with the winner (the server rejects contradictions)
    if (winnerSeat == 0 && s[0] < s[1]) s[0] = s[1];
    if (winnerSeat == 1 && s[1] < s[0]) s[1] = s[0];
    if (winnerSeat == -1 && s[0] != s[1]) s[1] = s[0];
    for (int attempt = 0; attempt < 4; attempt++) {
      try {
        await ref
            .read(onlineProvider)
            .games
            ?.rpc('nx_t_report', params: <String, dynamic>{
          'p_game': widget.matchId,
          'p_winner_seat': winnerSeat,
          'p_s0': s[0],
          'p_s1': s[1],
        });
        return;
      } catch (e) {
        debugPrint('tournament report failed (try $attempt): $e');
        await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
  }

  Future<bool> _confirmLeave() async {
    if (_finished || _link == null || _watching) return true;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AnixDialog(
        title: Text(ctx.tx('ترک بازی آنلاین؟', 'Leave the online match?')),
        content: Text(ctx.tx(
            'خروج یعنی تسلیم: در بازی دونفره حریف برنده می‌شود.',
            'Leaving counts as a forfeit: in a 2-player game your opponent wins.')),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tx('ادامه', 'Keep playing'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NxColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tx('تسلیم و خروج', 'Forfeit & leave')),
          ),
        ],
      ),
    );
    if (ok == true) {
      _finished = true;
      _forgetMatch();
      await _link?.forfeit();
      return true;
    }
    return false;
  }

  /// A game that draws its own chrome during the match (GameLaunch.immersive): the corner buttons, presence dots and
  /// tutorial banner hide, and the voice controls move to the bottom centre, below the game's playfield.
  final ValueNotifier<bool> _immersive = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _rematch?.dispose();
    _immersive.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (OpenMatchTracker.openMatchId.value == widget.matchId) OpenMatchTracker.openMatchId.value = null;
    final SupabaseMatchLink? l = _link;
    if (l != null) {
      if (l.isOver && !l.isSpectator) _forgetMatch();
      l.removeListener(_onLinkChanged);
      l.resyncRequests.removeListener(_onResync);
      l.dispose();
    }
    MusicService.instance.exitGame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(backendProvider);
    final AppSettings s = ref.watch(settingsProvider);
    final SupabaseMatchLink? l = _link;
    final GameInfo? game = gameById(_gameId);
    Widget body;
    if (_error != null) {
      body = Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Text(widget.spectate
            ? context.tx('تماشای این بازی ممکن نیست', 'This match can not be watched')
            : context.tx('ورود به بازی ممکن نشد', 'Could not open the match')),
        if (_error != 'not_player' && _error != 'offline') ...<Widget>[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => unawaited(_open()),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.tx('تلاش دوباره', 'Try again')),
          ),
        ],
      ]));
    } else if (l == null || game == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final GameLaunch launch = GameLaunch(
        gameId: _gameId,
        mode: GameMode.online,
        difficulty: BotDifficulty.normal,
        playerName: l.mySeat >= 0 && l.mySeat < l.names.length
            ? l.names[l.mySeat]
            : 'Explorer',
        isFa: s.isFa,
        fancyEffects: s.fancyEffects,
        reducedMotion: s.reducedMotion,
        soundOn: s.sound,
        playerCount: l.seatCount,
        skins: Map<String, String>.from(ref.read(profileProvider).equipped),
        seed: l.seed,
        net: l,
        onFinish: _onGameFinish,
        immersive: _immersive,
      );
      final Widget gameView = KeyedSubtree(
        key: ValueKey<int>(_generation),
        child: game.builder(launch),
      );
      // a spectator's touches never reach the game (it also can not send anything: SupabaseMatchLink.isSpectator)
      body = l.isSpectator ? IgnorePointer(child: gameView) : gameView;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (didPop) return;
        final NavigatorState nav = Navigator.of(context);
        if (await _confirmLeave()) nav.pop();
      },
      child: Scaffold(
        backgroundColor: NxColors.luxeBg,
        body: Stack(children: <Widget>[
          Positioned.fill(child: body),
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: _immersive,
              builder: (BuildContext context, bool hide, Widget? chrome) =>
                  hide && _result == null ? const SizedBox.shrink() : chrome!,
              child: Stack(children: <Widget>[
          PositionedDirectional(
            top: MediaQuery.paddingOf(context).top + 6,
            start: 6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.35),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () async {
                  final NavigatorState nav = Navigator.of(context);
                  if (await _confirmLeave()) nav.pop();
                },
              ),
            ),
          ),
          if (l != null && _result == null)
            PositionedDirectional(
                top: MediaQuery.paddingOf(context).top + 10,
                end: 10,
                child: _presenceBar(l)),
          // RS-01: a player may invite a friend to watch (read-only) while the match runs
          if (l != null && !l.isSpectator && !l.isOver && _result == null && isSpectatableGame(l.game))
            PositionedDirectional(
              top: MediaQuery.paddingOf(context).top + 6,
              start: 56,
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: context.tx('دعوت دوست به تماشا', 'Invite a friend to watch'),
                  icon: const Icon(Icons.visibility_rounded, color: Colors.white, size: 20),
                  onPressed: () => unawaited(_inviteWatcher(l)),
                ),
              ),
            ),
          if (l != null && l.isSpectator && _result == null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 0,
              right: 0,
              child: IgnorePointer(child: Center(child: _watchBadge(context))),
            ),
          if (_result == null && !_watching)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 58,
              left: 0,
              right: 0,
              child: OracleTutorialBanner(gameId: _gameId),
            ),
              ]),
            ),
          ),
          // In-match voice: mic mute/unmute + speaker on/off (same LiveKit room as the lobby). An immersive game keeps
          // a bottom strip free of play for it, so it sits centred there.
          // spectators stay out of the players' voice room (no coaching from the stands)
          if (_result == null && !_watching)
            ValueListenableBuilder<bool>(
              valueListenable: _immersive,
              // One stable tree in both modes (only the alignment changes), so the voice bar keeps its connection.
              builder: (BuildContext context, bool immersive, Widget? bar) => Positioned(
                left: 10,
                right: 10,
                bottom: MediaQuery.paddingOf(context).bottom + (immersive ? 8 : 10),
                child: Align(
                  alignment: immersive ? Alignment.center : AlignmentDirectional.centerEnd,
                  child: bar,
                ),
              ),
              child: RoomVoiceBar(id: widget.matchId, match: true, compact: true),
            ),
          if (_result != null && !_watching && _result!.outcome == GameOutcome.win)
            Positioned.fill(child: _victoryFx(s)),
          if (_result != null)
            Positioned.fill(child: _watching ? _watchOverlay(context, _result!) : _overlay(context, _result!)),
        ]),
      ),
    );
  }

  /// Friends list -> nx_invite_watch (server checks: caller plays this match, not blocked, not banned, watchable).
  Future<void> _inviteWatcher(SupabaseMatchLink l) async {
    final OnlineService o = ref.read(onlineProvider);
    final c = o.games;
    if (c == null) return;
    List<NxUser> friends = <NxUser>[];
    try {
      final a = o.social;
      if (a != null) friends = await SocialApi(a).friends();
    } catch (_) {}
    if (!mounted) return;
    final Set<String> playing = l.names.toSet();
    await showAnixSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: friends.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(ctx.tx('هنوز دوستی نداری.', 'No friends yet.')),
              )
            : ListView(shrinkWrap: true, children: <Widget>[
                for (final NxUser f in friends)
                  if (!playing.contains(f.username))
                    ListTile(
                      leading: const Icon(Icons.person_rounded),
                      title: Text(f.username),
                      trailing: FilledButton(
                        onPressed: () async {
                          final bool fa = ctx.isFa;
                          final String sent = fa ? 'دعوت به تماشا فرستاده شد' : 'Watch invite sent';
                          final String notSent = fa ? 'دعوت فرستاده نشد' : 'Invite not sent';
                          String msg;
                          bool bad = false;
                          try {
                            final dynamic r = await c.rpc('nx_invite_watch',
                                params: <String, dynamic>{'p_match': widget.matchId, 'p_user': f.id});
                            final bool ok = r is Map && r['ok'] == true;
                            bad = !ok;
                            msg = ok ? sent : notSent;
                          } catch (e) {
                            bad = true;
                            msg = safetyErrorText(e, fa) ?? notSent;
                          }
                          if (!mounted) return;
                          luxeToast(context, msg, error: bad);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(ctx.tx('دعوت', 'Invite')),
                      ),
                    ),
              ]),
      ),
    );
  }

  Widget _victoryFx(AppSettings s) {
    final VictoryFx? fx = equippedVictoryFx(ref.read(profileProvider));
    if (fx == null) return const SizedBox.shrink();
    return VictoryFxBurst(fx: fx, reducedMotion: s.reducedMotion);
  }

  Widget _watchBadge(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NxColors.gold.withValues(alpha: .6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          const Icon(Icons.visibility_rounded, size: 14, color: NxColors.gold),
          const SizedBox(width: 5),
          Text(context.tx('در حال تماشا', 'Watching'),
              style: const TextStyle(color: NxColors.gold, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      );

  /// Spectator end screen: the server's result, no rewards, back.
  Widget _watchOverlay(BuildContext context, GameResult r) {
    final String summary = context.tx(r.summaryFa, r.summaryEn);
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        const Icon(Icons.flag_rounded, color: NxColors.gold, size: 64),
        const SizedBox(height: 10),
        Text(context.tx('بازی تمام شد', 'Match over'),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: NxColors.gold)),
        if (summary.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(summary, textAlign: TextAlign.center, style: const TextStyle(color: NxColors.ink)),
        ],
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          label: Text(context.tx('بازگشت', 'Back')),
        ),
      ]),
    );
  }

  Widget _presenceBar(SupabaseMatchLink l) {
    final int? rtt = l.rttMs;
    final Color pingColor = rtt == null
        ? NxColors.textDim
        : (rtt < 85 ? NxColors.success : (rtt < 170 ? NxColors.gold : NxColors.danger));
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          if (rtt != null) ...<Widget>[
            Icon(Icons.network_check_rounded, size: 12, color: pingColor),
            const SizedBox(width: 3),
            Text(
              '${rtt}ms',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: pingColor),
            ),
            const SizedBox(width: 5),
          ],
          for (int s = 0; s < l.seatCount; s++)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: l.forfeitedSeats.contains(s)
                      ? NxColors.danger
                      : (l.connectedSeats.contains(s)
                          ? NxColors.success
                          : NxColors.gold),
                  border: s == l.mySeat
                      ? Border.all(color: Colors.white, width: 1.5)
                      : null,
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _overlay(BuildContext context, GameResult r) {
    final (String title, Color color, IconData icon) = switch (r.outcome) {
      GameOutcome.win => (
          context.tx('پیروزی!', 'Victory!'),
          NxColors.gold,
          Icons.emoji_events_rounded
        ),
      GameOutcome.draw => (
          context.tx('مساوی', 'Draw'),
          NxColors.champagne,
          Icons.handshake_rounded
        ),
      GameOutcome.loss => (
          context.tx('شکست', 'Defeat'),
          NxColors.danger,
          Icons.sentiment_dissatisfied_rounded
        ),
    };
    final String summary = context.tx(r.summaryFa, r.summaryEn);
    final String reward = switch (r.outcome) {
      GameOutcome.win => '+80 XP · +50',
      GameOutcome.draw => '+40 XP · +20',
      GameOutcome.loss => '+20 XP · +8',
    };
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Icon(icon, color: color, size: 72),
        const SizedBox(height: 10),
        Text(title,
            style: TextStyle(
                fontSize: 34, fontWeight: FontWeight.w900, color: color)),
        if (summary.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(summary,
              textAlign: TextAlign.center,
              style: const TextStyle(color: NxColors.ink)),
        ],
        if (_oracleLine != null) OracleResultLine(text: _oracleLine!),
        const SizedBox(height: 10),
        Text(
            '${context.tx('بازی آنلاین ثبت شد', 'Online match recorded')} · $reward 🪙',
            style: const TextStyle(color: NxColors.textDim)),
        if (widget.tournamentMatchId != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                context.tx(
                    'نتیجه برای تورنمنت ارسال شد؛ با تأیید هر دو بازیکن ثبت می‌شود.',
                    'Result sent to the tournament; it counts once both players agree.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: NxColors.gold, fontSize: 12)),
          ),
        if (_rematch != null) ...<Widget>[
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: MatchRematchPanel(c: _rematch!, fa: context.isFa),
          ),
        ],
        if (r.outcome == GameOutcome.win)
          TextButton.icon(
            onPressed: () => showVictoryFxShop(context, fa: context.isFa),
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: Text(context.tx('افکت پیروزی', 'Victory effect')),
          ),
        const SizedBox(height: 22),
        if (_link != null && _link!.seatCount > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton.icon(
              onPressed: () {
                final SupabaseMatchLink l = _link!;
                reportMatchPlayer(context,
                    matchId: widget.matchId,
                    myId: OnlineService.current?.uid,
                    game: l.game,
                    players: <(String, String)>[
                      for (int i = 0; i < l.playerIds.length; i++)
                        if (i != l.mySeat) (l.playerIds[i], i < l.names.length ? l.names[i] : 'Pilot ${i + 1}'),
                    ]);
              },
              icon: const Icon(Icons.flag_outlined, size: 18, color: NxColors.textDim),
              label: Text(context.tx('گزارش بازیکن', 'Report a player'),
                  style: const TextStyle(color: NxColors.textDim)),
            ),
          ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(widget.tournamentMatchId != null
              ? Icons.emoji_events_rounded
              : Icons.meeting_room_rounded),
          label: Text(widget.tournamentMatchId != null
              ? context.tx('بازگشت به تورنمنت', 'Back to the tournament')
              : context.tx('بازگشت به اتاق', 'Back to the room')),
        ),
      ]),
    );
  }
}

/// Games a spectator can follow from the public move log. The server-authoritative hidden-information games (each
/// player sees only their own view) are not watchable; the server enforces the same list (nx_can_spectate).
bool isSpectatableGame(String gameId) => !const <String>{'mafia', 'spy_mafia', 'uno', 'quiz'}.contains(gameId);
