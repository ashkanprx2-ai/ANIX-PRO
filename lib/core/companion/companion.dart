/// The two AI companions of NEXORA — ORACLE and LUNA ("Two Minds, One Universe").
///
/// Everything that used to be "the ORACLE character" (corner buddy, lines, tours, game sheet, AI chat, edge-function
/// persona) now asks [CompanionController] which companion is active. The choice is stored on the device
/// (`companion.active`) and in the profile's synced `equipped['companion']` slot, so it follows the account to other
/// phones through the existing cloud profile sync.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_service.dart';
import '../storage/local_store.dart';

enum CompanionId { oracle, luna }

CompanionId companionFromName(String? s) => s == 'luna' ? CompanionId.luna : CompanionId.oracle;

/// Expressions shared by both sticker sets (`assets/characters/ID/MOOD.webp`).
enum CompanionMood {
  happy, wink, love, confused, cool, shush, angry, cry, cheer, gamer, sleep, hearteyes, smart, salute, sign,
  // LUNA-only extras (ORACLE falls back to a close expression).
  fly, shy, plush, kiss, peek,
}

@immutable
class CompanionInfo {
  const CompanionInfo({
    required this.id,
    required this.nameFa,
    required this.nameEn,
    required this.roleFa,
    required this.roleEn,
    required this.bioFa,
    required this.bioEn,
    required this.color,
    required this.personaRow,
  });

  final CompanionId id;
  final String nameFa;
  final String nameEn;
  final String roleFa;
  final String roleEn;
  final String bioFa;
  final String bioEn;
  final Color color;

  /// Row id in `public.nx_oracle_persona` (1 = ORACLE, 2 = LUNA).
  final int personaRow;

  String get key => id.name;
  String name(bool fa) => fa ? nameFa : nameEn;
  String role(bool fa) => fa ? roleFa : roleEn;
  String bio(bool fa) => fa ? bioFa : bioEn;

  String get avatar => 'assets/characters/$key/avatar.webp';
  String get hero => 'assets/characters/$key/hero.webp';

  String mood(CompanionMood m) {
    if (id == CompanionId.oracle) {
      m = switch (m) {
        CompanionMood.fly => CompanionMood.cheer,
        CompanionMood.shy => CompanionMood.shush,
        CompanionMood.plush => CompanionMood.love,
        CompanionMood.kiss => CompanionMood.wink,
        CompanionMood.peek => CompanionMood.happy,
        _ => m,
      };
    }
    return 'assets/characters/$key/${m.name}.webp';
  }

  static const CompanionInfo oracle = CompanionInfo(
    id: CompanionId.oracle,
    nameFa: 'اوراکل',
    nameEn: 'ORACLE',
    roleFa: 'دستیار هوش مصنوعی نکسورا',
    roleEn: 'NEXORA AI assistant',
    bioFa: 'شیطون، بامزه و کمی بدجنس؛ با «جاااااان!» معروفش سربه‌سرت می‌ذاره و قوانین همه‌ی بازی‌ها رو بلده.',
    bioEn: 'Cheeky, funny and a bit sarcastic — teases you with his famous «Jaaaaan!» and knows every game\'s rules.',
    color: Color(0xFFFF9A3D),
    personaRow: 1,
  );

  static const CompanionInfo luna = CompanionInfo(
    id: CompanionId.luna,
    nameFa: 'لونا',
    nameEn: 'LUNA',
    roleFa: 'دستیار هوش مصنوعی نکسورا',
    roleEn: 'NEXORA AI assistant',
    bioFa: 'مهربون، پرانرژی و دخترونه‌شیطون؛ با «عزیییزم!» تشویقت می‌کنه، حواسش به حالت هست و بازی‌ها رو قشنگ یادت می‌ده.',
    bioEn: 'Warm, bubbly and playfully sweet — cheers you on with «Azizam!», cares how you feel and teaches every game gently.',
    color: Color(0xFFC25BFF),
    personaRow: 2,
  );

  static CompanionInfo of(CompanionId id) => id == CompanionId.luna ? luna : oracle;
  static const List<CompanionInfo> all = <CompanionInfo>[oracle, luna];
}

/// Holds the active companion. Listeners (buddy, AI page, persona engine) rebuild when it changes.
class CompanionController extends ChangeNotifier {
  CompanionController(this._store, this._profile) {
    _active = companionFromName(_profile?.equipped['companion'] ?? _store.getString(kStoreKey));
    _profile?.addListener(_onProfile);
    _apply();
  }

  static const String kStoreKey = 'companion.active';

  /// The app-wide controller (set by the provider), for code outside the widget tree.
  static CompanionController? current;

  /// Called whenever the active companion changes (the persona engine swaps its config).
  static final List<void Function(CompanionId)> onSwitch = <void Function(CompanionId)>[];

  final LocalStore _store;
  final ProfileService? _profile;
  late CompanionId _active;

  CompanionId get active => _active;
  CompanionInfo get info => CompanionInfo.of(_active);

  /// The active companion without a controller (tests / pure code): device choice, ORACLE by default.
  static CompanionId get activeId => current?._active ?? CompanionId.oracle;

  void _onProfile() {
    final String? synced = _profile?.equipped['companion'];
    if (synced == null) return;
    final CompanionId c = companionFromName(synced);
    if (c != _active) {
      _active = c;
      _store.setString(kStoreKey, c.name);
      _apply();
      notifyListeners();
    }
  }

  void _apply() {
    for (final void Function(CompanionId) f in onSwitch) {
      f(_active);
    }
  }

  void select(CompanionId c) {
    if (c == _active) return;
    _active = c;
    _store.setString(kStoreKey, c.name);
    // Synced with the account through the profile blob (equipped slots travel with cloud sync).
    _profile?.setPreference('companion', c.name);
    _apply();
    notifyListeners();
  }

  @override
  void dispose() {
    _profile?.removeListener(_onProfile);
    super.dispose();
  }
}

final companionProvider = ChangeNotifierProvider<CompanionController>((Ref ref) {
  final CompanionController c = CompanionController(LocalStore.instance, ref.read(profileProvider));
  CompanionController.current = c;
  return c;
});
