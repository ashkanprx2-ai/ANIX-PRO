// The Station login shows the "Continue with Google" button (with the painted G mark) next to the username /
// e-mail login, in Persian (RTL) and English, and tapping it without an online config says so instead of crashing.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nexora/core/settings/app_settings.dart';
import 'package:nexora/core/storage/local_store.dart';
import 'package:nexora/ui/kit/station_kit.dart';
import 'package:nexora/ui/screens/auth_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pump(WidgetTester tester, String lang) async {
  SharedPreferences.setMockInitialValues(<String, Object>{'settings.lang': lang});
  await LocalStore.init();
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final ProviderContainer c = ProviderContainer();
  addTearDown(c.dispose);
  c.read(settingsProvider).languageCode = lang;
  final GoRouter router = GoRouter(routes: <RouteBase>[GoRoute(path: '/', builder: (_, __) => const StationAuthPage())]);
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
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return c;
}

void main() {
  for (final String lang in <String>['fa', 'en']) {
    testWidgets('login screen renders the Google button ($lang)', (WidgetTester tester) async {
      await _pump(tester, lang);
      final Finder google = find.byKey(const ValueKey<String>('auth-google'));
      expect(google, findsOneWidget);
      expect(tester.widget<StationButton>(google).onTap, isNotNull);
      expect(find.descendant(of: google, matching: find.byType(GoogleMark)), findsOneWidget);
      expect(find.text(lang == 'fa' ? 'ورود با گوگل' : 'Continue with Google'), findsOneWidget);
      // The username / e-mail login stays.
      expect(find.byKey(const ValueKey<String>('auth-id')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Google tap without an online config shows a plain message', (WidgetTester tester) async {
    await _pump(tester, 'fa');
    await tester.ensureVisible(find.byKey(const ValueKey<String>('auth-google')));
    await tester.tap(find.byKey(const ValueKey<String>('auth-google')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('اتصال آنلاین تنظیم نشده است.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
