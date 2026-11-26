// Station hubs at 720×1600 (360×800 @2x): Games, Events, Rewards, Chat, More and the Profile screen.
//   flutter test test_render/station_hub_render_test.dart --dart-define=SHOTS=/workspace/work/shots/out
// Also asserts the hub grid contract: every card of a hub has exactly the same size, and an odd last card is centred.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/profile/profile_service.dart';
import 'package:nexora/core/storage/local_store.dart';
import 'package:nexora/ui/kit/station_hub_grid.dart';
import 'package:nexora/ui/screens/profile_screens.dart';
import 'package:nexora/ui/shell/station_page.dart';
import 'package:nexora/ui/theme/station_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_util.dart';

Widget _app(ProviderContainer c, Widget home) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildStationTheme(StationSkin.neon),
        locale: const Locale('fa'),
        supportedLocales: const <Locale>[Locale('fa'), Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: RepaintBoundary(key: kShotKey, child: home),
      ),
    );

void main() {
  setUp(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{'settings.lang': 'fa', 'settings.oracle_buddy': false});
    await LocalStore.init();
    await loadFonts();
  });

  const Map<String, int> hubs = <String, int>{'games': 0, 'events': 1, 'rewards': 2, 'chat': 4, 'more': 8};
  for (final MapEntry<String, int> h in hubs.entries) {
    testWidgets('hub ${h.key}: equal cards, centred odd last card', (WidgetTester tester) async {
      phone(tester);
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(profileProvider).updateProfile(name: 'Ashkan');
      await tester.pumpWidget(_app(c, StationPage(initialWorld: h.value)));
      await settle(tester, frames: 20);
      final List<Rect> cards = find.byType(StationHubCard).evaluate().map((Element e) => tester.getRect(find.byWidget(e.widget))).toList();
      expect(cards, isNotEmpty);
      for (final Rect r in cards) {
        expect(r.size.width, closeTo(cards.first.width, .5), reason: 'card widths differ');
        expect(r.size.height, closeTo(cards.first.height, .5), reason: 'card heights differ');
      }
      // Two per row; a row with a single card is centred on the screen.
      final Map<double, List<Rect>> rows = <double, List<Rect>>{};
      for (final Rect r in cards) {
        rows.putIfAbsent(r.top.roundToDouble(), () => <Rect>[]).add(r);
      }
      for (final List<Rect> row in rows.values) {
        expect(row.length, lessThanOrEqualTo(2));
        if (row.length == 1) expect(row.first.center.dx, closeTo(180, 1));
      }
      await shoot(tester, 'ui/hub_${h.key}.png');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }

  testWidgets('profile screen', (WidgetTester tester) async {
    phone(tester);
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(profileProvider).updateProfile(name: 'Ashkan');
    await tester.pumpWidget(_app(c, const StationProfileScreen()));
    await settle(tester, frames: 20);
    await shoot(tester, 'ui/profile.png');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
