import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_store.dart';
import '../../ui/theme/station_palette.dart';

enum GraphicsQuality { low, medium, high, ultra }

/// Global app settings (P13, P16, P28). Persisted locally.
class AppSettings extends ChangeNotifier {
  AppSettings(this._store) {
    final q = _store.getString(_kQuality);
    _quality = GraphicsQuality.values
        .firstWhere((e) => e.name == q, orElse: () => GraphicsQuality.high);
    _reducedMotion = _store.getBool(_kReduced) ?? false;
    _languageCode = _store.getString(_kLang) ?? 'fa';
    // Station UI skin (neon = orange/navy, white = ice crystal). A device that had picked the old light appearance
    // starts in the white skin.
    final String? skin = _store.getString(_kSkin);
    _skin = skin == 'white' || (skin == null && _store.getString(_kAppearance) == 'light') ? StationSkin.white : StationSkin.neon;
    _music = false;
    _musicVolume = 0.0;
    _sfxVolume = (_store.getInt(_kSfxVol) ?? 80).clamp(0, 100) / 100.0;
    _sound = _store.getBool(_kSound) ?? true;
    _haptics = _store.getBool(_kHaptics) ?? true;
    _onboarded = _store.getBool(_kOnboarded) ?? false;
    _authMode = _store.getString(_kAuthMode) ?? '';
    _oracleBuddy = _store.getBool(_kOracleBuddy) ?? true;
    _oracleTalk = _store.getBool(_kOracleTalk) ?? true;
    _introSeen = _store.getBool(_kIntroSeen) ?? false;
  }

  static const _kOracleBuddy = 'settings.oracle_buddy';
  static const _kOracleTalk = 'settings.oracle_talk';
  static const _kIntroSeen = 'settings.intro_seen';
  late bool _oracleBuddy;
  late bool _oracleTalk;
  late bool _introSeen;

  /// The mischievous corner ORACLE outside games (off = hidden everywhere).
  bool get oracleBuddy => _oracleBuddy;

  /// Speech bubbles / teasing lines from the corner ORACLE (off = silent, animations only).
  bool get oracleTalk => _oracleTalk;

  set oracleBuddy(bool v) {
    _oracleBuddy = v;
    _store.setBool(_kOracleBuddy, v);
    notifyListeners();
  }

  set oracleTalk(bool v) {
    _oracleTalk = v;
    _store.setBool(_kOracleTalk, v);
    notifyListeners();
  }

  /// True once the full cinematic intro has been watched (or skipped) at least once, so returning users are not
  /// forced through it on every launch. Replayable from Settings.
  bool get introSeen => _introSeen;

  set introSeen(bool v) {
    _introSeen = v;
    _store.setBool(_kIntroSeen, v);
    notifyListeners();
  }

  final LocalStore _store;
  static const _kQuality = 'settings.quality';
  static const _kReduced = 'settings.reduced_motion';
  static const _kLang = 'settings.lang';
  static const _kSound = 'settings.sound';
  static const _kHaptics = 'settings.haptics';
  static const _kOnboarded = 'settings.onboarded';
  static const _kAuthMode = 'settings.auth_mode';
  static const _kMusic = 'settings.music';
  static const _kMusicVol = 'settings.music_volume';
  static const _kSfxVol = 'settings.sfx_volume';
  static const _kAppearance = 'settings.appearance';
  static const _kSkin = 'settings.station_skin';
  static const _kCtlSens = 'settings.controller_sensitivity';
  static const _kCtlLeft = 'settings.controller_left_handed';
  static const _kNotify = 'settings.notifications';

  late GraphicsQuality _quality;
  late bool _reducedMotion;
  late String _languageCode;
  late StationSkin _skin;
  late bool _sound;
  late bool _haptics;
  late bool _onboarded;
  late String _authMode;
  late bool _music;
  late double _musicVolume;
  late double _sfxVolume;

  /// Background music on menus (default on).
  bool get music => _music;

  /// 0..1 background music volume.
  double get musicVolume => _musicVolume;

