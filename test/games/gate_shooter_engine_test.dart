import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/storage/local_store.dart';
import 'package:nexora/games/gate_shooter/gs_engine.dart';
import 'package:nexora/games/gate_shooter/gs_meta.dart';
import 'package:nexora/games/solo/solo_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// دونده‌ی تیرانداز must be a real game: the squad fires, blocks break into coins, gates change the squad,
/// boss waves arrive and the run ends when health runs out.
void main() {
  setUp(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStore.init();
  });

  test('registered as a solo game', () {
    expect(soloDef('gate_shooter'), isNotNull);
  });

  test('lobby waits, start runs, squad shoots and scores', () {
    final GsEngine e = GsEngine(seed: 1, meta: GsMeta());
    e.update(0.02);
    expect(e.phase, GsPhase.lobby);
    expect(e.distance, 0);
    e.start();
    for (int i = 0; i < 50 * 8; i++) {
      e.update(0.02);
      e.events.clear();
    }
    expect(e.distance, greaterThan(40));
    expect(e.score, greaterThan(40));
    expect(e.kills + e.gatesTaken, greaterThan(0));
  });

  test('gates add, multiply and subtract soldiers', () {
    final GsEngine e = GsEngine(seed: 2, meta: GsMeta());
    e.start();
    e.gates.clear();
    e.targets.clear();
    final int n0 = e.soldiers.length;
    e.gates.add(GsGate(0.5, <GsGateSide>[GsGateSide(GateOp.add, 4, -4, 0), GsGateSide(GateOp.sub, 3, 0, 4)]));
    e.px = -1;
    e.steer = -1;
    for (int i = 0; i < 40; i++) {
      e.update(0.02);
    }
    expect(e.soldiers.length, n0 + 4);
    e.gates.add(GsGate(0.5, <GsGateSide>[GsGateSide(GateOp.mul, 2, -4, 0), GsGateSide(GateOp.add, 1, 0, 4)]));
    for (int i = 0; i < 40; i++) {
      e.update(0.02);
    }
    expect(e.soldiers.length, (n0 + 4) * 2);
  });

  test('shooting a red gate raises its value', () {
    final GsGateSide s = GsGateSide(GateOp.sub, 1, 0, 4);
    final GsEngine e = GsEngine(seed: 3, meta: GsMeta());
    e.start();
    e.targets.clear();
    e.gates
      ..clear()
      ..add(GsGate(30, <GsGateSide>[GsGateSide(GateOp.add, 1, -4, 0), s]));
    e.px = 1;
    e.steer = 1;
    for (int i = 0; i < 150; i++) {
      e.update(0.02);
      e.gates.first.z = 30;
    }
    expect(s.op, GateOp.add);
  });

  test('every third wave brings a boss and dying ends the run', () {
    final GsEngine e = GsEngine(seed: 4, meta: GsMeta());
    e.start();
    e.wave = 3;
    e.waveStart = e.distance - e.waveLen;
    e.update(0.02);
    expect(e.phase, GsPhase.boss);
    expect(e.boss, isNotNull);
    e.health = 0;
    for (int i = 0; i < 200; i++) {
      e.update(0.02);
    }
    expect(e.phase, GsPhase.over);
  });

  test('upgrades cost coins and persist', () {
    final GsMeta m = GsMeta(coins: 1000);
    final int c = m.cost(GsStat.power);
    expect(m.buy(GsStat.power), isTrue);
    expect(m.coins, 1000 - c);
    expect(GsMeta.load().level(GsStat.power), 2);
    expect(GsMeta(coins: 0).buy(GsStat.rate), isFalse);
  });
}
