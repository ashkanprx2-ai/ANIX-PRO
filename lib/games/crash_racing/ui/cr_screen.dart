import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../arcade_kit/arcade_result.dart';
import '../../core/game_contract.dart';
import '../core/cr_race.dart';
import '../core/cr_track.dart';
import '../data/cr_board.dart';
import 'cr_art.dart';
import 'cr_audio.dart';
import 'cr_session.dart';
import 'cr_text.dart';

enum CrPhase { title, character, track, race, results, board }

const Color _kOrange = Color(0xFFFF8A1E);
const Color _kGold = Color(0xFFFFD34E);
const Color _kInk = Color(0xFF1A0E00);
const Color _kNight = Color(0xFF0E1630);

TextStyle _display(double size, {Color color = Colors.white}) => TextStyle(
      fontFamily: 'Lalezar',
      fontSize: size,
      height: 1.15,
      color: color,
      shadows: const <Shadow>[
        Shadow(color: _kInk, offset: Offset(0, 3)),
        Shadow(color: Color(0xAA000000), offset: Offset(0, 5), blurRadius: 8),
      ],
    );

TextStyle _body(double size, {Color color = Colors.white, FontWeight w = FontWeight.w500}) =>
    TextStyle(fontFamily: 'Vazirmatn', fontSize: size, height: 1.35, color: color, fontWeight: w);

/// «کرش ریسینگ»: title → driver select → track select → race (Flame) → podium → host result.
class CrashRacingGame extends StatefulWidget {
  const CrashRacingGame({
    super.key,
    required this.launch,
    this.debugPhase,
    this.debugTrack,
    this.debugCharacter,
    this.debugAutopilot = false,
    this.onSession,
  });

  final GameLaunch launch;

  /// Tests: open straight on a phase (title / race / board).
  final CrPhase? debugPhase;
  final String? debugTrack;
  final int? debugCharacter;
  final bool debugAutopilot;
  final void Function(CrSession session)? onSession;

  @override
  State<CrashRacingGame> createState() => _CrashRacingGameState();
}

class _CrashRacingGameState extends State<CrashRacingGame> {
  static int _lastChar = 0;
  static String _lastTrack = 'jungle';

  CrPhase phase = CrPhase.title;
  int character = _lastChar;
  String trackId = _lastTrack;
  CrArt? art = CrArt.ready;
  CrSession? session;
  CrFlameGame? game;
  late final CrAudio audio = CrAudio(enabled: widget.launch.soundOn);
  bool paused = false;
  bool _reported = false;
  final FocusNode _focus = FocusNode();

  // results
  List<int> _order = const <int>[];
  bool _newBest = false;
  String _submit = '';
  final Map<String, int> _bestRace = <String, int>{};

  GameLaunch get l => widget.launch;
  bool get fa => l.isFa;
  String tx(String f, String e) => fa ? f : e;

