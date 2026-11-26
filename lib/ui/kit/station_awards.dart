import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import '../../core/profile/achievements.dart';
import '../../core/profile/profile_service.dart';
import 'station_kit.dart';

/// Level-up / achievement celebration (`#modal` look). Silent when nothing new happened.
Future<void> showAwardOutcome(BuildContext context, AwardOutcome o) async {
  if (!o.levelUp && o.unlocked.isEmpty) return;
  final StationPalette p = StationPalette.of(context);
  await showStationModal(
    context,
    big: o.levelUp ? '⭐' : '🏅',
    title: o.levelUp ? stx(context, 'ارتقای سطح!', 'Level up!') : stx(context, 'دستاورد جدید!', 'New achievement!'),
    text: o.levelUp ? '${stx(context, 'سطح', 'Level')} ${nxNum(context, o.newLevel)}' : '',
    art: o.unlocked.isEmpty
        ? null
        : Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            for (final AchievementDef a in o.unlocked.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: <Widget>[
                  Image.asset(AppAssets.achievement(a.asset), width: 44, height: 44, errorBuilder: (_, __, ___) => const StationIcon('r4c3', size: 44)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      Text(stationFa(context) ? a.nameFa : a.nameEn, style: TextStyle(fontSize: 14, color: p.ink, fontWeight: FontWeight.w500)),
                      Text('${stationFa(context) ? a.descFa : a.descEn}  +${nxNum(context, a.coinReward)}',
                          style: TextStyle(fontSize: 11, color: p.mute)),
                    ]),
                  ),
                ]),
              ),
          ]),
  );
}
