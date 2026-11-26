// RS (work/rematch-spectator): read-only spectator link, generic rematch for every online game.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/online/match_link.dart';
import 'package:nexora/games/core/net_link.dart';
import 'package:nexora/games/finger_soccer/ui/bm_rematch.dart';

import 'fake_match_server.dart';

class _Net extends ChangeNotifier implements NetLink {
  _Net(this.mySeat);
  @override
  final int mySeat;
  @override
  String get matchId => 'm1';
  _Net? peer;
  final StreamController<NetLiveMessage> _live = StreamController<NetLiveMessage>.broadcast(sync: true);
  @override
  int get seatCount => 2;
  @override
  int get seed => 1;
  @override
  Map<String, dynamic> get settings => const <String, dynamic>{};
  @override
  List<String> get names => const <String>['A', 'B'];
  @override
  Set<int> get connectedSeats => const <int>{0, 1};
  @override
  Set<int> get forfeitedSeats => const <int>{};
  @override
  bool get isAuthority => mySeat == 0;
  @override
  Listenable get changes => this;
  @override
  bool get replaying => false;
  @override
  void listen(void Function(NetMove move) onMove, {VoidCallback? onReplayDone}) {}
  @override
  Future<bool> send(Map<String, dynamic> data, {String kind = 'move', String? hash, int? asSeat}) async => false;
  @override
  void sendLive(String event, Map<String, dynamic> data) => peer?._live.add(NetLiveMessage(mySeat, event, data));
  @override
  Stream<NetLiveMessage> get live => _live.stream;
  @override
  set turnSeat(int? seat) {}
  @override
  Future<void> putSecret(int seat, String slot, Map<String, dynamic> data) async {}
  @override
  Future<Map<String, dynamic>?> readSecret(String slot) async => null;
  @override
  void verify(int seq, String? expected, String actual) {}
  @override
  int get desyncs => 0;
}

void main() {
  group('generic rematch', () {
    test('two phones on the generic event: both accept -> both go to the new match', () async {
      final _Net n0 = _Net(0), n1 = _Net(1);
      n0.peer = n1;
      n1.peer = n0;
      final List<String> went = <String>[];
      final MatchRematchController c0 = MatchRematchController(
          net: n0, starter: () async => 'm2', roomPoll: () async => null, onGo: went.add);
      final MatchRematchController c1 = MatchRematchController(
          net: n1, starter: () async => null, roomPoll: () async => null, onGo: went.add);
      expect(c0.event, kMatchRematchEvent);
      c0.request();
      expect(c1.phase, RematchPhase.incoming);
      c1.accept();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(went, <String>['m2', 'm2']);
      c0.dispose();
      c1.dispose();
    });

    test('finger soccer keeps its own event and does not hear the generic one', () {
      final _Net n0 = _Net(0), n1 = _Net(1);
      n0.peer = n1;
      n1.peer = n0;
      final MatchRematchController g =
          MatchRematchController(net: n0, starter: () async => null, roomPoll: () async => null, onGo: (_) {});
      final FsRematchController fs =
          FsRematchController(net: n1, starter: () async => null, roomPoll: () async => null, onGo: (_) {});
      expect(fs.event, kFsRematchEvent);
      g.request();
      expect(fs.phase, RematchPhase.idle);
      g.dispose();
      fs.dispose();
    });

    test('tournament games and room-less matches never offer it', () {
      expect(matchRematchAllowed(const <String, dynamic>{'tmatch': 'x'}, roomId: 'r'), isFalse);
      expect(matchRematchAllowed(const <String, dynamic>{}, roomId: null), isFalse);
      expect(matchRematchAllowed(const <String, dynamic>{}, roomId: 'r'), isTrue);
    });
  });

  group('spectator link', () {
    test('reads the log, never writes, never acts as authority', () async {
      final FakeMatchServer s = FakeMatchServer(players: <String>['u0', 'u1']);
      final SupabaseMatchLink p0 = fakeLink(s, 0);
      final SupabaseMatchLink w = SupabaseMatchLink.test(s.backendFor('u0'), 'm1', 'watcher', s.matchRow, spectate: true);
      expect(w.isSpectator, isTrue);
      expect(w.mySeat, 0);
      expect(w.isAuthority, isFalse);
      final List<NetMove> seen = <NetMove>[];
      w.listen(seen.add);
      p0.listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(await p0.send(<String, dynamic>{'x': 1}), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(seen.map((NetMove m) => m.seq), contains(1));
      final int before = s.rows.length;
      expect(await w.send(<String, dynamic>{'x': 2}), isFalse);
      expect(s.rows.length, before);
      expect((await w.act(<String, dynamic>{'a': 'x'}))['reason'], 'spectator');
      p0.dispose();
      w.dispose();
    });

    test('a player opening with spectate=true is still a player', () {
      final FakeMatchServer s = FakeMatchServer(players: <String>['u0', 'u1']);
      final SupabaseMatchLink l = SupabaseMatchLink.test(s.backendFor('u1'), 'm1', 'u1', s.matchRow, spectate: true);
      expect(l.isSpectator, isFalse);
      expect(l.mySeat, 1);
      l.dispose();
    });
  });
}