  @override
  void initState() {
    super.initState();
    character = widget.debugCharacter ?? character;
    trackId = widget.debugTrack ?? trackId;
    unawaited(SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) l.immersive?.value = true;
    });
    if (art == null) {
      unawaited(CrArt.load().then((CrArt a) {
        if (mounted) setState(() => art = a);
      }));
    }
    for (final CrTrackInfo t in kCrTracks) {
      unawaited(CrBoard.localBest(t.id).then((int v) {
        if (mounted && v > 0) setState(() => _bestRace[t.id] = v);
      }));
    }
    final CrPhase? dp = widget.debugPhase;
    if (dp == CrPhase.race) {
      _startRace();
    } else if (dp != null) {
      phase = dp;
    }
  }

  @override
  void dispose() {
    _restoreOrientation();
    session?.finished.removeListener(_onFinished);
    session?.dispose();
    audio.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _restoreOrientation() {
    unawaited(SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]));
  }

  double get _botSkill => switch (l.daily ? BotDifficulty.hard : l.difficulty) {
        BotDifficulty.easy => 0.86,
        BotDifficulty.normal => 0.92,
        BotDifficulty.hard => 0.975,
      };

  void _startRace() {
    final CrArt? a = art;
    if (a == null) return;
    _lastChar = character;
    _lastTrack = trackId;
    session?.finished.removeListener(_onFinished);
    session?.dispose();
    final CrSession s = CrSession(
      trackId: trackId,
      character: character,
      art: a,
      audio: audio,
      fa: fa,
      haptics: !l.reducedMotion,
      botSkill: _botSkill,
      seed: l.seed ?? DateTime.now().millisecondsSinceEpoch & 0xffff,
      autopilot: widget.debugAutopilot,
    );
    s.finished.addListener(_onFinished);
    session = s;
    game = CrFlameGame(s);
    paused = false;
    phase = CrPhase.race;
    widget.onSession?.call(s);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _onFinished() {
    final CrSession? s = session;
    if (s == null || !s.finished.value) return;
    _order = List<int>.of(s.race.finishOrder);
    final CrRacer me = s.race.player;
    final int raceMs = (me.finishTime * 1000).round();
    final int lapMs = (me.bestLap * 1000).round();
    _submit = '';
    unawaited(CrBoard.saveLocal(trackId, raceMs, lapMs).then(((bool, bool) r) {
      if (!mounted) return;
      setState(() {
        _newBest = r.$1;
        if (r.$1) _bestRace[trackId] = raceMs;
      });
    }));
    unawaited(CrBoard.submit(
      track: trackId,
      character: kCrCharIds[character],
      raceMs: raceMs,
      bestLapMs: lapMs,
      place: me.place,
    ).then((bool ok) {
      if (mounted) setState(() => _submit = ok ? tx('در جدول جهانی ثبت شد', 'Posted to the global board') : '');
    }));
    if (mounted) setState(() => phase = CrPhase.results);
  }

  void _report() {
    if (_reported) return;
    final CrSession? s = session;
    if (s == null) return;
    _reported = true;
    final CrRace r = s.race;
    final List<int> order = _order.isEmpty ? List<int>.of(r.order) : _order;
    final int place = order.indexOf(0) + 1;
    final List<int> scores = List<int>.filled(6, 0);
    for (int i = 0; i < order.length; i++) {
      scores[order[i]] = 6 - i;
    }
    final String t = crFormatTime(r.player.finishTime, true);
    l.immersive?.value = false;
    _restoreOrientation();
    l.onFinish(GameResult(
      outcome: place == 1 ? GameOutcome.win : GameOutcome.loss,
      score: 7 - place,
      opponentScore: place == 1 ? 5 : 6,
      winnerSeats: <int>[order.first],
      scores: scores,
      summaryFa: '${crTrackInfo(trackId).nameFa} · نفر ${ordinalFa(place)} از ۶ · $t',
      summaryEn: '${crTrackInfo(trackId).nameEn} · ${ordinalEn(place)} of 6 · ${crFormatTime(r.player.finishTime, false)}',
      tournamentMatchId: l.tournamentMatchId,
      durationMs: (r.player.finishTime * 1000).round(),
      holdMs: 250,
    ));
  }

  void _pause(bool on) {
    final CrFlameGame? g = game;
    if (g == null) return;
    setState(() => paused = on);
    if (on) {
      g.pauseEngine();
    } else {
      g.resumeEngine();
    }
  }

  void _exit() => unawaited(Navigator.maybePop(context));

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final CrSession? s = session;
    if (s == null || phase != CrPhase.race) return KeyEventResult.ignored;
    final bool down = e is KeyDownEvent || e is KeyRepeatEvent;
    final LogicalKeyboardKey k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      s.left = down;
    } else if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) {
      s.right = down;
    } else if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.shiftLeft) {
      s.drift = down;
    } else if (k == LogicalKeyboardKey.keyX && e is KeyDownEvent) {
      s.tapTurbo();
    } else if ((k == LogicalKeyboardKey.keyZ || k == LogicalKeyboardKey.enter) && e is KeyDownEvent) {
      s.tapItem();
    } else if (k == LogicalKeyboardKey.escape && e is KeyDownEvent) {
      _pause(!paused);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _go(CrPhase p) {
    audio.play('select', volume: 0.5);
    setState(() => phase = p);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (phase) {
      CrPhase.title => _title(),
      CrPhase.character => _characterSelect(),
      CrPhase.track => _trackSelect(),
      CrPhase.race => _race(),
      CrPhase.results => _results(),
      CrPhase.board => _CrBoardView(fa: fa, onBack: () => _go(CrPhase.title), initialTrack: trackId),
    };
    return Directionality(
      textDirection: fa ? TextDirection.rtl : TextDirection.ltr,
      child: ColoredBox(color: _kNight, child: body),
    );
  }

  // ------------------------------------------------------------------ menus
  /// Lays a menu out on an 800-wide design canvas scaled to the screen (never overflows in either orientation).
  Widget _canvas(Widget Function(Size s) child) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
      final double w = c.maxWidth, h = c.maxHeight;
      if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) return const SizedBox.shrink();
      const double dw = 800;
      final double dh = math.max(360, dw * h / w);
      final Size s = Size(dw, dh);
      return FittedBox(fit: BoxFit.contain, child: SizedBox(width: s.width, height: s.height, child: child(s)));
    });
  }

  Widget _bg(String asset, {double dim = 0.45}) => Positioned.fill(
        child: Stack(fit: StackFit.expand, children: <Widget>[
          Image.asset('$kCrDir$asset', fit: BoxFit.cover, cacheWidth: 1024, filterQuality: FilterQuality.medium),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.black.withValues(alpha: dim * 0.5), Colors.black.withValues(alpha: dim)],
              ),
            ),
          ),
        ]),
      );

  Widget _topBar(String title, VoidCallback onBack) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(children: <Widget>[
          _RoundIcon(icon: fa ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 12),
          Text(title, style: _display(30)),
        ]),
      );

  Widget _title() {
    return _canvas((Size s) => Stack(children: <Widget>[
          _bg('title.webp', dim: 0.25),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: s.height * 0.55,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x88000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
          Positioned(top: 14, left: 14, child: _RoundIcon(icon: Icons.close_rounded, onTap: _exit)),
          Positioned(
            top: s.height * 0.07,
            left: 0,
            right: 0,
            child: Column(children: <Widget>[
              _Logo(text: tx('کرش ریسینگ', 'CRASH RACING'), size: fa ? 74 : 62),
              Transform.translate(
                offset: const Offset(0, -6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F6BFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: Text(tx('نیترو', 'NITRO'), style: _display(22)),
                ),
              ),
            ]),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              _PillButton(
                label: tx('رکوردها', 'Records'),
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFF2F6BFF),
                onTap: () => _go(CrPhase.board),
              ),
              const SizedBox(width: 18),
              _PillButton(
                label: tx('شروع مسابقه', 'Start race'),
                icon: Icons.flag_rounded,
                color: _kOrange,
                big: true,
                onTap: () => _go(CrPhase.character),
              ),
            ]),
          ),
        ]));
  }

  Widget _characterSelect() {
    final CrCharacter ch = kCrCharacters[character];
    return _canvas((Size s) => Stack(children: <Widget>[
          _bg('bg_jungle.webp', dim: 0.6),
          Column(children: <Widget>[
            _topBar(tx('انتخاب راننده', 'Choose your driver'), () => _go(CrPhase.title)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: Row(children: <Widget>[
                  // grid
                  Expanded(
                    flex: 11,
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.08,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: <Widget>[
                        for (int i = 0; i < kCrCharacters.length; i++)
                          _CharTile(
                            index: i,
                            selected: i == character,
                            fa: fa,
                            onTap: () {
                              audio.play('select', volume: 0.5);
                              setState(() => character = i);
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // detail
                  Expanded(
                    flex: 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xCC0E1630),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Color(ch.color), width: 3),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Column(children: <Widget>[
                        Expanded(
                          child: Row(children: <Widget>[
                            Expanded(
                              child: Image.asset('${kCrDir}char_${kCrCharIds[character]}.webp',
                                  cacheWidth: 360, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(fa ? ch.nameFa : ch.nameEn, style: _display(26), maxLines: 1),
                                  Container(
                                    margin: const EdgeInsets.only(top: 2, bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: Color(ch.color), borderRadius: BorderRadius.circular(8)),
                                    child: Text(ch.classFa, style: _body(12, w: FontWeight.w700)),
                                  ),
                                  _StatBar(label: tx('سرعت', 'Speed'), value: ch.speed),
                                  _StatBar(label: tx('شتاب', 'Accel'), value: ch.accel),
                                  _StatBar(label: tx('فرمان', 'Turn'), value: ch.turn),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        SizedBox(
                          height: 74,
                          child: Row(children: <Widget>[
                            Image.asset('${kCrDir}kart_${kCrCharIds[character]}.webp', cacheWidth: 200, height: 70),
                            const Spacer(),
                            _PillButton(
                              label: tx('بعدی', 'Next'),
                              icon: fa ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                              color: _kOrange,
                              onTap: () => _go(CrPhase.track),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ]));
  }

  Widget _trackSelect() {
    return _canvas((Size s) => Stack(children: <Widget>[
          _bg('bg_${trackId == 'temple' ? 'temple' : trackId == 'beach' ? 'beach' : 'jungle'}.webp', dim: 0.6),
          Column(children: <Widget>[
            _topBar(tx('انتخاب پیست', 'Choose a track'), () => _go(CrPhase.character)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(children: <Widget>[
                  for (final CrTrackInfo t in kCrTracks)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _TrackCard(
                          info: t,
                          selected: t.id == trackId,
                          fa: fa,
                          best: _bestRace[t.id] ?? 0,
                          onTap: () {
                            audio.play('select', volume: 0.5);
                            setState(() => trackId = t.id);
                          },
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 4),
              child: _PillButton(
                label: tx('مسابقه!', 'Race!'),
                icon: Icons.sports_score_rounded,
                color: _kOrange,
                big: true,
                onTap: art == null
                    ? null
                    : () {
                        audio.play('select', volume: 0.5);
                        setState(_startRace);
                      },
              ),
            ),
          ]),
        ]));
  }

  // ------------------------------------------------------------------ race
  Widget _race() {
    final CrSession? s = session;
    final CrFlameGame? g = game;
    if (s == null || g == null) return const SizedBox.shrink();
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    s.padTop = pad.top + 8;
    s.padLeft = pad.left + 6;
    s.padRight = pad.right + 6;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
        final double u = math.min(c.maxWidth, c.maxHeight * 1.9) / 800;
        final double btn = 86 * u;
        return Stack(children: <Widget>[
          Positioned.fill(child: RepaintBoundary(child: GameWidget<CrFlameGame>(game: g))),
          // countdown
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<int>(
                valueListenable: s.countdown,
                builder: (BuildContext context, int v, _) {
                  if (v < 0) return const SizedBox.shrink();
                  final String t = v == 0 ? tx('برو!', 'GO!') : CrText.digits('$v', fa);
                  return Align(
                    alignment: const Alignment(0, -0.25),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey<int>(v),
                      tween: Tween<double>(begin: 1.8, end: 1),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      builder: (BuildContext context, double k, Widget? child) => Transform.scale(scale: k, child: child),
                      child: Text(t, style: _display(110 * u, color: v == 0 ? const Color(0xFF7CFF5A) : _kGold)),
                    ),
                  );
                },
              ),
            ),
          ),
          // banner
          Positioned(
            left: 0,
            right: 0,
            top: c.maxHeight * 0.2,
            child: IgnorePointer(
              child: ValueListenableBuilder<String>(
                valueListenable: s.banner,
                builder: (BuildContext context, String v, _) => v.isEmpty
                    ? const SizedBox.shrink()
                    : Center(child: Text(v, style: _display(40 * u, color: _kGold))),
              ),
            ),
          ),
          // pause
          Positioned(
            top: pad.top + 8,
            left: pad.left + 8,
            child: _RoundIcon(icon: Icons.pause_rounded, onTap: () => _pause(true), size: 46 * math.max(u, 0.8)),
          ),
          // steering (physical left side for every locale)
          Positioned(
            left: pad.left + 14 * u,
            bottom: 14 * u,
            child: Row(textDirection: TextDirection.ltr, children: <Widget>[
              _HoldButton(
                size: btn,
                icon: Icons.chevron_left_rounded,
                onChange: (bool d) => s.left = d,
              ),
              SizedBox(width: 14 * u),
              _HoldButton(
                size: btn,
                icon: Icons.chevron_right_rounded,
                onChange: (bool d) => s.right = d,
              ),
            ]),
          ),
          // drift / turbo / item
          Positioned(
            right: pad.right + 14 * u,
            bottom: 14 * u,
            child: SizedBox(
              width: btn * 2.35,
              height: btn * 2.05,
              child: Stack(children: <Widget>[
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: s.turboWindow,
                    builder: (BuildContext context, bool hot, _) => _HoldButton(
                      size: btn * 1.18,
                      label: tx('دریفت', 'DRIFT'),
                      color: hot ? const Color(0xFFFF3B2F) : _kOrange,
                      glow: hot,
                      onChange: (bool d) => s.drift = d,
                    ),
                  ),
                ),
                Positioned(
                  right: btn * 1.28,
                  bottom: btn * 0.02,
                  child: _TapButton(
                    size: btn * 0.86,
                    label: tx('توربو', 'TURBO'),
                    color: const Color(0xFF2F6BFF),
                    onTap: s.tapTurbo,
                  ),
                ),
                Positioned(
                  right: btn * 0.2,
                  bottom: btn * 1.24,
                  child: _TapButton(
                    size: btn * 0.78,
                    label: tx('آیتم', 'ITEM'),
                    color: const Color(0xFF9B3BFF),
                    onTap: s.tapItem,
                  ),
                ),
              ]),
            ),
          ),
          if (paused) Positioned.fill(child: _pauseOverlay()),
        ]);
      }),
    );
  }

  Widget _pauseOverlay() {
    return ColoredBox(
      color: const Color(0xAA000000),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          decoration: BoxDecoration(
            color: _kNight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kGold, width: 3),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text(tx('توقف', 'Paused'), style: _display(34)),
            const SizedBox(height: 10),
            _PillButton(label: tx('ادامه', 'Resume'), icon: Icons.play_arrow_rounded, color: _kOrange, onTap: () => _pause(false), wide: true),
            const SizedBox(height: 8),
            _PillButton(
              label: tx('شروع دوباره', 'Restart'),
              icon: Icons.replay_rounded,
              color: const Color(0xFF2F6BFF),
              wide: true,
              onTap: () => setState(_startRace),
            ),
            const SizedBox(height: 8),
            _PillButton(label: tx('خروج', 'Quit'), icon: Icons.logout_rounded, color: const Color(0xFF59607A), wide: true, onTap: _exit),
          ]),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ results
  Widget _results() {
    final CrSession? s = session;
    if (s == null) return const SizedBox.shrink();
    final CrRace r = s.race;
    final List<int> order = _order.isEmpty ? List<int>.of(r.order) : _order;
    final int myPlace = order.indexOf(0) + 1;
    String nameOf(int i) {
      final CrRacer rc = r.racers[i];
      if (rc.isPlayer) return l.playerName.isEmpty ? tx('تو', 'You') : l.playerName;
      final CrCharacter ch = kCrCharacters[rc.character];
      return fa ? ch.nameFa : ch.nameEn;
    }

    Widget podium(int place, double height) {
      if (order.length < place) return const SizedBox.shrink();
      final CrRacer rc = r.racers[order[place - 1]];
      const List<Color> colors = <Color>[Color(0xFFFFC21A), Color(0xFFC9D3E0), Color(0xFFCD7F32)];
      return Column(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
        Flexible(
          child: SizedBox(
            height: 118,
            child: Image.asset('${kCrDir}char_${kCrCharIds[rc.character]}.webp', cacheWidth: 256, fit: BoxFit.contain),
          ),
        ),
        Text(nameOf(rc.index), style: _body(12, w: FontWeight.w700, color: rc.isPlayer ? _kGold : Colors.white), maxLines: 1),
        Container(
          width: 92,
          height: height,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[colors[place - 1], Color.lerp(colors[place - 1], Colors.black, 0.45)!],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
          ),
          alignment: Alignment.topCenter,
          child: Text(CrText.digits('$place', fa), style: _display(40)),
        ),
      ]);
    }

    return _canvas((Size sz) => Stack(children: <Widget>[
          _bg('bg_${crTrackInfo(trackId).theme.name}.webp', dim: 0.55),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              // podium
              Expanded(
                flex: 10,
                child: Column(children: <Widget>[
                  Text(
                    myPlace == 1
                        ? tx('قهرمان شدی!', 'You won!')
                        : tx('نفر ${ordinalFa(myPlace)} شدی', 'You finished ${ordinalEn(myPlace)}'),
                    style: _display(36, color: myPlace == 1 ? _kGold : Colors.white),
                  ),
                  if (_newBest)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(10)),
                      child: Text(tx('رکورد جدید!', 'New record!'), style: _body(13, w: FontWeight.w700)),
                    ),
                  Expanded(
                    child: Row(
                      textDirection: TextDirection.ltr,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[podium(2, 70), const SizedBox(width: 8), podium(1, 100), const SizedBox(width: 8), podium(3, 50)],
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 14),
              // table
              Expanded(
                flex: 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xD90E1630),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kGold.withValues(alpha: 0.8), width: 2),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(children: <Widget>[
                    Row(children: <Widget>[
                      Text(fa ? crTrackInfo(trackId).nameFa : crTrackInfo(trackId).nameEn, style: _display(20, color: _kGold)),
                      const Spacer(),
                      Text(tx('بهترین دور', 'Best lap'), style: _body(11, color: Colors.white70)),
                      const SizedBox(width: 24),
                    ]),
                    const SizedBox(height: 4),
                    for (int i = 0; i < order.length; i++)
                      _ResultRow(
                        place: i + 1,
                        name: nameOf(order[i]),
                        character: r.racers[order[i]].character,
                        time: crFormatTime(r.racers[order[i]].finishTime, fa),
                        lap: crFormatTime(r.racers[order[i]].bestLap, fa),
                        me: order[i] == 0,
                        fa: fa,
                      ),
                    const Spacer(),
                    if (_submit.isNotEmpty) Text(_submit, style: _body(11, color: const Color(0xFF7CFF5A))),
                    const SizedBox(height: 4),
                    _PillButton(label: tx('ادامه', 'Continue'), icon: Icons.check_rounded, color: _kOrange, onTap: _report, wide: true),
                  ]),
                ),
              ),
            ]),
          ),
        ]));
  }
}

// ==================================================================== widgets
class _Logo extends StatelessWidget {
  const _Logo({required this.text, required this.size});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = TextStyle(fontFamily: 'Lalezar', fontSize: size, height: 1.1);
    return Stack(children: <Widget>[
      // thick dark outline + drop
      Transform.translate(
        offset: const Offset(0, 6),
        child: Text(text,
            style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = size * 0.2
                  ..strokeJoin = StrokeJoin.round
                  ..color = const Color(0xFF3A1200))),
      ),
      Text(text,
          style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = size * 0.2
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF7A2A00))),
      ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (Rect r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFFFF4A0), Color(0xFFFFC21A), Color(0xFFFF6A00)],
          stops: <double>[0, 0.45, 1],
        ).createShader(r),
        child: Text(text, style: base.copyWith(color: Colors.white)),
      ),
    ]);
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, this.size = 44});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0x99000000),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.6),
        ),
      );
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.icon, required this.color, required this.onTap, this.big = false, this.wide = false});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool big;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final double h = big ? 58 : 46;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: h,
          width: wide ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: big ? 30 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color.lerp(color, Colors.white, 0.25)!, color, Color.lerp(color, Colors.black, 0.25)!],
            ),
            borderRadius: BorderRadius.circular(h / 2),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x88000000), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            Icon(icon, color: Colors.white, size: big ? 28 : 22),
            const SizedBox(width: 8),
            Text(label, style: _display(big ? 28 : 21)),
          ]),
        ),
      ),
    );
  }
}

