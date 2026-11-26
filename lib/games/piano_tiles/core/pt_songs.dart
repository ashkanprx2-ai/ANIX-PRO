/// ===================== PIANO TILES · SONG BOOK =====================
/// Note charts for the piano tiles game. Every song is public domain or a traditional folk tune.
///
/// Chart notation (one token per tile, whitespace separated, `|` is only a visual bar line):
///   `C5`      a short tile that plays C5
///   `C5:2`    a long (hold) tile two rows tall
///   `C5+G4`   a double tile: two lanes on the same row, both must be tapped
///   `D#5`     sharps use `#`
/// One row is one beat of the chart; the game scrolls in rows per second.
/// ====================================================================
library;

class PtNote {
  const PtNote(this.pitches, this.len);

  /// MIDI note numbers. Two entries make a double tile.
  final List<int> pitches;

  /// Rows the tile is tall (1 = short tap, 2+ = hold).
  final int len;

  bool get isDouble => pitches.length > 1;
  bool get isHold => len > 1;
}

class PtSong {
  const PtSong({
    required this.id,
    required this.titleFa,
    required this.titleEn,
    required this.subtitleFa,
    required this.subtitleEn,
    required this.speed,
    required this.level,
    required this.chart,
  });

  final String id;
  final String titleFa;
  final String titleEn;
  final String subtitleFa;
  final String subtitleEn;

  /// Base scroll speed in rows per second.
  final double speed;

  /// Difficulty 1..3 (shown as notes on the song card).
  final int level;
  final String chart;

  List<PtNote> get notes => _parsed[id] ??= parseChart(chart);
  static final Map<String, List<PtNote>> _parsed = <String, List<PtNote>>{};
}

