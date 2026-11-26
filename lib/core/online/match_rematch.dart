// Online rematch for every game (generalised 2026-11-26 from finger soccer v13, bm_rematch.dart, owner request
// "بازی مجدد برای همه بازی‌های آنلاین").
//
// Flow (every message rides the match's existing Realtime channel as an ephemeral live message, so nothing is written
// to the finished match's move log):
//   1. A player taps "بازی مجدد" on the end screen -> {op: req}. The others see "حریف درخواست بازی مجدد داد" with
//      Accept / Decline ({op: acc} / {op: dec}).
//   2. No answer within [kRematchTimeoutMs] -> "حریف پاسخ نداد" ({op: cancel} clears the prompt on the other side).
//      Two players asking at the same time count as both accepting.
//   3. Everyone accepted -> a new match for the same room and players is created through the normal server path
//      (nx_start_match for lobby / quick rooms, nx_start_room_match for talk rooms; both return the room's running
//      match when it already exists, so several phones calling is harmless). Seat 0 calls at once, the others poll
//      the room row and take the 'go' message, and try the call themselves after a few seconds. Each phone then leaves
//      the finished match page; the room page opens the new match as it does for every match.
//   4. A player who left (presence gone / forfeited) -> "حریف از بازی خارج شد" and the button is disabled.
// Tournament games never offer a rematch (the bracket decides the next game); spectators never see it.
// Finger soccer runs the same controller on its own score table with event 'fs_rm' (bm_rematch.dart) and carries its
// team picks; every other game gets it on the host's online result screen (online_match_page.dart, event 'nx_rm').
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../games/core/net_link.dart';
import '../../ui/kit/station_compat.dart';
import 'match_link.dart';
import 'online_service.dart';

/// Live event name of every rematch message.
const String kMatchRematchEvent = 'nx_rm';

/// How long a request waits for an answer (ms).
const int kRematchTimeoutMs = 20000;

/// How long the new match may take to appear once everyone accepted (ms).
const int kRematchStartMs = 15000;

enum RematchPhase {
  /// Nothing asked yet (or a request lapsed / was declined by this phone).
  idle,

  /// This phone asked (or accepted) and waits for the others.
  waiting,

  /// Another player asked: Accept / Decline.
  incoming,

  /// Everyone accepted: the new match is being created / opened.
  starting,

  /// Our request ran out ("حریف پاسخ نداد").
  noAnswer,

  /// The other player declined.
  declined,

  /// A player left: the button is disabled.
  opponentLeft,

  /// The new match could not be created.
  failed,
}

/// Pure rematch state machine (no I/O; tests drive it directly). Times are ms on any monotonic clock.
class RematchMachine {
  RematchMachine({required this.mySeat, required this.seatCount, this.timeoutMs = kRematchTimeoutMs});

  final int mySeat, seatCount, timeoutMs;
  RematchPhase phase = RematchPhase.idle;

  /// Seats that want the rematch in the current round.
  final Set<int> accepted = <int>{};

  /// Round id (the requester's random number), echoed by answers.
  int? nonce;
  double deadline = 0;

  /// Seat whose request is shown ([RematchPhase.incoming]).
  int? fromSeat;

  /// Id of the new match once known.
  String? matchId;

  bool get allAccepted => accepted.length >= seatCount;
  bool get canRequest => const <RematchPhase>{
        RematchPhase.idle,
        RematchPhase.noAnswer,
        RematchPhase.declined,
        RematchPhase.failed,
      }.contains(phase);

  /// A request / answer / start is in progress (the end screen stays up).
  bool get busy =>
      phase == RematchPhase.waiting || phase == RematchPhase.incoming || phase == RematchPhase.starting;

  void _toStarting(double now) {
    phase = RematchPhase.starting;
    deadline = now + kRematchStartMs;
  }

  /// This phone asks. Returns the message to send (null when it cannot ask now).
  Map<String, dynamic>? request(double now, int n) {
    if (!canRequest) return null;
    phase = RematchPhase.waiting;
    accepted
      ..clear()
      ..add(mySeat);
    nonce = n;
    fromSeat = mySeat;
    deadline = now + timeoutMs;
    return <String, dynamic>{'op': 'req', 'n': n};
  }

  /// This phone accepts the shown request.
  Map<String, dynamic>? accept(double now) {
    if (phase != RematchPhase.incoming) return null;
    accepted.add(mySeat);
    if (allAccepted) {
      _toStarting(now);
    } else {
      phase = RematchPhase.waiting;
      deadline = now + timeoutMs;
    }
    return <String, dynamic>{'op': 'acc', 'n': nonce};
  }

