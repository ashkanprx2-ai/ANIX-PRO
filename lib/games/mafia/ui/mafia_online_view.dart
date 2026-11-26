import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/ui/kit/station_compat.dart';

import 'package:nexora/games/core/game_contract.dart';
import 'package:nexora/games/core/server_game.dart';

import '../core/mafia_models.dart';

enum _Stage { intro, night, nominate, finalVote, over }

/// Online Mafia, server-authoritative: the server deals the roles, keeps every secret (roles, night actions, the
/// Detective's results, the Mafia-only chat), validates each input and resolves nights, votes and the winner.
/// This phone only renders its own player's view (nx_match_secrets 'view') and sends inputs through nx_hg_act;
/// it never learns a role it may not know, so a modified client has nothing to read.
class MafiaOnlineView extends StatefulWidget {
  const MafiaOnlineView({super.key, required this.launch});
  final GameLaunch launch;

  @override
  State<MafiaOnlineView> createState() => _MafiaOnlineViewState();
}

class _MafiaOnlineViewState extends State<MafiaOnlineView> {
  late final NetLink _net;
  late final ServerGameSync _sync;
  Map<String, dynamic>? _v;
  final TextEditingController _msg = TextEditingController();
  bool _finished = false;
  bool _sending = false;
  int? _pick;
  _Stage? _lastStage;
  int _lastDay = 0;
  Timer? _clock;

  GameLaunch get _l => widget.launch;
  int get _me => _net.mySeat;

