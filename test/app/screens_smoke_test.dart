// Smoke tests: the Station home, every Station screen, every registered game (detail page + a vs-bot match), the
// chat screens and the sign-in screens build and run a few seconds of frames without exceptions, in English and
// Persian (RTL). Also drives the real app router as a guest: menu destinations open a page (or the explicit sign-in
// screen), never bounce to /hub.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nexora/app/app.dart';
import 'package:nexora/core/profile/profile_service.dart';
import 'package:nexora/core/settings/app_settings.dart';
import 'package:nexora/core/storage/local_store.dart';
import 'package:nexora/games/game_registry.dart';
import 'package:nexora/ui/screens/ai_screens.dart';
import 'package:nexora/ui/screens/auth_screens.dart';
import 'package:nexora/ui/screens/event_screens.dart';
import 'package:nexora/ui/screens/game_screens.dart';
import 'package:nexora/ui/screens/profile_screens.dart';
import 'package:nexora/ui/screens/rooms_screens.dart';
import 'package:nexora/ui/screens/shop_screens.dart';
import 'package:nexora/ui/shell/station_page.dart';
import 'package:nexora/ui/theme/station_theme.dart';
import 'package:nexora/worlds/arcade/game_host_page.dart';
import 'package:nexora/worlds/arcade/online/online_lobby_page.dart';
import 'package:nexora/worlds/orbit_network/orbit_network_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Collects framework errors. Text overflow is ignored: the test font (Ahem) is much wider than the app fonts.
final List<void Function()> _restore = <void Function()>[];

/// Puts the test framework's error handler back (must happen before any expect, or a failure is masked).
void _release() {
  for (final void Function() f in _restore) {
    f();
  }
  _restore.clear();
}

List<String> _captureErrors() {
  final List<String> errs = <String>[];
  final void Function(FlutterErrorDetails)? old = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails d) {
    final String s = d.exceptionAsString();
    if (s.contains('overflowed by')) return;
    errs.add(s.split('\n').take(3).join(' / '));
  };
  _restore.add(() => FlutterError.onError = old);
  addTearDown(_release);
  return errs;
}

Future<void> _frames(WidgetTester tester, int n, {int ms = 100}) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 30));
}

Widget _host(GameInfo g) =>
    GameHostPage(game: g, mode: GameMode.vsBot, difficulty: BotDifficulty.normal, players: g.defaultPlayers);

