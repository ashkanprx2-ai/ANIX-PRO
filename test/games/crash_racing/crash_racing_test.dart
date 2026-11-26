import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/games/core/game_contract.dart';
import 'package:nexora/games/crash_racing/core/cr_race.dart';
import 'package:nexora/games/crash_racing/core/cr_track.dart';
import 'package:nexora/games/crash_racing/ui/cr_art.dart';
import 'package:nexora/games/crash_racing/ui/cr_screen.dart';
import 'package:nexora/games/crash_racing/ui/cr_session.dart';
import 'package:nexora/games/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameLaunch _launch(List<GameResult> out) => GameLaunch(
      gameId: 'crash_racing',
      mode: GameMode.vsBot,
      difficulty: BotDifficulty.normal,
      playerName: 'Tester',
      isFa: true,
      fancyEffects: true,
      reducedMotion: true,
      soundOn: false,
      seed: 7,
      onFinish: out.add,
    );

void main() {
  group('crash racing core', () {
    test('every track builds as a closed loop with pickups and ramps', () {
      for (final CrTrackInfo info in kCrTracks) {
        final CrTrack t = CrTrack.build(info.id);
        expect(t.n, greaterThan(400), reason: info.id);
        expect(t.y[t.n], t.y[0]);
        expect(t.pickups.where((CrPickup p) => p.kind == CrPickupKind.box).length, 16);
        expect(t.ramp.where((int r) => r == 1).length, greaterThanOrEqualTo(1));
        for (int i = 0; i < t.n; i++) {
          expect(t.mapX[i], inInclusiveRange(0, 1));
          expect(t.mapY[i], inInclusiveRange(0, 1));
        }
      }
    });

    test('an AI-driven field finishes 3 laps with laps, places and best laps', () {
      final CrRace r = CrRace(track: CrTrack.build('jungle'), playerCharacter: 2, seed: 3, botSkill: 0.92)
        ..autopilotPlayer = true;
      double t = 0;
      while (r.finishOrder.length < 6 && t < 400) {
        r.step(1 / 60);
        t += 1 / 60;
      }
      expect(r.finishOrder.length, 6);
      expect(r.finishOrder.toSet().length, 6);
      for (final CrRacer k in r.racers) {
        expect(k.finished, isTrue);
        expect(k.bestLap, greaterThan(10));
        expect(k.finishTime, greaterThan(k.bestLap * 2.5));
      }
      final List<int> places = <int>[for (final CrRacer k in r.racers) k.place]..sort();
      expect(places, <int>[1, 2, 3, 4, 5, 6]);
    });

    test('power-slide: a timed turbo tap gives a boost, an early one loses the heat', () {
      final CrRace r = CrRace(track: CrTrack.build('temple'), playerCharacter: 0, seed: 1);
      while (!r.started) {
        r.step(1 / 60);
      }
      for (int i = 0; i < 180; i++) {
        r.input(steer: 0, drift: false);
        r.step(1 / 60);
      }
      // hop with steer held → slide on landing
      for (int i = 0; i < 40; i++) {
        r.input(steer: 1, drift: true);
        r.step(1 / 60);
      }
      final CrRacer p = r.player;
      expect(p.drifting, isTrue);
      expect(p.driftDir, 1);
      // early tap: no stage
      p.driftMeter = 0.3;
      r.input(steer: 1, drift: true, turbo: true);
      expect(p.driftStage, 0);
      expect(p.driftMeter, 0);
      // timed tap: stage 1 boost
      p.driftMeter = 0.8;
      r.input(steer: 1, drift: true, turbo: true);
      expect(p.driftStage, 1);
      expect(p.boostTime, greaterThan(0));
      expect(p.boostPower, greaterThan(1));
    });

    test('items: shield absorbs a hit, the mask makes a kart invincible', () {
      final CrRace r = CrRace(track: CrTrack.build('beach'), playerCharacter: 4, seed: 9);
      while (!r.started) {
        r.step(1 / 60);
      }
      final CrRacer p = r.player;
      p.item = CrItem.shield;
      r.fireItem(p);
      expect(p.shield, greaterThan(0));
      r.hit(p);
      expect(p.spin, 0);
      expect(p.shield, 0);
      r.hit(p);
      expect(p.spin, greaterThan(0));
      p.spin = 0;
      p.item = CrItem.mask;
      r.fireItem(p);
      r.hit(p);
      expect(p.spin, 0);
      p.mask = 0;
      p.item = CrItem.rocket;
      r.fireItem(p);
      expect(r.projectiles.where((CrProjectile x) => x.active).length, 1);
    });

    test('catalogue registers کرش ریسینگ', () {
      final GameInfo? g = gameById('crash_racing');
      expect(g, isNotNull);
      expect(g!.nameFa, 'کرش ریسینگ');
    });
  });

  group('crash racing widget', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('race screen runs several seconds of frames without exceptions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(CrArt.load);
      final List<GameResult> results = <GameResult>[];
      CrSession? session;
      final FlutterExceptionHandler? old = FlutterError.onError;
      final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];
      FlutterError.onError = errors.add;
      try {
        await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CrashRacingGame(
                launch: _launch(results),
                debugPhase: CrPhase.race,
                debugAutopilot: true,
                onSession: (CrSession s) => session = s,
              ),
            ),
          ),
        ));
        for (int i = 0; i < 60 * 8; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(session, isNotNull);
        expect(session!.race.started, isTrue);
        expect(session!.race.player.dist, greaterThan(0));
        // close the race and walk through the podium to the host result
        session!.race.simulateToEnd();
        session!.ended = true;
        session!.finished.value = true;
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(find.text('ادامه'), findsOneWidget);
        await tester.tap(find.text('ادامه'));
        await tester.pump(const Duration(milliseconds: 50));
        expect(results.length, 1);
        expect(results.single.scores!.length, 6);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      } finally {
        FlutterError.onError = old;
      }
      for (final FlutterErrorDetails d in errors) {
        // ignore: avoid_print
        print('Error: ${d.exceptionAsString()}\n${d.stack}');
      }
      expect(errors, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('menus build without overflow (title, driver, track)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final List<GameResult> results = <GameResult>[];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: CrashRacingGame(launch: _launch(results)))));
      await tester.pump();
      expect(find.text('شروع مسابقه'), findsOneWidget);
      await tester.tap(find.text('شروع مسابقه'));
      await tester.pump();
      expect(find.text('انتخاب راننده'), findsOneWidget);
      await tester.tap(find.text('بعدی'));
      await tester.pump();
      expect(find.text('انتخاب پیست'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
