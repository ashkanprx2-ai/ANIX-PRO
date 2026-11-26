import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backend/backend_gateway.dart';
import '../../core/backend/supabase_backend.dart';
import '../../core/companion/companion.dart';
import '../../core/profile/achievements.dart';
import '../../core/profile/profile_service.dart';
import '../../core/settings/app_settings.dart';
import '../../core/storage/local_store.dart';
import '../../games/finger_soccer/core/bm_engine.dart';
import '../../games/game_registry.dart';
import '../../worlds/oracle_core/core/oracle_brain.dart';
import '../../worlds/oracle_core/persona/oracle_persona.dart';
import '../kit/station_awards.dart';
import '../kit/station_kit.dart';
import '../widgets/companion_widgets.dart';

// =====================================================================================================================
// AI world: the companion page (ORACLE / LUNA selector + chat that really performs actions), Forecast, Team analysis
// and Smart tips (`AI(x)` of nexora-screens.js) on real data.
// =====================================================================================================================

const int _kMaxMessages = 100;

/// Chat history key per companion (ORACLE keeps the original key, so existing conversations stay).
String _chatKey(CompanionId c) => c == CompanionId.luna ? 'luna.chat.v1' : 'oracle.chat.v1';

CompanionMood moodForPose(String pose) => switch (pose) {
      'confused' || 'alert' => CompanionMood.confused,
      'cheer' || 'power' => CompanionMood.cheer,
      'focus' || 'craft' => CompanionMood.smart,
      'present' => CompanionMood.sign,
      'sleep' => CompanionMood.sleep,
      'spin' => CompanionMood.gamer,
      'calm' => CompanionMood.cool,
      'hero_wave' || 'wave' => CompanionMood.salute,
      _ => CompanionMood.happy,
    };

/// Speaks in LUNA's name when she is the active companion (the offline brain was written for ORACLE).
String companionVoice(String s, CompanionId c) =>
    c == CompanionId.luna ? s.replaceAll('ORACLE', 'LUNA').replaceAll('Oracle', 'Luna').replaceAll('اوراکل', 'لونا') : s;

class _Msg {
  _Msg({required this.fromUser, required this.fa, required this.en, this.actions = const <OracleAction>[], this.pose = 'idle', this.followFa = const <String>[], this.followEn = const <String>[], this.ran = -1, this.error = false, DateTime? at})
      : at = at ?? DateTime.now();
  final bool fromUser;
  final String fa;
  final String en;
  final List<OracleAction> actions;
  final String pose;
  final List<String> followFa;
  final List<String> followEn;
  int ran;
  final bool error;
  final DateTime at;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'u': fromUser,
        'fa': fa,
        'en': en,
        'a': actions.map((OracleAction a) => a.toJson()).toList(),
        'p': pose,
        'ffa': followFa,
        'fen': followEn,
        'ran': ran,
        'err': error,
        'at': at.millisecondsSinceEpoch,
      };

  static _Msg? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Map<String, dynamic> j = Map<String, dynamic>.from(raw);
    List<String> strs(Object? v) => v is List ? v.map((Object? e) => '$e').toList() : const <String>[];
    final Object? a = j['a'];
    return _Msg(
      fromUser: j['u'] == true,
      fa: '${j['fa'] ?? ''}',
      en: '${j['en'] ?? ''}',
      actions: a is List ? <OracleAction>[for (final Object? e in a) if (e is Map) OracleAction.fromJson(Map<String, dynamic>.from(e))] : const <OracleAction>[],
      pose: '${j['p'] ?? 'idle'}',
      followFa: strs(j['ffa']),
      followEn: strs(j['fen']),
      ran: j['ran'] is int ? j['ran'] as int : -1,
      error: j['err'] == true,
      at: j['at'] is int ? DateTime.fromMillisecondsSinceEpoch(j['at'] as int) : null,
    );
  }
}