const Map<String, int> _steps = <String, int>{'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};

/// `C4` -> 60, `D#5` -> 75, `Bb3` -> 58.
int pitchOf(String name) {
  final RegExpMatch? m = RegExp(r'^([A-G])([#b]?)(-?\d)$').firstMatch(name.trim());
  if (m == null) throw FormatException('bad note "$name"');
  int v = _steps[m.group(1)!]!;
  if (m.group(2) == '#') v++;
  if (m.group(2) == 'b') v--;
  return (int.parse(m.group(3)!) + 1) * 12 + v;
}

List<PtNote> parseChart(String chart) {
  final List<PtNote> out = <PtNote>[];
  for (final String raw in chart.split(RegExp(r'\s+'))) {
    final String tok = raw.trim();
    if (tok.isEmpty || tok == '|') continue;
    final List<String> parts = tok.split(':');
    final int len = parts.length > 1 ? int.parse(parts[1]) : 1;
    final List<int> pitches = parts[0].split('+').map(pitchOf).toList();
    out.add(PtNote(pitches, pitches.length > 1 ? 1 : len));
  }
  return out;
}

/// The lowest and highest MIDI notes synthesised in assets/games/piano_tiles/notes/.
const int kPtLowNote = 55, kPtHighNote = 88;

const List<PtSong> kPtSongs = <PtSong>[
  PtSong(
    id: 'twinkle',
    titleFa: 'چشمک ستاره‌ها',
    titleEn: 'Twinkle Twinkle',
    subtitleFa: 'ترانهٔ کودکانه',
    subtitleEn: 'Nursery rhyme',
    speed: 2.3,
    level: 1,
    chart: 'C5+C4 C5 G5 G5 A5 A5 G5:2 | F5 F5 E5 E5 D5 D5 C5:2 | '
        'G5+E5 G5 F5 F5 E5 E5 D5:2 | G5+E5 G5 F5 F5 E5 E5 D5:2 | '
        'C5+C4 C5 G5 G5 A5 A5 G5:2 | F5 F5 E5 E5 D5 D5 C5+E5 C5:2',
  ),
  PtSong(
    id: 'ode_to_joy',
    titleFa: 'سرود شادی',
    titleEn: 'Ode to Joy',
    subtitleFa: 'بتهوون · سمفونی نهم',
    subtitleEn: 'Beethoven · Symphony No. 9',
    speed: 2.6,
    level: 1,
    chart: 'E5+C5 E5 F5 G5 G5 F5 E5 D5 C5 C5 D5 E5 E5 D5 D5:2 | '
        'E5+C5 E5 F5 G5 G5 F5 E5 D5 C5 C5 D5 E5 D5 C5 C5:2 | '
        'D5+G4 D5 E5 C5 D5 E5 F5 E5 C5 D5 E5 F5 E5 D5 C5 D5 G4:2 | '
        'E5+G4 E5 F5 G5 G5 F5 E5 D5 C5 C5 D5 E5 D5 C5 C5+E5 C5:2',
  ),
  PtSong(
    id: 'frere_jacques',
    titleFa: 'برادر ژاک',
    titleEn: 'Frère Jacques',
    subtitleFa: 'ترانهٔ فولکلور فرانسوی',
    subtitleEn: 'French folk round',
    speed: 2.8,
    level: 2,
    chart: 'C5 D5 E5 C5 C5 D5 E5 C5 | E5 F5 G5:2 E5 F5 G5:2 | '
        'G5 A5 G5 F5 E5 C5 G5 A5 G5 F5 E5 C5 | C5+G4 G4 C5:2 C5+G4 G4 C5:2',
  ),
  PtSong(
    id: 'atal_matal',
    titleFa: 'اتل متل توتوله',
    titleEn: 'Atal Matal Tootooleh',
    subtitleFa: 'ترانهٔ فولکلور ایرانی',
    subtitleEn: 'Persian folk rhyme',
    speed: 2.8,
    level: 2,
    // Traditional Persian children's rhyme, arranged in a Shur-flavoured D mode.
    chart: 'D5+A4 D5 F5 F5 E5 D5 C5:2 | D5 D5 F5 G5 F5 E5 D5:2 | '
        'F5+D5 F5 G5 A5 G5 F5 E5:2 | E5 F5 E5 D5 C5 E5 D5:2 | '
        'A5+F5 A5 G5 F5 G5 A5 G5 F5 | E5 F5 G5 F5 E5 D5 C5:2 | '
        'D5 E5 F5 E5 D5 C5 D5 E5 | F5 E5 D5 C5 E5 D5+A4 D5:2',
  ),
  PtSong(
    id: 'amu_zanjirbaf',
    titleFa: 'عمو زنجیرباف',
    titleEn: 'Amu Zanjirbaf',
    subtitleFa: 'بازی فولکلور ایرانی',
    subtitleEn: 'Persian folk game song',
    speed: 3.0,
    level: 2,
    // Call and response: every «بله!» answer is a double tile.
    chart: 'G4 C5 C5 E5 D5:2 G5+C5 | E5 E5 D5 C5 D5 E5 D5:2 G5+B4 | '
        'E5 D5 C5 D5 E5 C5:2 G5+C5 | G4 C5 C5 E5 D5 C5 B4 C5:2 | '
        'E5 E5 F5 G5 G5 F5 E5 D5 | E5 E5 D5 C5 D5:2 G5+B4 | '
        'C5 D5 E5 F5 G5 E5 C5:2 | D5 E5 D5 C5 B4 D5 C5+E5 C5:2',
  ),
  PtSong(
    id: 'happy_birthday',
    titleFa: 'تولدت مبارک',
    titleEn: 'Happy Birthday',
    subtitleFa: 'ترانهٔ جشن',
    subtitleEn: 'Party song',
    speed: 3.1,
    level: 2,
    chart: 'G4 G4 A4:2 G4 C5:2 B4:3 | G4 G4 A4:2 G4 D5:2 C5:3 | '
        'G4 G4 G5:2 E5 C5 B4 A4:2 | F5 F5 E5:2 C5 D5 C5+E5 C5:3',
  ),
  PtSong(
    id: 'fur_elise',
    titleFa: 'برای الیزه',
    titleEn: 'Für Elise',
    subtitleFa: 'بتهوون · باگاتل',
    subtitleEn: 'Beethoven · Bagatelle',
    speed: 3.5,
    level: 3,
    chart: 'E5 D#5 E5 D#5 E5 B4 D5 C5 A4:2 | C4 E4 A4 B4:2 | E4 G#4 B4 C5:2 | '
        'E4 E5 D#5 E5 D#5 E5 B4 D5 C5 A4:2 | C4 E4 A4 B4:2 | E4 C5 B4 A4:2 | '
        'B4 C5 D5 E5:2 G4 F5 E5 D5:2 F4 E5 D5 C5:2 E4 D5 C5 B4:2 | '
        'E4 E5 E6 D#5 E5 D#5 E5 D#5 E5 B4 D5 C5 A4+C4 A4:2',
  ),
];

PtSong ptSong(String id) => kPtSongs.firstWhere((PtSong s) => s.id == id, orElse: () => kPtSongs.first);

/// Every pitch used by [song] (for preloading its samples).
Set<int> ptPitches(PtSong song) => <int>{for (final PtNote n in song.notes) ...n.pitches};
