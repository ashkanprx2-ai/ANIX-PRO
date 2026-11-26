import 'package:flutter/material.dart';

import '../solo/solo_kit.dart';
import 'gate_shooter_board.dart';

export 'gate_shooter_board.dart' show GateShooterBoard;

/// Registry entry of دونده‌ی تیرانداز (Gate Shooter). Added to `kSoloDefs` with one line.
final SoloDef kGateShooterDef = SoloDef(
  id: 'gate_shooter',
  titleFa: 'دونده‌ی تیرانداز',
  titleEn: 'Gate Shooter',
  hintFa: 'انگشتت را چپ و راست بکش تا جوخه را هدایت کنی؛ سربازها خودشان شلیک می‌کنند. بشکه‌ها و جعبه‌های شماره‌دار را بشکن، '
      'از دروازه‌ی آبی رد شو تا سربازها و قدرتت بیشتر شود و از دروازه‌ی قرمز دوری کن. هر سه موج یک غول در راه است؛ با سکه‌ها ارتقا بخر.',
  hintEn: 'Drag left and right to steer the squad; it fires on its own. Break the numbered barrels and crates, run through '
      'blue gates to grow your squad and firepower and dodge the red ones. Every third wave brings a boss; spend coins on upgrades.',
  control: SoloControl.drag,
  accent: const Color(0xFF3FA2FF),
  accent2: const Color(0xFFFFD34E),
  board: (BuildContext c, SoloRun r) => GateShooterBoard(run: r),
);