class _CharTile extends StatelessWidget {
  const _CharTile({required this.index, required this.selected, required this.fa, required this.onTap});
  final int index;
  final bool selected;
  final bool fa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final CrCharacter ch = kCrCharacters[index];
    final Color c = Color(ch.color);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.93,
        duration: const Duration(milliseconds: 160),
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 0.9,
              colors: <Color>[Color.lerp(c, Colors.white, 0.35)!, c, Color.lerp(c, Colors.black, 0.55)!],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? _kGold : Colors.white.withValues(alpha: 0.6), width: selected ? 4 : 2),
            boxShadow: selected
                ? const <BoxShadow>[BoxShadow(color: Color(0xAAFFD34E), blurRadius: 14)]
                : const <BoxShadow>[BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 3))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: <Widget>[
            Positioned.fill(
              bottom: 18,
              child: Image.asset('${kCrDir}char_${kCrCharIds[index]}.webp', cacheWidth: 220, fit: BoxFit.contain),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: const Color(0xCC000000),
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(fa ? ch.nameFa : ch.nameEn, textAlign: TextAlign.center, style: _body(12, w: FontWeight.w700), maxLines: 1),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(children: <Widget>[
          SizedBox(width: 44, child: Text(label, style: _body(11.5, color: Colors.white70))),
          for (int i = 0; i < 5; i++)
            Container(
              width: 16,
              height: 9,
              margin: const EdgeInsetsDirectional.only(end: 3),
              decoration: BoxDecoration(
                color: i < value ? _kGold : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ]),
      );
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.info, required this.selected, required this.fa, required this.best, required this.onTap});
  final CrTrackInfo info;
  final bool selected;
  final bool fa;
  final int best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: _kNight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? _kGold : Colors.white.withValues(alpha: 0.5), width: selected ? 4 : 2),
            boxShadow: selected ? const <BoxShadow>[BoxShadow(color: Color(0xAAFFD34E), blurRadius: 16)] : const <BoxShadow>[],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Expanded(
              child: Stack(fit: StackFit.expand, children: <Widget>[
                Image.asset('${kCrDir}bg_${info.theme.name}.webp', cacheWidth: 480, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x00000000), Color(0xCC000000)],
                      stops: <double>[0.45, 1],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 10,
                  end: 10,
                  bottom: 4,
                  child: Text(fa ? info.nameFa : info.nameEn, style: _display(26), maxLines: 1),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(info.descFa, style: _body(11.5, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: <Widget>[
                  const Icon(Icons.timer_rounded, size: 15, color: _kGold),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      best > 0 ? crFormatTime(best / 1000, fa) : (fa ? 'هنوز رکوردی نداری' : 'No record yet'),
                      style: _body(12, color: _kGold, w: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.place,
    required this.name,
    required this.character,
    required this.time,
    required this.lap,
    required this.me,
    required this.fa,
  });
  final int place;
  final String name;
  final int character;
  final String time;
  final String lap;
  final bool me;
  final bool fa;

  @override
  Widget build(BuildContext context) => Container(
        height: 31,
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: me ? _kOrange.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: <Widget>[
          SizedBox(width: 22, child: Text(CrText.digits('$place', fa), style: _display(18, color: place <= 3 ? _kGold : Colors.white))),
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsetsDirectional.only(end: 6),
            decoration: BoxDecoration(color: Color(kCrCharacters[character].color), shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('${kCrDir}char_${kCrCharIds[character]}.webp', cacheWidth: 64, fit: BoxFit.cover),
          ),
          Expanded(child: Text(name, style: _body(12.5, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text(time, style: _body(12.5, w: FontWeight.w700)),
          const SizedBox(width: 10),
          SizedBox(width: 58, child: Text(lap, style: _body(11.5, color: Colors.white70), textAlign: TextAlign.end)),
        ]),
      );
}

/// A press-and-hold control (multi-touch safe: each button tracks its own pointers).
class _HoldButton extends StatefulWidget {
  const _HoldButton({required this.size, required this.onChange, this.icon, this.label, this.color, this.glow = false});
  final double size;
  final ValueChanged<bool> onChange;
  final IconData? icon;
  final String? label;
  final Color? color;
  final bool glow;

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> {
  int _down = 0;

  void _set(int d) {
    final bool was = _down > 0;
    _down = math.max(0, d);
    final bool now = _down > 0;
    if (was != now) {
      widget.onChange(now);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool on = _down > 0;
    final Color c = widget.color ?? const Color(0xFFFFFFFF);
    final bool tinted = widget.color != null;
    return Listener(
      onPointerDown: (_) => _set(_down + 1),
      onPointerUp: (_) => _set(_down - 1),
      onPointerCancel: (_) => _set(_down - 1),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tinted ? c.withValues(alpha: on ? 0.95 : 0.72) : Colors.black.withValues(alpha: on ? 0.55 : 0.32),
          border: Border.all(color: Colors.white.withValues(alpha: on ? 1 : 0.75), width: 3),
          boxShadow: widget.glow ? <BoxShadow>[BoxShadow(color: c, blurRadius: 22, spreadRadius: 3)] : const <BoxShadow>[],
        ),
        alignment: Alignment.center,
        child: widget.icon != null
            ? Icon(widget.icon, color: Colors.white, size: widget.size * 0.7)
            : Text(widget.label ?? '', style: _display(widget.size * 0.27)),
      ),
    );
  }
}

class _TapButton extends StatefulWidget {
  const _TapButton({required this.size, required this.label, required this.color, required this.onTap});
  final double size;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_TapButton> createState() => _TapButtonState();
}

class _TapButtonState extends State<_TapButton> {
  bool _on = false;

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) {
          widget.onTap();
          setState(() => _on = true);
        },
        onPointerUp: (_) => setState(() => _on = false),
        onPointerCancel: (_) => setState(() => _on = false),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _on ? 0.95 : 0.72),
            border: Border.all(color: Colors.white.withValues(alpha: _on ? 1 : 0.75), width: 3),
          ),
          alignment: Alignment.center,
          child: Text(widget.label, style: _display(widget.size * 0.27)),
        ),
      );
}