  /// This phone declines the shown request.
  Map<String, dynamic>? decline() {
    if (phase != RematchPhase.incoming) return null;
    final int? n = nonce;
    phase = RematchPhase.idle;
    accepted.clear();
    nonce = null;
    return <String, dynamic>{'op': 'dec', 'n': n};
  }

  /// A message from [seat]. Never answers by itself (the user does), so it returns nothing.
  void receive(int seat, Map<String, dynamic> d, double now) {
    if (seat == mySeat || seat < 0 || seat >= seatCount) return;
    final String op = '${d['op']}';
    final int? n = (d['n'] as num?)?.toInt();
    switch (op) {
      case 'req':
        if (phase == RematchPhase.starting || phase == RematchPhase.opponentLeft) return;
        if (phase == RematchPhase.waiting) {
          // both asked (crossing requests) or another seat of a team game joined in: that player accepts too
          accepted.add(seat);
          if (allAccepted) _toStarting(now);
          return;
        }
        phase = RematchPhase.incoming;
        nonce = n;
        fromSeat = seat;
        accepted
          ..clear()
          ..add(seat);
        deadline = now + timeoutMs;
        return;
      case 'acc':
        if (phase != RematchPhase.waiting && phase != RematchPhase.incoming) return;
        accepted.add(seat);
        if (phase == RematchPhase.waiting && allAccepted) _toStarting(now);
        return;
      case 'dec':
        if ((phase == RematchPhase.waiting || phase == RematchPhase.incoming) && (n == null || n == nonce)) {
          phase = phase == RematchPhase.waiting ? RematchPhase.declined : RematchPhase.idle;
          accepted.clear();
        }
        return;
      case 'cancel':
        if (phase == RematchPhase.incoming && (n == null || n == nonce)) {
          phase = RematchPhase.idle;
          accepted.clear();
        }
        return;
      case 'go':
        final dynamic m = d['m'];
        if (m is String && m.isNotEmpty && phase != RematchPhase.opponentLeft) {
          matchId = m;
          if (phase != RematchPhase.starting) _toStarting(now);
        }
        return;
    }
  }

  /// Timeouts. Returns a message to send (the requester's 'cancel'), or null.
  Map<String, dynamic>? tick(double now) {
    if (now <= deadline) return null;
    switch (phase) {
      case RematchPhase.waiting:
        phase = RematchPhase.noAnswer;
        accepted.clear();
        return <String, dynamic>{'op': 'cancel', 'n': nonce};
      case RematchPhase.incoming:
        phase = RematchPhase.idle;
        accepted.clear();
        return null;
      case RematchPhase.starting:
        if (matchId == null) phase = RematchPhase.failed;
        return null;
      default:
        return null;
    }
  }

  /// Presence: [present] = seats still in the match (connected and not forfeited). While the new match is starting a
  /// player leaving the old page is expected and ignored.
  void presence(Set<int> present) {
    if (phase == RematchPhase.starting) return;
    bool gone = false;
    for (int s = 0; s < seatCount; s++) {
      if (s != mySeat && !present.contains(s)) gone = true;
    }
    if (gone) {
      phase = RematchPhase.opponentLeft;
      accepted.clear();
    } else if (phase == RematchPhase.opponentLeft) {
      phase = RematchPhase.idle; // back after a brief disconnect
    }
  }
}

/// Creates the next match of the room (null when this phone may not / could not).
typedef RematchStarter = Future<String?> Function();

/// Reads the room's running match id when it is a new one (null when not yet).
typedef RematchRoomPoll = Future<String?> Function();

