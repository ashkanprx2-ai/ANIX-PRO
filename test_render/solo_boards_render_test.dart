// Renders every solo board straight into a phone-sized frame (no ready card) and saves PNGs.
//   flutter test test_render/solo_boards_render_test.dart --dart-define=TAG=after
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/storage/local_store.dart';
import 'package:nexora/games/arcade_kit/arcade_skin.dart';
import 'package:nexora/games/core/game_contract.dart';
import 'package:nexora/games/solo/solo_kit.dart';
import 'package:nexora/games/solo/solo_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arcade_util.dart';

const String tag = String.fromEnvironment('TAG', defaultValue: 'after');
const String only = String.fromEnvironment('ONLY');

void main() {
  setUp(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStore.init();
    await loadFonts();
  });
  for (final SoloDef d in kSoloDefs) {
    if (only.isNotEmpty && !only.split(',').contains(d.id)) continue;
    testWidgets('solo ${d.id}', (WidgetTester tester) async {
      phone(tester);
      final GameLaunch l = GameLaunch(
          gameId: d.id, mode: GameMode.vsBot, difficulty: BotDifficulty.normal, playerName: 'A',
          isFa: false, fancyEffects: true, reducedMotion: false, soundOn: false, seed: 3, playerCount: 1, onFinish: (_) {});
      final SoloRun run = SoloRun(
          launch: l,
          skin: ArcadeSkin(gameId: d.id, bgTop: const Color(0xFF101B32), bgBottom: const Color(0xFF050812),
              accent: d.accent, accent2: d.accent2, glow: d.accent2),
          seed: 3)
        ..playing = true;
      await tester.pumpWidget(shotApp(Builder(builder: (BuildContext c) => d.board(c, run))));
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      await shoot(tester, '$tag/${d.id}_a.png');
      // poke the board: taps across the play area, then a drag
      for (int k = 0; k < 6; k++) {
        await tester.tapAt(Offset(80.0 + k * 45, 420));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 33));
        }
      }
      await tester.dragFrom(const Offset(80, 500), const Offset(240, -120));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      await shoot(tester, '$tag/${d.id}_b.png');
    });
  }
}
