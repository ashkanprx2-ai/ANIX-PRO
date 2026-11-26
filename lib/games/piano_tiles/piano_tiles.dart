import 'package:flutter/material.dart';

import '../solo/solo_kit.dart';
import 'ui/pt_board.dart';

/// ===================== PIANO TILES (پیانو تایلز) =====================
/// Self-contained solo game: song book + engine in `core/`, art, audio and board in `ui/`,
/// synthesised piano samples in `assets/games/piano_tiles/` (regenerate with
/// `python3 tool/piano_tiles_synth.py`). Registered as one [SoloDef] in solo_registry.dart.
/// =====================================================================

final SoloDef kPianoTilesDef = SoloDef(
  id: 'piano_tiles',
  titleFa: 'پیانو تایلز',
  titleEn: 'Piano Tiles',
  hintFa: 'کاشی‌های تیره را به ترتیب لمس کن تا ملودی نواخته شود؛ کاشی‌های بلند را نگه دار و کاشی‌های جفت را با هم بزن. '
      'لمس جای خالی یا جا انداختن یک کاشی بازی را تمام می‌کند. بعد از پایان ترانه، حالت بی‌پایان سریع‌تر ادامه می‌دهد.',
  hintEn: 'Tap the dark tiles in order to play the melody; hold the long tiles and hit double tiles together. '
      'Tapping empty space or letting a tile slip ends the run. After the song, endless mode keeps going faster.',
  control: SoloControl.tap,
  accent: const Color(0xFFB79CFF),
  accent2: const Color(0xFFFFE3A8),
  board: (BuildContext c, SoloRun r) => PianoTilesBoard(run: r),
);
