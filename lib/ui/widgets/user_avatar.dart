import 'package:flutter/material.dart';

import '../kit/station_kit.dart';

/// The painted player portraits (profile `portrait` ids) in assets/avatar/portraits.
class PlayerPortraits {
  PlayerPortraits._();
  static const List<String> ids = <String>[
    '01-vanguard', '02-cyber-scout', '03-moon-elf', '04-iron-warden', '05-crimson-duelist', '06-onyx-knight',
    '07-star-fox', '08-void-assassin', '09-arcane-scholar', '10-frostborn', '11-sprout-drone', '12-shadow-mage',
    '13-elder-sage', '14-stonebreaker', '15-violet-psion', '16-golden-sentinel', '17-neon-ranger', '18-bark-guardian',
    '19-night-elf', '20-rune-touched', '21-goggle-fox', '22-hooded-oracle', '23-nova-pilot', '24-lumen-android',
  ];
  static const String fallback = '01-vanguard';
  static String asset(String id) => 'assets/avatar/portraits/$id.webp';
}

/// Small round avatar for any player (Station `.a`): an uploaded photo (https url), a painted portrait id, or initials.
class NxUserAvatar extends StatelessWidget {
  const NxUserAvatar({super.key, required this.avatar, required this.name, this.size = 36, this.ring});
  final String? avatar;
  final String name;
  final double size;

  /// Optional ring colour (e.g. speaking / manager highlight).
  final Color? ring;

  static bool isPhoto(String? a) => a != null && (a.startsWith('https://') || a.startsWith('http://'));

  @override
  Widget build(BuildContext context) {
    final String? a = avatar;
    if (isPhoto(a) || a == null || !PlayerPortraits.ids.contains(a)) {
      final Widget l = StationLetter(name, size: size, imageUrl: isPhoto(a) ? a : null);
      if (ring == null) return l;
      return Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, color: ring), child: l);
    }
    final StationPalette p = StationPalette.of(context);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: ring == null ? p.primary : null, color: ring),
      child: ClipOval(
        child: Image.asset(PlayerPortraits.asset(a), fit: BoxFit.cover, cacheWidth: (size * 3).round(),
            errorBuilder: (_, __, ___) => StationLetter(name, size: size)),
      ),
    );
  }
}
