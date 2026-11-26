import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/app_settings.dart';
import '../../ui/kit/station_compat.dart';
import 'legal_texts.dart';

/// `/legal/privacy` and `/legal/terms` (P0 #6). Reachable without signing in (sign-up links here).
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.kind});

  /// 'privacy' or 'terms'.
  final String kind;

  @override
  Widget build(BuildContext context) {
    final bool fa = context.isFa;
    final bool privacy = kind == 'privacy';
    final List<LegalSection> sections = privacy ? (fa ? privacyFa : privacyEn) : (fa ? termsFa : termsEn);
    final NxThemeColors visual = NxThemeColors.of(context);
    return StationScreen(
      title: privacy ? context.tx('حریم خصوصی', 'Privacy Policy') : context.tx('شرایط استفاده', 'Terms of Use'),
      balance: false,
      onBack: () => context.canPop() ? context.pop() : context.go('/auth'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: <Widget>[
          Text(context.tx('آخرین به‌روزرسانی: $legalVersion', 'Last updated: $legalVersion'),
              style: TextStyle(color: visual.muted, fontSize: 12)),
          for (final LegalSection s in sections) ...<Widget>[
            const SizedBox(height: 18),
            Text(s.title, style: TextStyle(color: visual.accent, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(s.body, style: TextStyle(color: visual.text, height: 1.6)),
          ],
        ],
      ),
    );
  }
}