/// The AI page: pick ORACLE or LUNA (persisted locally and on the profile), then chat with the active one.
class StationAiScreen extends ConsumerStatefulWidget {
  const StationAiScreen({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  ConsumerState<StationAiScreen> createState() => _StationAiScreenState();
}

class _StationAiScreenState extends ConsumerState<StationAiScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _msgs = <_Msg>[];
  late final OfflineOracleEngine _engine;
  RemoteOracleEngine? _remote;
  bool _thinking = false;
  late CompanionId _loadedFor;

  @override
  void initState() {
    super.initState();
    _engine = OfflineOracleEngine(games: <String, OracleGameInfo>{
      for (final GameInfo g in kGames) g.id: OracleGameInfo(id: g.id, nameFa: g.nameFa, nameEn: g.nameEn, rulesFa: g.rulesFa, rulesEn: g.rulesEn),
    });
    final BackendGateway be = ref.read(backendProvider);
    if (be is SupabaseBackend) _remote = RemoteOracleEngine(invoke: be.oracleInvoke, offline: _engine);
    _loadedFor = ref.read(companionProvider).active;
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _end(jump: true);
      final String q = (widget.initialQuery ?? '').trim();
      if (q.isNotEmpty) _ask(q);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _load() {
    _msgs.clear();
    final List<dynamic>? raw = LocalStore.instance.getJsonList(_chatKey(_loadedFor));
    if (raw != null) {
      for (final Object? e in raw) {
        final _Msg? m = _Msg.fromJson(e);
        if (m != null) _msgs.add(m);
      }
    }
    if (_msgs.length > _kMaxMessages) _msgs.removeRange(0, _msgs.length - _kMaxMessages);
  }

  void _save() {
    if (_msgs.length > _kMaxMessages) _msgs.removeRange(0, _msgs.length - _kMaxMessages);
    LocalStore.instance.setJson(_chatKey(_loadedFor), _msgs.map((_Msg m) => m.toJson()).toList());
  }

  void _end({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (jump || ref.read(settingsProvider).reducedMotion) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } else {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: kStationEase);
      }
    });
  }

  OracleContext _context() {
    final ProfileService p = ref.read(profileProvider);
    final AppSettings s = ref.read(settingsProvider);
    return OracleContext(
      username: p.username,
      explorerId: p.explorerId,
      level: p.level,
      xp: p.xp,
      xpIntoLevel: p.xpIntoLevel,
      xpForNextLevel: ProfileService.xpForLevel(p.level),
      rankFa: p.rankTitleFa,
      rankEn: p.rankTitleEn,
      coins: p.coins,
      achievementsUnlocked: p.achievements.length,
      achievementsTotal: kAchievements.length,
      lockedAchievements: <OracleAchievementHint>[
        for (final AchievementDef a in kAchievements)
          if (!p.achievements.contains(a.id)) OracleAchievementHint(nameFa: a.nameFa, nameEn: a.nameEn, descFa: a.descFa, descEn: a.descEn),
      ],
      stats: <String, OracleGameStat>{
        for (final MapEntry<String, GameStats> e in p.stats.entries)
          e.key: OracleGameStat(played: e.value.played, won: e.value.won, lost: e.value.lost, draw: e.value.draw, best: e.value.best),
      },
      canClaimDaily: p.canClaimDaily,
      streak: p.streak,
      reducedMotion: s.reducedMotion,
      quality: s.quality.name,
      languageCode: s.languageCode,
      now: DateTime.now(),
    );
  }

  Future<void> _ask(String text) async {
    final String q = text.trim();
    if (q.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg(fromUser: true, fa: q, en: q));
      _thinking = true;
    });
    _save();
    _end();
    final ProfileService p = ref.read(profileProvider);
    p.bump('oracle.asked');
    final AwardOutcome outcome = p.award('oracle.ask', xp: 3);
    // A persona reply first (name lookups, the companion's signature replies), then the brain / online AI.
    OracleReply reply;
    final String? persona =
        OraclePersona.instance.wakeReply(q) ?? OraclePersona.instance.playerReply(q) ?? OraclePersona.instance.janReply(q);
    try {
      if (persona != null) {
        reply = OracleReply(textFa: persona, textEn: persona, pose: 'cheer', intent: 'persona');
      } else {
        final RemoteOracleEngine? remote = _remote;
        reply = remote != null && ref.read(backendProvider).isOnline ? await remote.ask(q, _context()) : await _engine.ask(q, _context());
      }
    } catch (_) {
      reply = const OracleReply(
        textFa: 'متأسفم، در پردازش این پیام خطایی رخ داد. لطفاً دوباره بپرس.',
        textEn: 'Sorry, something went wrong while processing that. Please ask again.',
        pose: 'confused',
        intent: 'fallback',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    final CompanionId c = ref.read(companionProvider).active;
    final _Msg msg = _Msg(
      fromUser: false,
      fa: companionVoice(reply.textFa, c),
      en: companionVoice(reply.textEn, c),
      actions: reply.actions,
      pose: reply.pose,
      followFa: reply.followUpsFa,
      followEn: reply.followUpsEn,
    );
    setState(() {
      _msgs.add(msg);
      _thinking = false;
    });
    _save();
    _end();
    if (outcome.levelUp || outcome.unlocked.isNotEmpty) await showAwardOutcome(context, outcome);
    if (reply.autoRun && reply.actions.isNotEmpty && mounted) await _run(msg, 0);
  }

  Future<void> _run(_Msg msg, int index) async {
    if (index < 0 || index >= msg.actions.length) return;
    final OracleAction a = msg.actions[index];
    bool ok = false;
    try {
      ok = switch (a.type) {
        OracleActionType.navigate => _navigate(a.route),
        OracleActionType.setting => _setting(a.settingKey, a.settingValue),
        OracleActionType.none => false,
      };
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      setState(() => msg.ran = index);
      _save();
      if (a.type == OracleActionType.setting) stationToast(context, stx(context, 'انجام شد: ${a.labelFa}', 'Done: ${a.labelEn}'));
    } else {
      setState(() => _msgs.add(_Msg(
            fromUser: false,
            fa: 'نتوانستم «${a.labelFa.isEmpty ? 'این کار' : a.labelFa}» را انجام دهم. چیزی تغییر نکرد.',
            en: 'I couldn\'t do "${a.labelEn.isEmpty ? 'that' : a.labelEn}". Nothing was changed.',
            pose: 'confused',
            error: true,
          )));
      _save();
      _end();
    }
  }

  bool _navigate(String? route) {
    if (route == null || route.isEmpty || !route.startsWith('/')) return false;
    if (route == '/hub') {
      context.go('/hub');
    } else {
      context.push(route);
    }
    return true;
  }

  bool _setting(String? key, String? value) {
    if (key == null || value == null) return false;
    final AppSettings s = ref.read(settingsProvider);
    switch (key) {
      case OracleSettingKeys.reducedMotion:
        if (value != 'true' && value != 'false') return false;
        s.reducedMotion = value == 'true';
        return true;
      case OracleSettingKeys.quality:
        for (final GraphicsQuality q in GraphicsQuality.values) {
          if (q.name == value) {
            s.quality = q;
            return true;
          }
        }
        return false;
      case OracleSettingKeys.language:
        if (value != 'fa' && value != 'en') return false;
        s.languageCode = value;
        return true;
      default:
        return false;
    }
  }

  Future<void> _clear() async {
    final bool ok = await showStationConfirm(context,
        title: stx(context, 'پاک کردن گفتگو', 'Clear conversation'),
        message: stx(context, 'همه‌ی پیام‌های این گفتگو از این دستگاه پاک شود؟', 'Delete all messages of this conversation from this device?'),
        confirm: stx(context, 'پاک کن', 'Delete'),
        danger: true);
    if (!ok || !mounted) return;
    setState(_msgs.clear);
    LocalStore.instance.remove(_chatKey(_loadedFor));
  }

  @override
  Widget build(BuildContext context) {
    final CompanionController ctl = ref.watch(companionProvider);
    if (ctl.active != _loadedFor) {
      _loadedFor = ctl.active;
      _load();
      _end(jump: true);
    }
    final CompanionInfo info = ctl.info;
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    String pose = 'idle';
    for (int i = _msgs.length - 1; i >= 0; i--) {
      if (!_msgs[i].fromUser) {
        pose = _msgs[i].pose;
        break;
      }
    }
    final List<String> suggestions = fa
        ? <String>['امروز چی بازی کنم؟', 'قوانین فوتبال انگشتی', 'آمار من چطوره؟', 'جایزه‌ی روزانه', info.id == CompanionId.luna ? 'لونا!' : 'اوراکل!']
        : <String>['What should I play?', 'Finger soccer rules', 'How are my stats?', 'Daily reward', info.id == CompanionId.luna ? 'Luna!' : 'Oracle!'];
    return StationScreen(
      title: stx(context, 'هوش مصنوعی', 'AI'),
      latin: 'AI',
      tint: info.color,
      balance: false,
      actions: <Widget>[
        StationRoundButton(icon: Icons.delete_sweep_rounded, onTap: _msgs.isEmpty ? null : _clear, tooltip: stx(context, 'پاک کردن گفتگو', 'Clear chat')),
      ],
      bottom: Container(
        padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.paddingOf(context).bottom + 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: <Widget>[
              for (final String s in suggestions)
                Padding(padding: const EdgeInsetsDirectional.only(end: 6, bottom: 6), child: StationPill(label: s, on: false, onTap: () => _ask(s))),
            ]),
          ),
          Row(children: <Widget>[
            Expanded(
              child: StationInput(
                controller: _input,
                hint: fa ? 'از ${info.nameFa} بپرس…' : 'Ask ${info.nameEn}…',
                onSubmitted: _ask,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            StationRoundButton(icon: Icons.send_rounded, size: 46, active: true, onTap: () => _ask(_input.text)),
          ]),
        ]),
      ),
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
        children: <Widget>[
          StationTitle(stx(context, 'همراه فعال را انتخاب کن', 'Choose your active companion')),
          const CompanionSelector(compact: true),
          StationCard(
            child: Row(children: <Widget>[
              CompanionMascot(mood: _thinking ? CompanionMood.smart : moodForPose(pose), size: 74),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text(info.name(fa), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: p.ink)),
                  Text(info.role(fa), style: StationText.lat(context, size: 10, color: info.color)),
                  const SizedBox(height: 4),
                  Text(
                    _thinking ? stx(context, 'در حال فکر کردن…', 'Thinking…') : info.bio(fa),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: p.mute, height: 1.6),
                  ),
                ]),
              ),
            ]),
          ),
          if (_msgs.isEmpty)
            StationEmpty(
              text: fa
                  ? 'سلام! من ${info.nameFa}م. هرچی دلت خواست بپرس: قوانین، آمار، پیشنهاد بازی… حتی می‌تونم برات صفحه‌ها رو باز کنم.'
                  : "Hi! I'm ${info.nameEn}. Ask anything: rules, stats, what to play… I can even open screens for you.",
              icon: 'r5c2',
            ),
          for (final _Msg m in _msgs) _bubble(context, m, info),
          if (_thinking)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(padding: const EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2, color: p.gold)),
            ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, _Msg m, CompanionInfo info) {
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    final bool mine = m.fromUser;
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
        if (!mine) ...<Widget>[CompanionAvatar(id: info.id, size: 28), const SizedBox(width: 6)],
        Flexible(
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .74),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: mine ? p.primary : (p.isLight ? null : p.glass),
              color: mine ? null : (p.isLight ? Colors.white : null),
              border: mine ? null : Border.all(color: m.error ? const Color(0xFFFF5A6E) : (p.isLight ? const Color(0xFFD19A22) : p.line), width: p.isLight ? 2 : 1),
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(18),
                topEnd: const Radius.circular(18),
                bottomStart: Radius.circular(mine ? 4 : 18),
                bottomEnd: Radius.circular(mine ? 18 : 4),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
              Text(fa ? m.fa : m.en, style: TextStyle(fontSize: 13.5, height: 1.7, color: mine ? p.primaryInk : p.ink)),
              if (m.actions.isNotEmpty)
                Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
                  for (int i = 0; i < m.actions.length; i++)
                    if (m.actions[i].type != OracleActionType.none)
                      StationButton(
                        label: '${m.ran == i ? '✓ ' : ''}${fa ? m.actions[i].labelFa : m.actions[i].labelEn}',
                        small: true,
                        expand: false,
                        ghost: m.ran == i,
                        margin: const EdgeInsets.only(top: 8),
                        onTap: () => _run(m, i),
                      ),
                ]),
              if ((fa ? m.followFa : m.followEn).isNotEmpty)
                Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
                  for (final String f in (fa ? m.followFa : m.followEn).take(3))
                    Padding(padding: const EdgeInsets.only(top: 8), child: StationPill(label: f, on: false, onTap: () => _ask(f))),
                ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

