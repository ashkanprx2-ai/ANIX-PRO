// Renders Piano Tiles inside the real solo shell on a 360x800 phone and saves PNGs:
//   flutter test test_render/piano_tiles_render_test.dart
// -> $SHOTS/games/piano_tiles/{0_ready,1_picker,2_start,3_play,4_hold,7_song_complete,6_pause,5_gameover}.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/storage/local_store.dart';
import 'package:nexora/games/core/game_contract.dart';
import 'package:nexora/games/piano_tiles/core/pt_engine.dart';
import 'package:nexora/games/piano_tiles/piano_tiles.dart';
import 'package:nexora/games/piano_tiles/ui/pt_board.dart';
import 'package:nexora/games/solo/solo_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_util.dart';

const String dir = 'games/piano_tiles';

Future<void> frames(WidgetTester tester, int n) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

PianoTilesBoardState board(WidgetTester tester) => tester.state<PianoTilesBoardState>(find.byType(PianoTilesBoard));

/// Taps the due tile; holds long tiles for [holdFrames] frames.
Future<void> playOne(WidgetTester tester, {int gap = 10, int holdFrames = 0, double lowY = 430}) async {
  final PianoTilesBoardState s = board(tester);
  // tap like a player: when the due tile has come down into the lower half
  for (int i = 0; i < 90 && s.engine.started && (s.debugNextTap()?.dy ?? 999) < lowY; i++) {
    await frames(tester, 1);
  }
  final Offset? at = s.debugNextTap();
  if (at == null) return;
  final bool hold = s.engine.next.first.isHold;
  final TestGesture g = await tester.startGesture(at);
  if (hold && holdFrames > 0) {
    await frames(tester, holdFrames);
  } else {
    await frames(tester, 1);
  }
  await g.up();
  await frames(tester, gap);
}

void main() {
  setUp(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{'pt_stars_twinkle': 3, 'pt_stars_ode_to_joy': 2, 'pt_stars_atal_matal': 1});
    await LocalStore.init();
    await loadFonts();
  });

  for (final bool fa in <bool>[true, false]) {
    testWidgets('piano tiles ${fa ? 'fa' : 'en'}', (WidgetTester tester) async {
      phone(tester);
      final String sfx = fa ? '' : '_en';
      final GameLaunch l = GameLaunch(
        gameId: 'piano_tiles',
        mode: GameMode.vsBot,
        difficulty: BotDifficulty.normal,
        playerName: 'A',
        isFa: fa,
        fancyEffects: true,
        reducedMotion: false,
        soundOn: false,
        seed: 3,
        playerCount: 1,
        onFinish: (_) {},
      );
      await tester.pumpWidget(shotApp(
          theme: ThemeData.dark(useMaterial3: true).copyWith(textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Estedad')),
          Directionality(
        textDirection: fa ? TextDirection.rtl : TextDirection.ltr,
        child: Builder(builder: (BuildContext c) => buildSoloGame(kPianoTilesDef, l)),
      )));
      await frames(tester, 20);
      if (fa) await shoot(tester, '$dir/0_ready.png');
      // shell start card -> song picker
      await tester.tapAt(const Offset(180, 400));
      await frames(tester, 20);
      await shoot(tester, '$dir/1_picker$sfx.png');
      await tester.tap(find.byKey(const ValueKey<String>('pt_song_twinkle')));
      await frames(tester, 50);
      await shoot(tester, '$dir/2_start$sfx.png');
      // play the opening of the song
      for (int i = 0; i < 9; i++) {
        await playOne(tester, gap: 9, holdFrames: 30);
      }
      await playOne(tester, gap: 2);
      await shoot(tester, '$dir/3_play$sfx.png');
      if (!fa) return;
      // find a hold and catch it mid-fill
      for (int i = 0; i < 30 && !board(tester).engine.next.first.isHold; i++) {
        await playOne(tester, gap: 8, holdFrames: 30);
      }
      final PianoTilesBoardState s = board(tester);
      for (int i = 0; i < 90 && s.debugNextTap()!.dy < 560; i++) {
        await frames(tester, 1);
      }
      final TestGesture g = await tester.startGesture(s.debugNextTap()!);
      await frames(tester, 14);
      await shoot(tester, '$dir/4_hold.png');
      await g.up();
      await frames(tester, 6);
      // finish the song: 3 stars, «song complete» and endless mode
      for (int i = 0; i < 80 && board(tester).engine.loops == 0; i++) {
        await playOne(tester, gap: 2, holdFrames: 40);
      }
      await frames(tester, 24);
      await shoot(tester, '$dir/7_song_complete.png');
      // pause card
      await tester.tap(find.byKey(const ValueKey<String>('pt_pause')));
      await frames(tester, 10);
      await shoot(tester, '$dir/6_pause.png');
      await tester.tap(find.byKey(const ValueKey<String>('pt_resume')));
      await frames(tester, 200);
      await playOne(tester, gap: 4, holdFrames: 30);
      // miss: tap an empty cell next to the due tile
      final PianoTilesBoardState s2 = board(tester);
      final PtTile due = s2.engine.next.first;
      final Offset at = s2.debugNextTap()!;
      final double laneW = 360 / 4;
      final int lane = <int>[0, 1, 2, 3].firstWhere((int k) =>
          k != due.lane && !s2.engine.tiles.any((PtTile t) => t.lane == k && !t.hit && (t.row - due.row).abs() < 1.2));
      await tester.tapAt(Offset((lane + 0.5) * laneW, at.dy));
      await frames(tester, 70);
      await shoot(tester, '$dir/5_gameover.png');
      await frames(tester, 120);
    });
  }
}