  set music(bool v) {
    _music = false;
    _store.setBool(_kMusic, false);
    notifyListeners();
  }

  /// 0..1 sound-effects volume (menus, rooms, results).
  double get sfxVolume => _sfxVolume;

  set sfxVolume(double v) {
    _sfxVolume = v.clamp(0.0, 1.0);
    _store.setInt(_kSfxVol, (_sfxVolume * 100).round());
    notifyListeners();
  }

  set musicVolume(double v) {
    _musicVolume = v.clamp(0.0, 1.0);
    _store.setInt(_kMusicVol, (_musicVolume * 100).round());
    notifyListeners();
  }

  GraphicsQuality get quality => _quality;
  bool get reducedMotion => _reducedMotion;
  String get languageCode => _languageCode;
  /// The Station UI skin (UI.zip `setTheme('neon'|'white')`).
  StationSkin get stationSkin => _skin;
  set stationSkin(StationSkin v) {
    if (_skin == v) return;
    _skin = v;
    _store.setString(_kSkin, v.name);
    notifyListeners();
  }

  /// Controller screen: touch sensitivity 10–100 and left-handed button layout (read by games that support them).
  int get controllerSensitivity => (_store.getInt(_kCtlSens) ?? 60).clamp(10, 100);
  set controllerSensitivity(int v) {
    _store.setInt(_kCtlSens, v.clamp(10, 100));
    notifyListeners();
  }

  bool get leftHanded => _store.getBool(_kCtlLeft) ?? false;
  set leftHanded(bool v) {
    _store.setBool(_kCtlLeft, v);
    notifyListeners();
  }

  /// In-app notification banners (tournament reminders, announcements, invites).
  bool get notifications => _store.getBool(_kNotify) ?? true;
  set notifications(bool v) {
    _store.setBool(_kNotify, v);
    notifyListeners();
  }
  bool get isFa => _languageCode == 'fa';
  Locale get locale => Locale(_languageCode);
  bool get sound => _sound;
  bool get haptics => _haptics;
  bool get onboarded => _onboarded;

  /// '', 'email' or 'guest'. Guest is deliberately local-only.
  String get authMode => _authMode;

  void setAuthMode(String mode) {
    if (mode != 'email' && mode != 'guest' && mode.isNotEmpty) return;
    _authMode = mode;
    _store.setString(_kAuthMode, mode);
    notifyListeners();
  }

  void clearAuthMode() => setAuthMode('');

  /// Effects budget helpers used by every world and game.
  bool get fancyEffects =>
      !_reducedMotion && _quality.index >= GraphicsQuality.medium.index;
  int get starCount => switch (_quality) {
        GraphicsQuality.low => 60,
        GraphicsQuality.medium => 140,
        GraphicsQuality.high => 240,
        GraphicsQuality.ultra => 380,
      };

  set quality(GraphicsQuality v) {
    _quality = v;
    _store.setString(_kQuality, v.name);
    notifyListeners();
  }

  set reducedMotion(bool v) {
    _reducedMotion = v;
    _store.setBool(_kReduced, v);
    notifyListeners();
  }

  set languageCode(String v) {
    _languageCode = v;
    _store.setString(_kLang, v);
    notifyListeners();
  }

  set sound(bool v) {
    _sound = v;
    _store.setBool(_kSound, v);
    notifyListeners();
  }

  set haptics(bool v) {
    _haptics = v;
    _store.setBool(_kHaptics, v);
    notifyListeners();
  }

  void markOnboarded() {
    _onboarded = true;
    _store.setBool(_kOnboarded, true);
    notifyListeners();
  }
}

final settingsProvider = ChangeNotifierProvider<AppSettings>(
    (ref) => AppSettings(LocalStore.instance));

/// Bilingual text helper: `context.tx('سلام', 'Hello')`.
extension NxTx on BuildContext {
  bool get isFa => Localizations.localeOf(this).languageCode == 'fa';
  String tx(String fa, String en) => isFa ? fa : en;
}
