import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/games/piano_tiles/core/pt_engine.dart';
import 'package:nexora/games/piano_tiles/core/pt_songs.dart';

/// Plays the next tile(s) exactly at their bottom row; returns false when nothing is due.
bool playNext(PtEngine e) {
  final List<PtTile> n = e.next;
  if (n.isEmpty) return false;
  for (final PtTile t in n) {
    expect(e.press(t.lane, t.row + 0.3, pointer: t.id), PtTap.hit);
  }
  return true;
}

void main() {
  test('every chart parses and stays inside the synthesised note range', () {
    expect(kPtSongs.length, greaterThanOrEqualTo(5));
    expect(kPtSongs.map((PtSong s) => s.id).toSet().length, kPtSongs.length);
    for (final PtSong s in kPtSongs) {
      expect(s.notes, isNotEmpty, reason: s.id);
      for (final int p in ptPitches(s)) {
        expect(p, inInclusiveRange(kPtLowNote, kPtHighNote), reason: '${s.id} uses $p');
      }
      expect(s.notes.any((PtNote n) => n.isHold), isTrue, reason: '${s.id} has no hold tile');
      expect(s.notes.any((PtNote n) => n.isDouble), isTrue, reason: '${s.id} has no double tile');
    }
    expect(pitchOf('C4'), 60);
    expect(pitchOf('D#5'), 75);
    expect(pitchOf('A4'), 69);
  });

  test('nothing scrolls until the start tile is tapped', () {
    final PtEngine e = PtEngine(kPtSongs.first, seed: 3);
    e.step(1);
    expect(e.scroll, 0);
    expect(e.next.single.isStart, isTrue);
    // A tap on empty space before starting is forgiven.
    final PtTile start = e.next.single;
    expect(e.press((start.lane + 2) % 4, 0.3), PtTap.ignored);
    expect(e.over, isFalse);
    playNext(e);
    expect(e.started, isTrue);
    e.step(0.1);
    expect(e.scroll, greaterThan(0));
  });

  test('lanes never repeat back to back and doubles use two lanes', () {
    final PtEngine e = PtEngine(ptSong('amu_zanjirbaf'), seed: 11);
    PtTile? prev;
    final List<PtTile> rows = List<PtTile>.of(e.tiles)..sort((PtTile a, PtTile b) => a.row.compareTo(b.row));
    for (final PtTile t in rows) {
      if (t.isDouble) {
        final List<PtTile> pair = rows.where((PtTile o) => o.group == t.group).toList();
        expect(pair.length, 2);
        expect(pair[0].lane != pair[1].lane, isTrue);
      } else if (prev != null && !prev.isDouble) {
        expect(t.lane != prev.lane, isTrue);
      }
      prev = t;
    }
  });

  test('a perfect run earns 3 stars, then the song loops faster (endless)', () {
    final PtSong song = ptSong('twinkle');
    final PtEngine e = PtEngine(song, seed: 5);
    final double base = e.speed;
    int guard = 0;
    while (e.loops == 0 && guard++ < 500) {
      playNext(e);
      // release holds after they fill
      for (int i = 0; i < 40; i++) {
        e.step(1 / 60);
        if (e.over) break;
        final List<PtTile> n = e.next;
        if (n.isNotEmpty && n.first.row - e.scroll < 0.5) break;
      }
      for (final PtTile t in e.tiles) {
        if (t.holding) e.release(t.pointer!);
      }
      expect(e.over, isFalse);
    }
    expect(e.stars, 3);
    expect(e.loops, 1);
    expect(e.endless, isTrue);
    expect(e.speed, greaterThan(base * 1.1));
    expect(e.score, greaterThanOrEqualTo(song.notes.length));
  });

  test('tapping empty lane space ends the run', () {
    final PtEngine e = PtEngine(kPtSongs.first, seed: 2);
    playNext(e);
    final PtTile next = e.next.first;
    final int empty = <int>[0, 1, 2, 3].firstWhere((int l) =>
        !e.tiles.any((PtTile t) => t.lane == l && t.row <= next.row + 0.5 && t.top >= next.row + 0.5));
    expect(e.press(empty, next.row + 0.5), PtTap.miss);
    expect(e.over, isTrue);
    expect(e.missLane, empty);
  });

  test('a tile slipping off the bottom ends the run and rewinds into view', () {
    final PtEngine e = PtEngine(kPtSongs.first, seed: 4);
    playNext(e);
    for (int i = 0; i < 600 && !e.over; i++) {
      e.step(1 / 60);
    }
    expect(e.over, isTrue);
    expect(e.missTile, isNotNull);
    expect(e.rewind, greaterThan(0));
    expect(e.events.any((PtEvent v) => v.kind == PtEventKind.miss), isTrue);
  });

  test('hold tiles score per row while held', () {
    final PtEngine e = PtEngine(ptSong('happy_birthday'), seed: 9);
    // play until the next tile is a hold
    int guard = 0;
    while (!e.next.first.isHold && guard++ < 50) {
      playNext(e);
      e.step(0.05);
    }
    final PtTile h = e.next.first;
    expect(h.isHold, isTrue);
    final int before = e.score;
    e.press(h.lane, h.row + 0.2, pointer: 77);
    expect(h.holding, isTrue);
    for (int i = 0; i < 120 && h.holding; i++) {
      e.step(1 / 60);
    }
    expect(h.holdDone, isTrue);
    expect(e.score - before, h.len + 1);
  });
}