// --------------------------------------------------------------------------------------------------- forecast

/// `AI(Forecast)` / `AI(Team analysis)` — finger-soccer match forecast from the real team stats (power / accuracy):
/// pick two teams, see the win chance and the deciding factors.
class StationForecastScreen extends ConsumerStatefulWidget {
  const StationForecastScreen({super.key, this.analysis = false});
  final bool analysis;

  @override
  ConsumerState<StationForecastScreen> createState() => _StationForecastScreenState();
}

class _StationForecastScreenState extends ConsumerState<StationForecastScreen> {
  int _g = 0;
  late final List<List<BmTeam>> _pairs = _makePairs();

  List<List<BmTeam>> _makePairs() {
    final List<BmTeam> t = kBmTeams.where((BmTeam x) => x.cat != 'custom').toList();
    if (t.length < 2) return <List<BmTeam>>[];
    final math.Random r = math.Random(DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000);
    return List<List<BmTeam>>.generate(3, (_) {
      final BmTeam a = t[r.nextInt(t.length)];
      BmTeam b = t[r.nextInt(t.length)];
      while (b.id == a.id) {
        b = t[r.nextInt(t.length)];
      }
      return <BmTeam>[a, b];
    });
  }

  double _rating(BmTeam t) => t.power * .55 + t.accuracy * .45;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    if (_pairs.isEmpty) {
      return StationScreen(title: stx(context, 'پیش‌بینی بازی', 'Forecast'), children: <Widget>[StationEmpty(text: stx(context, 'تیمی پیدا نشد', 'No teams'))]);
    }
    final List<BmTeam> m = _pairs[_g];
    final double ra = _rating(m[0]), rb = _rating(m[1]);
    final int pa = (100 / (1 + math.pow(10, (rb - ra) / 4))).round().clamp(5, 95);
    final List<(String, double, double)> factors = <(String, double, double)>[
      (stx(context, 'قدرت شوت', 'Shot power'), m[0].power / 10, m[1].power / 10),
      (stx(context, 'دقت نشانه‌گیری', 'Aim accuracy'), m[0].accuracy / 10, m[1].accuracy / 10),
      (stx(context, 'قدرت کلی', 'Overall'), ra / 10, rb / 10),
    ];
    return StationScreen(
      title: widget.analysis ? stx(context, 'تحلیل تیم', 'Team analysis') : stx(context, 'پیش‌بینی بازی', 'Forecast'),
      children: <Widget>[
        StationSeg(
          labels: <String>[for (int i = 0; i < _pairs.length; i++) fa ? 'بازی ${nxNum(context, i + 1)}' : 'Match ${i + 1}'],
          index: _g,
          onChanged: (int i) => setState(() => _g = i),
        ),
        StationCard(
          child: Column(children: <Widget>[
            Row(children: <Widget>[
              Image.asset(m[0].asset, width: 46, height: 46, cacheWidth: 138),
              const SizedBox(width: 8),
              Expanded(child: Text(fa ? m[0].faName : m[0].name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
              Expanded(child: Text(fa ? m[1].faName : m[1].name, textAlign: TextAlign.end, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
              const SizedBox(width: 8),
              Image.asset(m[1].asset, width: 46, height: 46, cacheWidth: 138),
            ]),
            StationBar(pa / 100, height: 14),
            const SizedBox(height: 8),
            Row(children: <Widget>[
              Text('٪${nxNum(context, pa)}', style: TextStyle(fontSize: 20, color: p.gold2)),
              const Spacer(),
              Text('٪${nxNum(context, 100 - pa)}', style: TextStyle(fontSize: 20, color: p.gold2)),
            ]),
          ]),
        ),
        StationCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Text(stx(context, 'عوامل مؤثر', 'Key factors'), style: TextStyle(color: p.gold, fontSize: 12.5)),
            for (final (String name, double a, double b) in factors)
              StationRow(
                title: name,
                subtitle: '${nxNum(context, (a * 10).round())} — ${nxNum(context, (b * 10).round())}',
                child: Row(children: <Widget>[Expanded(child: StationBar(a)), const SizedBox(width: 8), Expanded(child: StationBar(b))]),
              ),
          ]),
        ),
        if (widget.analysis)
          StationCard(
            child: Text(
              fa
                  ? '${m[0].faName}: قدرت ${nxNum(context, m[0].power)} و دقت ${nxNum(context, m[0].accuracy)} — ${m[0].power >= m[0].accuracy ? 'با شوت‌های محکم بازی کن.' : 'روی ضربه‌های دقیق و آرام تمرکز کن.'}'
                  : '${m[0].name}: power ${m[0].power}, accuracy ${m[0].accuracy} — ${m[0].power >= m[0].accuracy ? 'play strong shots.' : 'focus on precise soft shots.'}',
              style: TextStyle(fontSize: 13, height: 1.8, color: p.ink),
            ),
          ),
        StationButton(label: stx(context, 'بازی فوتبال انگشتی', 'Play finger soccer'), onTap: () => context.push('/arcade/finger_soccer')),
      ],
    );
  }
}

