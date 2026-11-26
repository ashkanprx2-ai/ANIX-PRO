import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/storage/local_store.dart';
import 'package:nexora/games/finger_soccer/intro/fs_formation_select.dart';
import 'package:nexora/games/finger_soccer/intro/fs_intro_data.dart';
import 'package:nexora/games/finger_soccer/intro/fs_team_select.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// v3 (owner request 2026-11-20): in the pre-match intro the team on screen is the team that plays (arrows pick an
/// owned / opponent team) and a formation is picked by tapping anywhere on its card.
const List<FsSidePlayer> _players = <FsSidePlayer>[
  FsSidePlayer(name: 'A', portrait: 'assets/ui/anix/avatars/01-vanguard.webp', badge: '1'),
  FsSidePlayer(name: 'B', portrait: 'assets/ui/anix/avatars/04-iron-warden.webp', badge: '2'),
];

Widget _app(Widget child) => MaterialApp(home: Scaffold(backgroundColor: Colors.black, body: child));

void main() {
  setUp(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{'settings.lang': 'fa', 'settings.sound': false});
    await LocalStore.init();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('team select: category tabs + puck grid pick the team (free team / opponent side)', (WidgetTester tester) async {
    phone(tester);
    final List<String> teams = <String>['fx_wolf', 'liverpool'];
    List<String>? ready;
    await tester.pumpWidget(_app(FsTeamSelect(
      fa: true,
      teams: teams,
      players: _players,
      onReady: (List<String> t) => ready = t,
      onShop: () {},
      onBar: () {},
      freeze: true,
    )));
    await tester.pump(const Duration(milliseconds: 300));
    // side one opens on its team's category (fantasy): every tile is an NX puck with its name
    expect(find.byKey(const ValueKey<String>('fs_team_fx_wolf')), findsOneWidget);
    expect(find.text('گرگ'), findsWidgets);
    // tapping another free puck picks it
    await tester.tap(find.byKey(const ValueKey<String>('fs_team_fx_shark')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(teams[0], 'fx_shark');
    // a locked puck is only browsed (buy button), the picked team stays
    await tester.tap(find.byKey(const ValueKey<String>('fs_team_fx_dragon')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(teams[0], 'fx_shark');
    expect(find.textContaining('خرید'), findsOneWidget);
    // side two (opponent, no ownership needed): clubs tab -> Arsenal
    await tester.tap(find.text('تیم دو'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey<String>('fs_tab_clubs')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey<String>('fs_team_arsenal')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(teams[1], 'arsenal');
    await tester.tap(find.text('آماده'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(ready, <String>['fx_shark', 'arsenal']);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  test('team category labels cover the NX puck categories in Persian and English', () {
    expect(fsTeamCategoryName('clubs', true), 'باشگاه‌ها');
    expect(fsTeamCategoryName('clubs', false), 'Clubs');
    expect(fsTeamCategoryName('nations', true), 'ملی');
    expect(fsTeamCategoryName('brands', true), 'برندها');
    expect(fsTeamCategoryName('cars', true), 'ماشین‌ها');
    expect(fsTeamCategoryName('fantasy', true), 'فانتزی');
    expect(fsTeamCategoryName('unknown', false), 'unknown');
  });

  testWidgets('formation select: tapping the mini pitch picks the formation', (WidgetTester tester) async {
    phone(tester);
    int? done;
    await tester.pumpWidget(_app(FsFormationSelect(
      discAsset: 'assets/games/finger_soccer/pucks/iso/fx_wolf.webp',
      initial: 0,
      onDone: (int f) => done = f,
      onBar: () {},
    )));
    await tester.pump(const Duration(milliseconds: 100));
    final Finder pitches =
        find.byWidgetPredicate((Widget w) => w is CustomPaint && w.painter is FsMiniPitchPainter);
    expect(pitches, findsNWidgets(9));
    await tester.tap(pitches.at(4));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('انتخاب شده'), findsOneWidget);
    // a pick runs the loading bar out in ~0.9 s, then the picked index is handed on
    for (int i = 0; i < 40 && done == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(done, 4);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
