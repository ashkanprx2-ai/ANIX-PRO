// Water Sort screenshots: start card, mid-pour, level complete, results.
//   flutter test test_render/water_sort_render_test.dart
// PNGs land in $SHOTS/games/water_sort/ (default /workspace/work/anix_shots).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/storage/local_store.dart';
import 'package:nexora/games/arcade_kit/arcade_skin.dart';
import 'package:nexora/games/core/game_contract.dart';
import 'package:nexora/games/solo/solo_kit.dart';
import 'package:nexora/games/solo/solo_registry.dart';
import 'package:nexora/games/water_sort/water_sort_art.dart';
import 'package:nexora/games/water_sort/water_sort_board.dart';
import 'package:nexora/games/water_sort/water_sort_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_util.dart';

const String dir = 'games/water_sort';

final ThemeData _faTheme = ThemeData.dark(useMaterial3: true)
    .copyWith(textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Estedad'));

GameLaunch _launch({bool fa = true}) => GameLaunch(
    gameId: 'water_sort', mode: GameMode.vsBot, difficulty: BotDifficulty.normal, playerName: 'A',
    isFa: fa, fancyEffects: true, reducedMotion: false, soundOn: false, seed: 3, playerCount: 1, onFinish: (_) {});

SoloRun _run(SoloDef d) => SoloRun(
    launch: _launch(),
    skin: ArcadeSkin(gameId: d.id, bgTop: const Color(0xFF101B32), bgBottom: const Color(0xFF050812),
        accent: d.accent, accent2: d.accent2, glow: d.accent2),
    seed: 3);

Future<void> _frames(WidgetTester tester, int n) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _tapTube(WidgetTester tester, WaterSortBoardState s, int i) async {
  final Offset m = s.homes[i];
  await tester.tapAt(m + Offset(0, s.geom.len * 0.6));
  await _frames(tester, 3);
}

void main() {
  setUp(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStore.init();
    await loadFonts();
    mockAudio();
  });

  final SoloDef def = soloDef('water_sort')!;

  testWidgets('water sort: start card', (WidgetTester tester) async {
    phone(tester);
    await tester.runAsync(WsArt.load);
    await tester.pumpWidget(shotApp(buildSoloGame(def, _launch()), theme: _faTheme));
    await _frames(tester, 40);
    await shoot(tester, '$dir/ws_1_start.png');
  });

  testWidgets('water sort: mid-pour on level 14', (WidgetTester tester) async {
    phone(tester);
    await tester.runAsync(WsArt.load);
    final SoloRun run = _run(def)..playing = true;
    await tester.pumpWidget(shotApp(Builder(builder: (BuildContext c) => WaterSortBoard(run: run, startLevel: 14))));
    await _frames(tester, 40);
    final WaterSortBoardState s = tester.state<WaterSortBoardState>(find.byType(WaterSortBoard));
    // First solver move, poured on screen.
    final List<int> mv = s.board.solve()!.first;
    await _tapTube(tester, s, mv[0]);
    await _frames(tester, 6);
    await shoot(tester, '$dir/ws_2_selected.png');
    await _tapTube(tester, s, mv[1]);
    await _frames(tester, 22); // ~ move + part of the pour
    await shoot(tester, '$dir/ws_3_pouring.png');
    await _frames(tester, 60);
    // A hint arrow for the next move.
    s.showHint();
    await _frames(tester, 10);
    await shoot(tester, '$dir/ws_4_hint.png');
  });

  testWidgets('water sort: mystery level', (WidgetTester tester) async {
    phone(tester);
    await tester.runAsync(WsArt.load);
    final SoloRun run = _run(def)..playing = true;
    expect(WsLevelSpec.of(60).mystery, isTrue);
    await tester.pumpWidget(shotApp(Builder(builder: (BuildContext c) => WaterSortBoard(run: run, startLevel: 60))));
    await _frames(tester, 50);
    await shoot(tester, '$dir/ws_5_level60_mystery.png');
  });

  testWidgets('water sort: level complete + results', (WidgetTester tester) async {
    phone(tester);
    await tester.runAsync(WsArt.load);
    await tester.pumpWidget(shotApp(buildSoloGame(def, _launch()), theme: _faTheme));
    await _frames(tester, 10);
    await tester.tap(find.text('شروع بازی'));
    await _frames(tester, 30);
    final WaterSortBoardState s = tester.state<WaterSortBoardState>(find.byType(WaterSortBoard));
    expect(s.level, 1);
    final List<List<int>> sol = s.board.solve()!;
    for (final List<int> mv in sol) {
      await _tapTube(tester, s, mv[0]);
      await _tapTube(tester, s, mv[1]);
      await _frames(tester, 100);
    }
    expect(s.board.solved, isTrue);
    await _frames(tester, 30);
    await shoot(tester, '$dir/ws_6_celebrate.png');
    await _frames(tester, 80);
    expect(s.complete, isTrue);
    await shoot(tester, '$dir/ws_7_level_complete.png');
    expect(LocalStore.instance.getInt('water_sort.level'), 2);
    await tester.tap(find.text('مرحله بعد'));
    await _frames(tester, 40);
    expect(s.level, 2);
    await shoot(tester, '$dir/ws_8_level2.png');
    await tester.tap(find.text('پایان'));
    await _frames(tester, 40);
    await shoot(tester, '$dir/ws_9_game_over.png');
    await tester.pump(const Duration(seconds: 2));
  });
}
