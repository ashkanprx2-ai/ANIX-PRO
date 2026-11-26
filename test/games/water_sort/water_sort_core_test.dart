import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/games/water_sort/water_sort_core.dart';

void main() {
  test('pour rules: same colour or empty target, room required, run moves together', () {
    final WsBoard b = WsBoard(<WsTube>[
      WsTube(<int>[0, 1, 1]),
      WsTube(<int>[2, 1]),
      WsTube(<int>[0, 2, 0, 2]),
      WsTube(<int>[]),
    ]);
    expect(b.canPour(0, 1), isTrue);
    expect(b.pourAmount(0, 1), 2);
    expect(b.canPour(0, 2), isFalse); // full
    expect(b.canPour(2, 0), isFalse); // colour mismatch
    expect(b.canPour(3, 0), isFalse); // empty source
    final WsMove? m = b.pour(0, 1);
    expect(m!.amount, 2);
    expect(b.tubes[1].units, <int>[2, 1, 1, 1]);
    b.undo();
    expect(b.tubes[0].units, <int>[0, 1, 1]);
    expect(b.tubes[1].units, <int>[2, 1]);
  });

  test('mystery layers reveal when uncovered and hide again on undo', () {
    final WsBoard b = WsBoard(<WsTube>[
      WsTube(<int>[0, 1, 1, 2], <bool>[true, true, true, false]),
      WsTube(<int>[]),
    ]);
    expect(b.tubes[0].topRun, 1);
    b.pour(0, 1);
    expect(b.tubes[0].hidden, <bool>[true, false, false]);
    b.undo();
    expect(b.tubes[0].hidden, <bool>[true, true, true, false]);
  });

  test('generated levels are deterministic, solvable and ramp up', () {
    final Stopwatch sw = Stopwatch()..start();
    int prevColors = 0;
    for (final int l in <int>[1, 2, 3, 5, 8, 12, 20, 25, 30, 45, 60, 75, 99, 120, 150, 200, 333, 500]) {
      final WsLevel a = WsLevel.generate(l);
      final WsLevel b = WsLevel.generate(l);
      expect(a.board.key(), b.board.key(), reason: 'level $l deterministic');
      expect(a.board.solved, isFalse);
      final List<List<int>>? sol = a.board.solve();
      expect(sol, isNotNull, reason: 'level $l solvable');
      final WsBoard play = a.board.copy();
      for (final WsTube t in play.tubes) {
        t.hidden.fillRange(0, t.hidden.length, false);
      }
      for (final List<int> mv in sol!) {
        expect(play.pour(mv[0], mv[1]), isNotNull);
      }
      expect(play.solved, isTrue);
      expect(a.spec.colors >= prevColors, isTrue);
      prevColors = a.spec.colors;
      // ignore: avoid_print
      print('level $l colors=${a.spec.colors} tubes=${a.board.tubes.length} mystery=${a.spec.mystery} par=${a.par} t=${sw.elapsedMilliseconds}ms');
    }
    expect(WsLevelSpec.of(60).colors, 12);
  });
}