  @override
  void initState() {
    super.initState();
    _net = _l.net!;
    _sync = ServerGameSync(_net, onView: _onView)..start();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _v != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _sync.dispose();
    _msg.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ view
  _Stage get _stage => switch ('${_v?['stage']}') {
        'night' => _Stage.night,
        'nominate' => _Stage.nominate,
        'final' => _Stage.finalVote,
        'over' => _Stage.over,
        _ => _Stage.intro,
      };
  int get _day => vInt(_v?['day']) ?? 1;
  MafiaRole? _role(dynamic r) => r is String && MafiaRole.values.any((MafiaRole x) => x.name == r) ? MafiaRole.values.byName(r) : null;
  MafiaRole get _myRole => _role(_v?['role']) ?? MafiaRole.citizen;
  bool get _alive => _v?['alive'] == true;
  List<Map<String, dynamic>> get _players => vMaps(_v?['players']);
  List<int>? get _legal => _v?['legal'] is List ? vInts(_v?['legal']) : null;
  bool get _acted => _v?['acted'] == true;
  List<int> get _waiting => vInts(_v?['waiting']);
  List<int> get _defs => vInts(_v?['defs']);
  MafiaTeam? get _winner => switch ('${_v?['winner']}') { 'town' => MafiaTeam.town, 'mafia' => MafiaTeam.mafia, _ => null };

  String _name(int s) {
    for (final Map<String, dynamic> p in _players) {
      if (vInt(p['s']) == s) return '${p['name'] ?? _l.netName(s) ?? 'Pilot ${s + 1}'}';
    }
    return _l.netName(s) ?? 'Pilot ${s + 1}';
  }

  MafiaRole? _roleOf(int s) {
    for (final Map<String, dynamic> p in _players) {
      if (vInt(p['s']) == s) return _role(p['role']);
    }
    return null;
  }

  void _onView(Map<String, dynamic> v) {
    if (!mounted) return;
    setState(() => _v = v);
    if (_lastStage != null && (_stage != _lastStage || _day != _lastDay)) {
      _pick = null;
      if (_l.soundOn) HapticFeedback.mediumImpact();
    }
    _lastStage = _stage;
    _lastDay = _day;
    _net.turnSeat = null;
    _checkOver();
  }

  Future<void> _send(String a, {int? t}) async {
    if (_sending) return;
    setState(() => _sending = true);
    final Map<String, dynamic> r = await _sync.act(<String, dynamic>{'a': a, 'd': _day, 't': t});
    if (!mounted) return;
    setState(() => _sending = false);
    if (r['ok'] != true && r['reason'] != 'rate') {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(_t('ثبت نشد، دوباره تلاش کن.', 'Not accepted, try again.'))));
    }
  }

  void _checkOver() {
    final MafiaTeam? w = _winner;
    if (w == null || _finished) return;
    _finished = true;
    final List<int> winners = <int>[
      for (final Map<String, dynamic> p in _players)
        if (_role(p['role'])?.team == w && p['out'] != true) vInt(p['s'])!,
    ];
    final bool won = _myRole.team == w && winners.contains(_me);
    Future<void>.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      _l.onFinish(GameResult(
        outcome: won ? GameOutcome.win : GameOutcome.loss,
        winnerSeats: winners,
        summaryFa: '${teamLabel(w, true)} پیروز شد. نقش تو: ${_myRole.labelFa}.',
        summaryEn: '${teamLabel(w, false)} won. Your role: ${_myRole.labelEn}.',
      ));
    });
  }

  Future<void> _sendChat() async {
    final String t = _msg.text.trim();
    if (t.isEmpty || !_alive) return;
    if (_stage == _Stage.night && !_myRole.isMafia) return;
    _msg.clear();
    final Map<String, dynamic> r = await _sync.act(<String, dynamic>{'a': 'chat', 't': t});
    if (!mounted) return;
    if (r['ok'] != true && r['reason'] == 'rate') {
      _msg.text = t;
    }
  }

  // ------------------------------------------------------------------ UI
  String _t(String fa, String en) => _l.tx(fa, en);

  @override
  Widget build(BuildContext context) {
    final bool night = _stage == _Stage.night || _stage == _Stage.intro;
    return NxBackground(
      palette: night ? WorldPalette.oracle : WorldPalette.social,
      stars: _l.fancyEffects,
      child: SafeArea(
        child: _v == null
            ? const Center(child: CircularProgressIndicator())
            : Column(children: <Widget>[
                const SizedBox(height: 8),
                Padding(padding: const EdgeInsets.fromLTRB(64, 0, 40, 6), child: _header()),
                Expanded(
                  child: ListView(padding: const EdgeInsets.symmetric(horizontal: NxSpace.md), children: <Widget>[
                    _roleCard(),
                    const SizedBox(height: 10),
                    _actionPanel(),
                    const SizedBox(height: 10),
                    _playersGrid(),
                    const SizedBox(height: 10),
                    _logPanel(),
                    const SizedBox(height: 10),
                    _chatPanel(),
                    const SizedBox(height: 16),
                  ]),
                ),
                if (_alive && _stage != _Stage.over && (_stage != _Stage.night || _myRole.isMafia)) _chatInput(),
              ]),
      ),
    );
  }

  Widget _header() {
    final String phase = switch (_stage) {
      _Stage.intro => _t('آشنایی با نقش‌ها', 'Meet your role'),
      _Stage.night => _t('شب $_day', 'Night $_day'),
      _Stage.nominate => _t('روز $_day · رأی‌گیری اول', 'Day $_day · nomination'),
      _Stage.finalVote => _t('روز $_day · رأی نهایی', 'Day $_day · final vote'),
      _Stage.over => _t('پایان بازی', 'Game over'),
    };
    final int alive = _players.where((Map<String, dynamic> p) => p['alive'] == true).length;
    final Duration? left = _stage == _Stage.over ? null : _sync.remaining;
    return Row(children: <Widget>[
      Icon(_stage == _Stage.night ? Icons.nightlight_round : Icons.wb_sunny_rounded,
          color: _stage == _Stage.night ? NxColors.goldDeep : NxColors.gold),
      const SizedBox(width: 8),
      Expanded(child: Text(phase, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
      if (left != null) ...<Widget>[
        NxPill(label: '${left.inSeconds}s', icon: Icons.timer_outlined, color: NxColors.gold),
        const SizedBox(width: 6),
      ],
      NxPill(label: '$alive/${_players.length}', icon: Icons.people_alt_rounded, color: NxColors.turquoise),
    ]);
  }

  Widget _roleCard() {
    final MafiaRole r = _myRole;
    final List<String> partners = <String>[
      for (final int s in vInts(_v?['partners']))
        '${_name(s)} (${_t(_roleOf(s)?.labelFa ?? '', _roleOf(s)?.labelEn ?? '')})',
    ];
    final Map<String, dynamic> det = _v?['det'] is Map ? Map<String, dynamic>.from(_v!['det'] as Map) : <String, dynamic>{};
    return GlassPanel(
      borderColor: (r.isMafia ? NxColors.danger : NxColors.turquoise).withValues(alpha: 0.6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Icon(r.isMafia ? Icons.masks_rounded : Icons.shield_rounded, color: r.isMafia ? NxColors.danger : NxColors.turquoise),
          const SizedBox(width: 8),
          Text(_t('نقش تو: ${r.labelFa}', 'Your role: ${r.labelEn}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const Spacer(),
          if (!_alive) NxPill(label: _t('حذف شده', 'Out'), icon: Icons.close_rounded, color: NxColors.danger),
        ]),
        const SizedBox(height: 6),
        Text(_t(r.descFa, r.descEn), style: const TextStyle(color: NxColors.textDim, fontSize: 12, height: 1.5)),
        if (partners.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(_t('هم‌تیمی‌ها: ${partners.join('، ')}', 'Partners: ${partners.join(', ')}'),
              style: const TextStyle(color: NxColors.danger, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
        if (r == MafiaRole.detective && det.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          for (final MapEntry<String, dynamic> en in det.entries)
            Text(
              _t('استعلام ${_name(int.tryParse(en.key) ?? 0)}: ${en.value == true ? 'مافیا' : 'بی‌گناه'}',
                  'Check ${_name(int.tryParse(en.key) ?? 0)}: ${en.value == true ? 'Mafia' : 'innocent'}'),
              style: TextStyle(color: en.value == true ? NxColors.danger : NxColors.success, fontSize: 12),
            ),
        ],
        if (r == MafiaRole.sniper && vInt(_v?['bullets']) != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(_t('گلوله: ${vInt(_v?['bullets'])}', 'Bullets: ${vInt(_v?['bullets'])}'),
              style: const TextStyle(color: NxColors.gold, fontSize: 12)),
        ],
      ]),
    );
  }

  Widget _actionPanel() {
    final List<int> waiting = _waiting;
    final Widget waitLine = Text(
      waiting.isEmpty
          ? ''
          : _t('در انتظار: ${waiting.map(_name).join('، ')}', 'Waiting for: ${waiting.map(_name).join(', ')}'),
      style: const TextStyle(color: NxColors.textDim, fontSize: 12),
    );
    final List<int>? legal = _legal;
    switch (_stage) {
      case _Stage.over:
        final MafiaTeam? w = _winner;
        return GlassPanel(
          child: Text(
            w == null ? '' : _t('${teamLabel(w, true)} پیروز شد!', '${teamLabel(w, false)} wins!'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: NxColors.gold),
          ),
        );
      case _Stage.intro:
        return GlassPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Text(_t('نقشت را به خاطر بسپار و به کسی نشانش نده.', 'Remember your role and keep it secret.')),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _acted || _sending || !_alive ? null : () => _send('ready'),
              icon: const Icon(Icons.check_rounded),
              label: Text(_acted ? _t('آماده‌ای ✓', 'Ready ✓') : _t('آماده‌ام', "I'm ready")),
            ),
            waitLine,
          ]),
        );
      case _Stage.night:
        if (legal == null) {
          final bool lead = vInt(_v?['lead']) == _me;
          return GlassPanel(
            child: Text(
              !_alive
                  ? _t('تو از بازی خارج شده‌ای؛ تماشا کن.', 'You are out — watch the game.')
                  : _acted
                      ? _t('انتخابت ثبت شد. منتظر بقیه…', 'Your choice is locked in. Waiting…')
                      : (_myRole.isMafia && !lead
                          ? _t('رهبر مافیا قربانی را انتخاب می‌کند؛ در چت مافیا پیشنهاد بده.',
                              'Your leader picks the target — suggest one in the Mafia chat.')
                          : _t('شهر خواب است… چشم‌هایت را ببند.', 'The town sleeps… close your eyes.')),
            ),
          );
        }
        final MafiaRole r = _myRole;
        final String prompt = r.isMafia
            ? _t('امشب چه کسی را حذف می‌کنید؟', 'Who do you eliminate tonight?')
            : r == MafiaRole.doctor
                ? _t('چه کسی را نجات می‌دهی؟', 'Who do you save?')
                : r == MafiaRole.detective
                    ? _t('هویت چه کسی را استعلام می‌کنی؟', 'Whom do you investigate?')
                    : _t('شلیک می‌کنی؟ (یک گلوله)', 'Fire your single bullet?');
        return _picker(prompt, legal, (int? t) => _send('night', t: t),
            allowNone: r == MafiaRole.sniper, noneLabel: _t('شلیک نمی‌کنم', 'Hold fire'));
      case _Stage.nominate:
        if (legal == null) {
          return GlassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Text(_alive ? _t('رأیت ثبت شد.', 'Vote recorded.') : _t('تو از بازی خارج شده‌ای.', 'You are out.')),
            waitLine,
          ]));
        }
        return _picker(_t('گفتگو کنید، بعد به کسی که مشکوک است رأی بده.', 'Discuss, then vote for a suspect.'), legal,
            (int? t) => _send('nom', t: t),
            allowNone: true, noneLabel: _t('رأی نمی‌دهم', 'Skip'), extra: <Widget>[waitLine]);
      case _Stage.finalVote:
        if (legal == null) {
          return GlassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Text(_t('به دفاع: ${_defs.map(_name).join('، ')}', 'On trial: ${_defs.map(_name).join(', ')}')),
            waitLine,
          ]));
        }
        return _picker(_t('دفاع شنیده شد. چه کسی حذف شود؟', 'Defences heard. Who should leave?'), legal,
            (int? t) => _send('final', t: t),
            allowNone: true, noneLabel: _t('هیچ‌کس (بخشش)', 'Nobody (spare)'), extra: <Widget>[waitLine]);
    }
  }

  Widget _picker(String prompt, List<int> legal, void Function(int?) onConfirm,
      {bool allowNone = false, String noneLabel = '', List<Widget> extra = const <Widget>[]}) {
    return GlassPanel(
      borderColor: NxColors.gold.withValues(alpha: 0.6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Text(prompt, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          for (final int id in legal)
            ChoiceChip(
              label: Text(_name(id)),
              selected: _pick == id,
              onSelected: (_) => setState(() => _pick = id),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: <Widget>[
          if (allowNone)
            Expanded(child: OutlinedButton(onPressed: _sending ? null : () => onConfirm(null), child: Text(noneLabel))),
          if (allowNone) const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: _sending || _pick == null || !legal.contains(_pick) ? null : () => onConfirm(_pick),
              child: Text(_t('تأیید', 'Confirm')),
            ),
          ),
        ]),
        ...extra,
      ]),
    );
  }

  Widget _playersGrid() {
    return GlassPanel(
      child: Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
        for (final Map<String, dynamic> p in _players)
          Builder(builder: (BuildContext context) {
            final int s = vInt(p['s']) ?? 0;
            final bool alive = p['alive'] == true;
            final MafiaRole? role = _role(p['role']);
            final bool online = _net.connectedSeats.contains(s);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: alive ? NxColors.glass : Colors.black26,
                border: Border.all(color: s == _me ? NxColors.gold : NxColors.goldLine),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: online ? NxColors.success : NxColors.textDim),
                ),
                const SizedBox(width: 6),
                Text('${p['name'] ?? _name(s)}',
                    style: TextStyle(
                        decoration: alive ? null : TextDecoration.lineThrough,
                        color: alive ? NxColors.ink : NxColors.textDim,
                        fontWeight: FontWeight.w700)),
                if (role != null && s != _me) ...<Widget>[
                  const SizedBox(width: 4),
                  Text('· ${_t(role.labelFa, role.labelEn)}',
                      style: TextStyle(color: role.isMafia ? NxColors.danger : NxColors.turquoise, fontSize: 11)),
                ],
              ]),
            );
          }),
      ]),
    );
  }

  Widget _logPanel() {
    final List<Map<String, dynamic>> log = vMaps(_v?['log']);
    final List<Map<String, dynamic>> last = log.length > 12 ? log.sublist(log.length - 12) : log;
    return GlassPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(_t('رویدادها', 'Events'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final Map<String, dynamic> e in last.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(_t('${e['fa'] ?? ''}', '${e['en'] ?? ''}'),
                style: TextStyle(
                    fontSize: 12,
                    color: e['k'] == 'death' ? NxColors.danger : (e['to'] is List ? NxColors.gold : NxColors.ink))),
          ),
      ]),
    );
  }

  Widget _chatPanel() {
    final List<Map<String, dynamic>> chat = vMaps(_v?['chat']);
    if (chat.isEmpty) return const SizedBox.shrink();
    return GlassPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(_t('گفتگو', 'Discussion'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final Map<String, dynamic> c in chat.length > 30 ? chat.sublist(chat.length - 30) : chat)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(TextSpan(children: <InlineSpan>[
              TextSpan(
                text: '${_name(vInt(c['s']) ?? 0)}${c['m'] == true ? ' 🔒' : ''}: ',
                style: TextStyle(fontWeight: FontWeight.w800, color: c['m'] == true ? NxColors.danger : NxColors.turquoise),
              ),
              TextSpan(text: '${c['t'] ?? ''}'),
            ]), style: const TextStyle(fontSize: 13)),
          ),
      ]),
    );
  }

  Widget _chatInput() {
    final bool mafiaOnly = _stage == _Stage.night && _myRole.isMafia;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(children: <Widget>[
        Expanded(
          child: TextField(
            controller: _msg,
            maxLength: 240,
            decoration: InputDecoration(
              counterText: '',
              hintText: mafiaOnly ? _t('چت مخفی مافیا…', 'Secret Mafia chat…') : _t('حرفت را بزن…', 'Say something…'),
            ),
            onSubmitted: (_) => _sendChat(),
          ),
        ),
        IconButton(onPressed: _sendChat, icon: const Icon(Icons.send_rounded, color: NxColors.turquoise)),
      ]),
    );
  }
}