/// `AI(Smart tips)` — the active companion's real tips: every game mechanic from its tutorials, plus personal hints
/// from the profile (daily reward, streak, locked achievements).
class StationTipsScreen extends ConsumerWidget {
  const StationTipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(companionProvider);
    final ProfileService prof = ref.watch(profileProvider);
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    final List<(String, String?)> tips = <(String, String?)>[];
    if (prof.canClaimDaily) tips.add((stx(context, 'جایزه‌ی روزانه‌ات منتظرته! 🎁', 'Your daily reward is waiting! 🎁'), '/s/gift'));
    final List<AchievementDef> locked = kAchievements.where((AchievementDef a) => !prof.achievements.contains(a.id)).take(2).toList();
    for (final AchievementDef a in locked) {
      tips.add((fa ? 'دستاورد «${a.nameFa}»: ${a.descFa}' : 'Achievement "${a.nameEn}": ${a.descEn}', '/s/medals'));
    }
    for (final GameInfo g in kGames) {
      for (final OracleTutorial t in OraclePersona.instance.tutorials(g.id).take(2)) {
        tips.add(('${fa ? g.nameFa : g.nameEn} · ${t.title}: ${t.line}\n${t.how}', '/arcade/${g.id}'));
      }
    }
    return StationScreen(
      title: stx(context, 'پیشنهاد هوشمند', 'Smart tips'),
      children: <Widget>[
        for (final (String text, String? route) in tips)
          StationCard(
            onTap: route == null ? null : () => context.push(route),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const CompanionAvatar(size: 40),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, height: 1.9, color: p.ink))),
            ]),
          ),
      ],
    );
  }
}
