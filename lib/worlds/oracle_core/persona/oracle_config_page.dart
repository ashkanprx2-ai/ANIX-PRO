import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../ui/kit/station_compat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/online/online_service.dart';
import 'json_form_editor.dart';
import 'luna_persona_data.dart';
import 'oracle_persona.dart';
import 'oracle_persona_data.dart';
import 'oracle_persona_store.dart';

/// Admin: edit the personality config of ORACLE (row 1) or LUNA (row 2) (players & aliases, lines, greetings, spontaneous lines, reactions,
/// tutorials, tour texts, frequencies, cooldowns, category switches). Saved to Supabase (`nx_oracle_persona_save`,
/// owner / 'oracle' permission only, audited); every app picks it up on its next refresh.
class OracleConfigPage extends ConsumerStatefulWidget {
  const OracleConfigPage({super.key});

  @override
  ConsumerState<OracleConfigPage> createState() => _OracleConfigPageState();
}

class _OracleConfigPageState extends ConsumerState<OracleConfigPage> {
  final TextEditingController _c = TextEditingController();
  Map<String, dynamic> _data = <String, dynamic>{};
  bool _loading = true, _saving = false, _json = false, _dirty = false;
  int _formKey = 0;
  String? _msg;
  String _who = 'oracle';

  Map<String, dynamic> get _defaults => _who == 'luna' ? kLunaPersonaDefaults : kOraclePersonaDefaults;

  static Map<String, dynamic> _copy(Map<String, dynamic> m) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(m)) as Map);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SupabaseClient? c = ref.read(onlineProvider).client;
    Map<String, dynamic> data = _copy(_defaults);
    try {
      final Map<String, dynamic>? row = await c?.from('nx_oracle_persona').select('data, version').eq('id', OraclePersonaStore.rowOf(_who)).maybeSingle();
      final Object? d = row?['data'];
      if (d is Map && d.isNotEmpty) data = _copy(Map<String, dynamic>.from(d));
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  /// Switch between the form and the raw JSON (advanced); the JSON text is parsed back when leaving it.
  bool _toggleJson() {
    if (_json) {
      try {
        final Object? j = jsonDecode(_c.text);
        if (j is! Map) throw const FormatException('not an object');
        _data = _copy(Map<String, dynamic>.from(j));
      } catch (e) {
        setState(() => _msg = 'JSON نامعتبر: $e');
        return false;
      }
    } else {
      _c.text = const JsonEncoder.withIndent('  ').convert(_data);
    }
    setState(() {
      _json = !_json;
      _formKey++;
    });
    return true;
  }

  Future<void> _save() async {
    final SupabaseClient? c = ref.read(onlineProvider).client;
    if (c == null) return;
    if (_json && !_toggleJson()) return;
    try {
      OraclePersona(config: _data); // validates that the engine accepts it
    } catch (e) {
      setState(() => _msg = 'تنظیمات نامعتبر: $e');
      return;
    }
    setState(() => _saving = true);
    final String? err = await OraclePersonaStore.save(c, _copy(_data), companion: _who);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = err != null;
      _msg = err == null ? 'ذخیره شد ✓ — همه‌ی گوشی‌ها در رفرش بعدی می‌گیرند.' : 'خطا: $err';
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _switch(String who) async {
    if (who == _who) return;
    if (_dirty && !await showStationConfirm(context, title: 'تغییرات ذخیره‌نشده دور ریخته شود؟', confirm: 'بله', danger: true)) return;
    setState(() {
      _who = who;
      _loading = true;
      _dirty = false;
      _json = false;
      _msg = null;
      _formKey++;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StationScreen(
        title: 'شخصیت اوراکل و لونا',
        balance: false,
        actions: <Widget>[
          StationRoundButton(
            tooltip: _json ? 'فرم' : 'JSON (پیشرفته)',
            icon: _json ? Icons.view_list_rounded : Icons.data_object_rounded,
            onTap: _loading ? null : _toggleJson,
          ),
          StationRoundButton(
            tooltip: 'پیش‌فرض',
            icon: Icons.restore_rounded,
            onTap: () => setState(() {
              _data = _copy(_defaults);
              _c.text = const JsonEncoder.withIndent('  ').convert(_data);
              _dirty = true;
              _formKey++;
            }),
          ),
          StationRoundButton(
            tooltip: 'ذخیره',
            icon: Icons.save_rounded,
            active: _dirty,
            onTap: _saving || _loading ? null : _save,
          ),
        ],
        child: Column(children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StationSeg(labels: const <String>['اوراکل', 'لونا'], index: _who == 'luna' ? 1 : 0, onChanged: (int i) => _switch(i == 1 ? 'luna' : 'oracle')),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Text(
              _msg ??
                  'هر بخش را باز کن و ویرایش کن: بازیکن‌ها و اسم‌های دیگرشان، جمله‌ها، خوشامدها، جمله‌های خودجوش، '
                      'واکنش برد/باخت، آموزش‌ها، متن تورها، احتمال‌ها و روشن/خاموش هر بخش. {jan} = «جاااااااااان».',
              style: TextStyle(fontFamily: kStationFont, color: p.mute, fontSize: 12, height: 1.7),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: p.gold))
                : _json
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: TextField(
                            controller: _c,
                            maxLines: null,
                            expands: true,
                            onChanged: (_) => _dirty = true,
                            style: TextStyle(color: p.ink, fontFamily: 'monospace', fontSize: 12),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: p.inputFill,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.line)),
                            ),
                          ),
                        ),
                      )
                    : JsonFormEditor(
                        key: ValueKey<String>('$_who-$_formKey'),
                        value: _data,
                        labels: kOracleConfigLabels,
                        onChanged: () {
                          if (!_dirty) setState(() => _dirty = true);
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}