void main() {
  // Every registered game is launched here: a game that cannot build its first frames is a
  // broken game, and this test is the only automated gate that proves each one runs.
  final List<String> reportedGames = kGames.map((GameInfo g) => g.id).toList();

  final Map<String, (Widget Function(), Type)> screens = <String, (Widget Function(), Type)>{
    'station home': (() => const StationPage(), StationPage),
    'all games': (() => const StationGamesScreen(), StationGamesScreen),
    'rooms': (() => const StationRoomsScreen(), StationRoomsScreen),
    'chat (orbit network)': (() => const OrbitNetworkPage(), OrbitNetworkPage),
    'sign-in': (() => const StationAuthPage(), StationAuthPage),
    'sign-in required': (() => const StationSignInRequired(from: '/social'), StationSignInRequired),
    'onboarding': (() => const StationOnboarding(), StationOnboarding),
    'AI (ORACLE / LUNA)': (() => const StationAiScreen(), StationAiScreen),
    'profile': (() => const StationProfileScreen(), StationProfileScreen),
    'account': (() => const StationAccountScreen(), StationAccountScreen),
    'settings': (() => const StationSettingsScreen(), StationSettingsScreen),
    'controller': (() => const StationControllerScreen(), StationControllerScreen),
    'shop': (() => const StationShopScreen(), StationShopScreen),
    'lucky wheel': (() => const StationWheelScreen(), StationWheelScreen),
    'missions': (() => const StationMissionsScreen(weekly: false), StationMissionsScreen),
    for (final String id in reportedGames) ...<String, (Widget Function(), Type)>{
      'game page $id': (() => StationGameScreen(gameId: id), StationGameScreen),
      'game $id vs bot': (() => _host(gameById(id)!), GameHostPage),
    },
  };

  for (final String lang in <String>['en', 'fa']) {
    for (final MapEntry<String, (Widget Function(), Type)> e in screens.entries) {
      testWidgets('${e.key} builds without exceptions ($lang)', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{'settings.lang': lang});
        await LocalStore.init();
        _phone(tester);
        final List<String> errs = _captureErrors();
        final ProviderContainer c = ProviderContainer();
        addTearDown(c.dispose);
        c.read(profileProvider).updateProfile(name: 'Ashkan');
        c.read(settingsProvider).languageCode = lang;
        final GoRouter router =
            GoRouter(routes: <RouteBase>[GoRoute(path: '/', builder: (_, __) => e.value.$1())]);
        await tester.pumpWidget(UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(
            theme: buildStationTheme(StationSkin.neon),
            routerConfig: router,
            locale: Locale(lang),
            supportedLocales: const <Locale>[Locale('fa'), Locale('en')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        ));
        await _frames(tester, 30);
        _release();
        expect(find.byType(e.value.$2), findsWidgets);
        expect(Directionality.of(tester.element(find.byType(e.value.$2).first)),
            lang == 'fa' ? TextDirection.rtl : TextDirection.ltr);
        expect(tester.takeException(), isNull);
        expect(errs, isEmpty);
        await _teardown(tester);
      });
    }
  }

  testWidgets('online lobby can be left (no ref use in dispose)', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'settings.lang': 'en'});
    await LocalStore.init();
    _phone(tester);
    final List<String> errs = _captureErrors();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(theme: buildStationTheme(StationSkin.neon), home: const OnlineLobbyPage(gameId: 'pool8')),
    ));
    await _frames(tester, 10);
    final bool shown = find.byType(OnlineLobbyPage).evaluate().length == 1;
    await _teardown(tester);
    _release();
    expect(shown, isTrue);
    expect(tester.takeException(), isNull);
    expect(errs, isEmpty);
  });

  for (final String lang in <String>['en', 'fa']) {
    testWidgets('app router as guest: menus open their pages, online-only ones the sign-in screen ($lang)',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settings.lang': lang,
        'settings.auth_mode': 'guest',
        'settings.oracle_buddy': false,
        // Guided ORACLE tours already seen (a tour is a full-screen coach mark that would take the taps).
        'oracle_tour.seen.local': '["home","dock","rooms","social","settings","oracle","tournaments","games","shop",'
            '"chat","profile","game_setup.pool8","game_setup.finger_soccer"]',
      });
      await LocalStore.init();
      _phone(tester);
      final List<String> errs = _captureErrors();
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);
      if (!c.read(profileProvider).hasIdentity) c.read(profileProvider).updateProfile(name: 'Ashkan');
      await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NexoraApp()));
      await _frames(tester, 20);
      _release(); // navigation failures must surface as test failures
      final GoRouter r = GoRouter.of(tester.element(find.byType(Navigator).first));
      r.go('/hub');
      await _frames(tester, 10);
      expect(find.byType(StationPage), findsOneWidget);

      final Map<String, Type> expected = <String, Type>{
        '/rooms': StationRoomsScreen,
        '/s/games?records=1': StationGamesScreen,
        '/arcade/pool8': StationGameScreen,
        '/arcade/finger_soccer': StationGameScreen,
        '/oracle': StationAiScreen,
        '/settings': StationSettingsScreen,
        '/s/profile': StationProfileScreen,
        '/social': StationSignInRequired,
        '/world/orbit_network': StationSignInRequired,
        '/tournaments': StationSignInRequired,
        '/leaderboard': StationSignInRequired,
        '/online/finger_soccer': StationSignInRequired,
      };
      for (final MapEntry<String, Type> e in expected.entries) {
        r.go('/hub');
        await _frames(tester, 8);
        r.push(e.key);
        await _frames(tester, 12);
        expect(find.byType(e.value), findsOneWidget, reason: e.key);
        expect(find.byType(StationPage, skipOffstage: false), findsOneWidget, reason: '${e.key}: no duplicate home page');
        r.pop();
        await _frames(tester, 10);
        expect(find.byType(StationPage), findsOneWidget, reason: '${e.key}: back');
      }
      expect(tester.takeException(), isNull);
      expect(errs, isEmpty);
      await _teardown(tester);
    });
  }
}
