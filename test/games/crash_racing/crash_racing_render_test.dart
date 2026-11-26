import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/games/core/game_contract.dart';
import 'package:nexora/games/crash_racing/core/cr_race.dart';
import 'package:nexora/games/crash_racing/core/cr_track.dart';
import 'package:nexora/games/crash_racing/ui/cr_art.dart';
import 'package:nexora/games/crash_racing/ui/cr_screen.dart';
import 'package:nexora/games/crash_racing/ui/cr_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the menu, a race mid-drift with the HUD and the podium to PNGs (for visual review).
/// Output: $CRASH_SHOTS_DIR (default /workspace/work/shots/out/crash when it exists; otherwise nothing is written).
String? _outDir() {
  final String? env = Platform.environment['CRASH_SHOTS_DIR'];
  if (env != null && env.isNotEmpty) return env;
  const String def = '/workspace/work/shots/out/crash';
  return Directory(def).existsSync() ? def : null;
}

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final FontLoader l = FontLoader(name);
    for (final String f in files) {
      l.addFont(rootBundle.load(f));
    }
    await l.load();
  }

  await family('Lalezar', <String>['assets/fonts/Lalezar-Regular.ttf']);
  await family('Vazirmatn', <String>['assets/fonts/Vazirmatn-Regular.ttf', 'assets/fonts/Vazirmatn-Bold.ttf']);
  final String root = Platform.environment['FLUTTER_ROOT'] ?? '/workspace/work/flutter_sdk';
  final File icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final FontLoader l = FontLoader('MaterialIcons')..addFont(Future<ByteData>.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
}

GameLaunch _launch() => GameLaunch(
      gameId: 'crash_racing',
      mode: GameMode.vsBot,
      difficulty: BotDifficulty.normal,
      playerName: 'آرش',
      isFa: true,
      fancyEffects: true,
      reducedMotion: true,
      soundOn: false,
      seed: 11,
      onFinish: (_) {},
    );

void main() {
  final String? out = _outDir();
  final GlobalKey shot = GlobalKey();

  Future<void> snap(WidgetTester tester, String name) async {
    if (out == null) return;
    await tester.runAsync(() async {
      final RenderRepaintBoundary b = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image img = await b.toImage(pixelRatio: 2);
      final ByteData? png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Future<void> settleImages(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Widget host(Widget child) => RepaintBoundary(
        key: shot,
        child: MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(body: child)),
      );

  void landscape(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('menus render', (WidgetTester tester) async {
    landscape(tester);
    await tester.runAsync(_loadFonts);
    await tester.runAsync(CrArt.load);
    await tester.pumpWidget(host(CrashRacingGame(launch: _launch())));
    await settleImages(tester);
    await snap(tester, '1_title');
    await tester.tap(find.text('شروع مسابقه'));
    await tester.pump();
    await settleImages(tester);
    await snap(tester, '2_driver');
    await tester.tap(find.text('بعدی'));
    await tester.pump();
    await settleImages(tester);
    await snap(tester, '3_track');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final String track in <String>['jungle', 'temple']) {
    testWidgets('race mid-drift + results render ($track)', (WidgetTester tester) async {
      landscape(tester);
      await tester.runAsync(_loadFonts);
      await tester.runAsync(CrArt.load);
      CrSession? s;
      await tester.pumpWidget(host(CrashRacingGame(
        launch: _launch(),
        debugPhase: CrPhase.race,
        debugTrack: track,
        debugCharacter: track == 'jungle' ? 0 : 1,
        debugAutopilot: true,
        onSession: (CrSession x) => s = x,
      )));
      // drive until the player is sliding through a curve with a few fruit and an item
      int frames = 0;
      while (frames < 60 * 40) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
        final CrRacer p = s!.race.player;
        if (frames > 60 * 9 && p.drifting && p.driftMeter > 0.55 && s!.race.track.curveAt(p.z).abs() > 2.5) break;
      }
      final CrRacer p = s!.race.player;
      p.item = CrItem.rocket;
      p.fruit = p.fruit < 4 ? 7 : p.fruit;
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await snap(tester, '4_race_${track}_drift');
      // results
      s!.race.simulateToEnd();
      s!.ended = true;
      s!.finished.value = true;
      await tester.pump();
      await settleImages(tester);
      await snap(tester, '5_results_$track');
      expect(CrTrack.laps, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
