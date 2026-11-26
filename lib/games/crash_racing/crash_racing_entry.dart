import 'package:flutter/widgets.dart';

import '../core/game_contract.dart';
import 'ui/cr_screen.dart';

/// «کرش ریسینگ» (Crash Racing): pseudo-3D kart racer vs 5 AI drivers — power-slide turbos, ramps, ? crates,
/// star-mangos, the guardian mask, 3 tracks, global best-race / best-lap boards on the games project.
Widget buildCrashRacingGame(GameLaunch launch) => CrashRacingGame(launch: launch);