/// Global per-track leaderboard (games project) with the player's personal best.
class _CrBoardView extends StatefulWidget {
  const _CrBoardView({required this.fa, required this.onBack, required this.initialTrack});
  final bool fa;
  final VoidCallback onBack;
  final String initialTrack;

  @override
  State<_CrBoardView> createState() => _CrBoardViewState();
}

class _CrBoardViewState extends State<_CrBoardView> {
  late String track = widget.initialTrack;
  bool lap = false;
  List<CrBoardRow>? rows;
  bool loading = true;
  int myBest = 0;

  String tx(String f, String e) => widget.fa ? f : e;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => loading = true);
    final String t = track;
    final bool lp = lap;
    unawaited(CrBoard.localBest(t, lap: lp).then((int v) {
      if (mounted) setState(() => myBest = v);
    }));
    unawaited(CrBoard.top(t, lap: lp).then((List<CrBoardRow>? r) {
      if (!mounted || t != track || lp != lap) return;
      setState(() {
        rows = r;
        loading = false;
      });
    }));
  }

  @override
  Widget build(BuildContext context) {
    final bool fa = widget.fa;
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
      const double dw = 800;
      final double dh = math.max(360, dw * c.maxHeight / math.max(1, c.maxWidth));
      return FittedBox(
        child: SizedBox(
          width: dw,
          height: dh,
          child: Stack(children: <Widget>[
            Positioned.fill(
              child: Image.asset('${kCrDir}bg_temple.webp', fit: BoxFit.cover, cacheWidth: 1024, color: const Color(0x99000000), colorBlendMode: BlendMode.darken),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(children: <Widget>[
                Row(children: <Widget>[
                  _RoundIcon(icon: fa ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded, onTap: widget.onBack),
                  const SizedBox(width: 12),
                  Text(tx('رکوردهای جهانی', 'World records'), style: _display(30)),
                  const Spacer(),
                  for (final CrTrackInfo t in kCrTracks)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: ChoiceChip(
                        label: Text(fa ? t.nameFa : t.nameEn, style: _body(12, w: FontWeight.w700, color: t.id == track ? _kInk : Colors.white)),
                        selected: t.id == track,
                        selectedColor: _kGold,
                        backgroundColor: const Color(0x66000000),
                        showCheckmark: false,
                        onSelected: (_) {
                          track = t.id;
                          _load();
                        },
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                Row(children: <Widget>[
                  ChoiceChip(
                    label: Text(tx('کل مسابقه', 'Full race'), style: _body(12, w: FontWeight.w700, color: !lap ? _kInk : Colors.white)),
                    selected: !lap,
                    selectedColor: _kOrange,
                    backgroundColor: const Color(0x66000000),
                    showCheckmark: false,
                    onSelected: (_) {
                      lap = false;
                      _load();
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(tx('بهترین دور', 'Best lap'), style: _body(12, w: FontWeight.w700, color: lap ? _kInk : Colors.white)),
                    selected: lap,
                    selectedColor: _kOrange,
                    backgroundColor: const Color(0x66000000),
                    showCheckmark: false,
                    onSelected: (_) {
                      lap = true;
                      _load();
                    },
                  ),
                  const Spacer(),
                  Text('${tx('رکورد خودت', 'Your best')}: ${myBest > 0 ? crFormatTime(myBest / 1000, fa) : '—'}',
                      style: _body(13, color: _kGold, w: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xCC0E1630), borderRadius: BorderRadius.circular(18)),
                    padding: const EdgeInsets.all(10),
                    child: loading
                        ? const Center(child: CircularProgressIndicator(color: _kGold))
                        : rows == null
                            ? Center(child: Text(tx('برای دیدن جدول جهانی وارد حساب شو.', 'Sign in to see the world board.'), style: _body(14)))
                            : rows!.isEmpty
                                ? Center(child: Text(tx('هنوز کسی رکورد ثبت نکرده. اولین نفر باش!', 'No times yet. Be the first!'), style: _body(14)))
                                : ListView.builder(
                                    itemCount: rows!.length,
                                    itemBuilder: (BuildContext context, int i) {
                                      final CrBoardRow r = rows![i];
                                      final int ci = math.max(0, kCrCharIds.indexOf(r.character));
                                      return _ResultRow(
                                        place: r.rank,
                                        name: r.name,
                                        character: ci,
                                        time: crFormatTime(r.ms / 1000, fa),
                                        lap: '',
                                        me: r.mine,
                                        fa: fa,
                                      );
                                    },
                                  ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}
