// Gate Shooter (دونده‌ی تیرانداز) screenshots: start line, mid-run, gates, boss and game over.
//   flutter test test_render/gate_shooter_render_test.dart --dart-define=SHOTS=/workspace/work/anix_shots
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/storage/local_store.dart';
import 'package:nexora/games/arcade_kit/arcade_skin.dart';
import 'package:nexora/games/core/game_contract.dart';
import 'package:nexora/games/gate_shooter/gate_shooter.dart';
import 'package:nexora/games/gate_shooter/gs_art.dart';
import 'package:nexora/games/gate_shooter/gs_engine.dart';
import 'package:nexora/games/solo/solo_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_util.dart';

const String dir = 'games/gate_shooter';

Future<void> frames(WidgetTester t, int n) async {
  for (int i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  setUp(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{
      'gate_shooter.meta.v1': jsonEncode(<String, int>{'coins': 1240, 'power': 3, 'soldiers': 4, 'bullets': 1, 'rate': 2}),
    });
    await LocalStore.init();
    await loadFonts();
  });

  testWidgets('gate shooter scenes', (WidgetTester tester) async {
    phone(tester);
    final GameLaunch l = GameLaunch(
        gameId: 'gate_shooter', mode: GameMode.vsBot, difficulty: BotDifficulty.normal, playerName: 'A',
        isFa: true, fancyEffects: true, reducedMotion: false, soundOn: false, seed: 7, playerCount: 1, onFinish: (_) {});
    final SoloRun run = SoloRun(
        launch: l,
        skin: ArcadeSkin(gameId: 'gate_shooter', bgTop: const Color(0xFF101B32), bgBottom: const Color(0xFF050812),
            accent: kGateShooterDef.accent, accent2: kGateShooterDef.accent2, glow: kGateShooterDef.accent2),
        seed: 7)
      ..playing = true;
    await tester.runAsync(GsArt.load);
    await tester.pumpWidget(shotApp(Directionality(
        textDirection: TextDirection.rtl, child: Builder(builder: (BuildContext c) => kGateShooterDef.board(c, run)))));
    await frames(tester, 30);
    await shoot(tester, '$dir/gs_1_start.png');

    // start the run and steer a little
    await tester.tapAt(const Offset(180, 420));
    // ignore: invalid_use_of_visible_for_testing_member
    final GsEngine e = GateShooterBoard.debugEngine!;
    for (int k = 0; k < 9; k++) {
      await tester.dragFrom(Offset(180, 460), Offset(k.isEven ? 40 : -55, 0));
      await frames(tester, 25);
    }
    await shoot(tester, '$dir/gs_2_run.png');
    // keep running until a gate is close
    for (int i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (e.gates.any((GsGate g) => !g.passed && g.z < 14 && g.z > 8)) break;
    }
    await shoot(tester, '$dir/gs_3_gate.png');
    for (int i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (e.targets.any((GsTarget t) => t.kind != GsKind.enemy && t.z < 22 && t.z > 12)) break;
    }
    await frames(tester, 12);
    await shoot(tester, '$dir/gs_4_blocks.png');

    // fast-forward into a boss wave
    e.health = 100;
    e.wave = 3;
    e.waveStart = e.distance - e.waveLen + 2;
    e.targets.clear();
    e.gates.clear();
    await frames(tester, 220);
    await shoot(tester, '$dir/gs_5_boss.png');
    e.boss?.z = 14;
    await frames(tester, 60);
    await shoot(tester, '$dir/gs_6_boss_fight.png');

    // game over
    e.health = 0.5;
    e.boss?.z = 6.5;
    await frames(tester, 140);
    e.health = 0;
    await frames(tester, 160);
    await shoot(tester, '$dir/gs_7_over.png');
    expect(run.over, isTrue);
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 80);
  });
}