/// Wires [RematchMachine] to the match link (live messages, presence) and the server.
class MatchRematchController extends ChangeNotifier {
  MatchRematchController({
    required this.net,
    required this.starter,
    required this.roomPoll,
    required this.onGo,
    this.event = kMatchRematchEvent,
    double Function()? clock,
    math.Random? rnd,
  })  : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch.toDouble()),
        _rnd = rnd ?? math.Random(),
        m = RematchMachine(mySeat: net.mySeat, seatCount: net.seatCount) {
    _sub = net.live.listen(_onLive, onError: (Object _) {});
    net.changes.addListener(_onPresence);
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    _onPresence();
  }

  /// A controller for a live Supabase match, or null when a rematch is not offered (tournament game, no room).
  static MatchRematchController? forLink(NetLink? net,
      {required String? tournamentMatchId, required void Function(String) onGo, String event = kMatchRematchEvent}) {
    if (net is! SupabaseMatchLink || net.isSpectator || tournamentMatchId != null) return null;
    if (!matchRematchAllowed(net.settings, roomId: net.roomId)) return null;
    final SupabaseClient? c = OnlineService.current?.games;
    if (c == null) return null;
    final String room = net.roomId!;
    final String old = net.matchId;
    final String fn = net.settings.containsKey('room_prefs') ? 'nx_start_room_match' : 'nx_start_match';
    return MatchRematchController(
      net: net,
      starter: () => matchRematchStart(c, fn, room, old),
      roomPoll: () => matchRematchPollRoom(c, room, old),
      onGo: onGo,
      event: event,
    );
  }

  /// Live event name of this controller's messages (finger soccer keeps its own 'fs_rm').
  final String event;
  final NetLink net;
  final RematchStarter starter;
  final RematchRoomPoll roomPoll;
  final void Function(String matchId) onGo;
  final double Function() _clock;
  final math.Random _rnd;
  final RematchMachine m;
  StreamSubscription<NetLiveMessage>? _sub;
  Timer? _timer;
  bool _disposed = false;
  bool _starting = false;
  bool _went = false;
  bool _tableDone = false;
  final Completer<void> _hold = Completer<void>();

  RematchPhase get phase => m.phase;

  /// Completes once the end screen may give way to the host's result overlay (table over and nothing pending).
  Future<void> get released => _hold.future;

  void _send(Map<String, dynamic>? msg) {
    if (msg == null) return;
    try {
      net.sendLive(event, msg);
    } catch (_) {}
  }

  void request() {
    _send(m.request(_clock(), 1 + _rnd.nextInt(1 << 30)));
    _changed();
  }

  void accept() {
    _send(m.accept(_clock()));
    _changed();
  }

  void decline() {
    _send(m.decline());
    _changed();
  }

  /// The score table's countdown is over.
  void tableDone() {
    _tableDone = true;
    _checkHold();
  }

  void _onLive(NetLiveMessage msg) {
    if (_disposed || msg.event != event) return;
    m.receive(msg.seat, msg.data, _clock());
    _changed();
  }

  void _onPresence() {
    if (_disposed) return;
    final Set<int> present = <int>{
      for (final int s in net.connectedSeats)
        if (!net.forfeitedSeats.contains(s)) s
    };
    final RematchPhase was = m.phase;
    m.presence(present);
    if (was != m.phase) _changed();
  }

  void _tick() {
    if (_disposed) return;
    final RematchPhase was = m.phase;
    _send(m.tick(_clock()));
    if (was != m.phase) _changed();
  }

  void _changed() {
    if (_disposed) return;
    if (m.phase == RematchPhase.starting) {
      final String? id = m.matchId;
      if (id != null) {
        _go(id);
      } else if (!_starting) {
        unawaited(_start());
      }
    }
    _checkHold();
    notifyListeners();
  }

  /// Everyone accepted: create (seat 0 at once, the others after a few seconds) or find the new match.
  Future<void> _start() async {
    _starting = true;
    final double t0 = _clock();
    bool tried = false;
    if (net.mySeat == 0) {
      tried = true;
      final String? id = await starter();
      if (id != null) {
        _send(<String, dynamic>{'op': 'go', 'm': id});
        _go(id);
        return;
      }
    }
    while (!_disposed && !_went && m.phase == RematchPhase.starting) {
      final String? id = await roomPoll();
      if (id != null) {
        _go(id);
        return;
      }
      if (!tried && _clock() - t0 > 5000) {
        tried = true;
        final String? s = await starter();
        if (s != null) {
          _send(<String, dynamic>{'op': 'go', 'm': s});
          _go(s);
          return;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
  }

  void _go(String id) {
    if (_went || _disposed) return;
    _went = true;
    m.matchId = id;
    onGo(id);
  }

  void _checkHold() {
    if (_hold.isCompleted) return;
    if (_tableDone && !m.busy) _hold.complete();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_sub?.cancel());
    net.changes.removeListener(_onPresence);
    if (!_hold.isCompleted) _hold.complete();
    super.dispose();
  }
}

/// A rematch is offered for room matches that are not tournament games.
bool matchRematchAllowed(Map<String, dynamic> settings, {required String? roomId}) =>
    roomId != null && !settings.containsKey('tournament') && !settings.containsKey('tmatch');

/// Starts the room's next match ([fn] = nx_start_match / nx_start_room_match). While the server still has the
/// finished match as the room's running one (its result is being booked) it returns that id: retried for a few
/// seconds until a new one comes back. Null when this phone may not start it (not the room's host / manager) or it
/// failed.
Future<String?> matchRematchStart(SupabaseClient c, String fn, String room, String oldMatch) async {
  for (int i = 0; i < 6; i++) {
    try {
      final dynamic r = await c.rpc(fn, params: <String, dynamic>{'p_room': room});
      final String? mid = r is Map ? r['match_id'] as String? : null;
      if (mid != null && mid != oldMatch) return mid;
    } on PostgrestException catch (e) {
      final String msg = e.message.toLowerCase();
      if (msg.contains('host only') || msg.contains('manager only') || msg.contains('need')) return null;
    } catch (_) {}
    await Future<void>.delayed(Duration(milliseconds: 700 * (i + 1)));
  }
  return null;
}

/// The room's running match when it is a new one.
Future<String?> matchRematchPollRoom(SupabaseClient c, String room, String oldMatch) async {
  try {
    final Map<String, dynamic>? r =
        await c.from('nx_rooms').select('status, match_id').eq('id', room).maybeSingle();
    final String? mid = r?['match_id'] as String?;
    if (r != null && r['status'] == 'playing' && mid != null && mid != oldMatch) return mid;
  } catch (_) {}
  return null;
}

/// The rematch strip on the end-of-match score table (black-gold Luxe look like the lobby).
class MatchRematchPanel extends StatelessWidget {
  const MatchRematchPanel({super.key, required this.c, required this.fa});
  final MatchRematchController c;
  final bool fa;

  String _t(String f, String e) => fa ? f : e;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (BuildContext context, _) {
        final RematchPhase p = c.phase;
        final List<Widget> kids = <Widget>[];
        String? note;
        Color noteColor = Luxe.mute;
        switch (p) {
          case RematchPhase.incoming:
            note = _t('حریف درخواست بازی مجدد داد', 'Your opponent wants a rematch');
            noteColor = Luxe.gold2;
            kids.add(Row(children: <Widget>[
              Expanded(
                child: LuxeButton(
                  label: _t('رد', 'Decline'),
                  kind: LuxeButtonKind.ghost,
                  height: 44,
                  uppercase: false,
                  onTap: c.decline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LuxeButton(
                  label: _t('قبول', 'Accept'),
                  icon: Icons.check_rounded,
                  height: 44,
                  uppercase: false,
                  onTap: c.accept,
                ),
              ),
            ]));
            break;
          case RematchPhase.waiting:
            note = _t('در انتظار پاسخ حریف…', 'Waiting for your opponent…');
            kids.add(LuxeButton(label: _t('بازی مجدد', 'Rematch'), height: 44, uppercase: false, loading: true, onTap: () {}));
            break;
          case RematchPhase.starting:
            note = _t('بازی مجدد شروع می‌شود…', 'Starting the rematch…');
            noteColor = Luxe.gold2;
            kids.add(LuxeButton(label: _t('بازی مجدد', 'Rematch'), height: 44, uppercase: false, loading: true, onTap: () {}));
            break;
          case RematchPhase.opponentLeft:
            note = _t('حریف از بازی خارج شد', 'Your opponent left');
            noteColor = const Color(0xFFFF8A9A);
            kids.add(LuxeButton(
                label: _t('بازی مجدد', 'Rematch'), icon: Icons.replay_rounded, height: 44, uppercase: false, onTap: null));
            break;
          case RematchPhase.idle:
          case RematchPhase.noAnswer:
          case RematchPhase.declined:
          case RematchPhase.failed:
            if (p == RematchPhase.noAnswer) note = _t('حریف پاسخ نداد', 'No answer from your opponent');
            if (p == RematchPhase.declined) note = _t('حریف بازی مجدد را رد کرد', 'Your opponent declined');
            if (p == RematchPhase.failed) note = _t('شروع بازی مجدد ممکن نشد', 'Could not start the rematch');
            kids.add(LuxeButton(
                label: _t('بازی مجدد', 'Rematch'),
                icon: Icons.replay_rounded,
                height: 44,
                uppercase: false,
                onTap: c.request));
            break;
        }
        return Directionality(
          textDirection: fa ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: Luxe.panel.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(LuxeRadius.md),
              border: Border.all(color: Luxe.gold3),
              boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x99000000), blurRadius: 14, offset: Offset(0, 4))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(note,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: noteColor, fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ...kids,
            ]),
          ),
        );
      },
    );
  }
}
