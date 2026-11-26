import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/online/online_service.dart';
import '../../core/safety/safety_actions.dart';
import '../../core/settings/app_settings.dart';
import '../../ui/kit/station_compat.dart';
/// Settings → Blocked users (P0 #7): everyone the signed-in user blocked, with Unblock.
class BlockedUsersPage extends ConsumerStatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  ConsumerState<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends ConsumerState<BlockedUsersPage> {
  List<Map<String, dynamic>>? _rows;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dynamic r = await ref.read(onlineProvider).rpc('nx_my_blocks');
      if (!mounted) return;
      setState(() {
        _failed = false;
        _rows = r is List ? r.map((dynamic e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final NxThemeColors visual = NxThemeColors.of(context);
    final List<Map<String, dynamic>>? rows = _rows;
    return StationScreen(
      title: context.tx('کاربران مسدودشده', 'Blocked users'),
      balance: false,
      child: _failed
          ? Center(
              child: TextButton(onPressed: _load, child: Text(context.tx('بارگذاری نشد؛ دوباره', 'Could not load; retry'))))
          : rows == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: rows.isEmpty
                      ? ListView(children: <Widget>[
                          const SizedBox(height: 120),
                          Center(
                              child: Text(context.tx('کسی را مسدود نکرده‌ای.', 'You have not blocked anyone.'),
                                  style: TextStyle(color: visual.muted))),
                        ])
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (BuildContext context, int i) {
                            final Map<String, dynamic> u = rows[i];
                            final String name = '${u['username'] ?? ''}';
                            final String display = '${u['display_name'] ?? ''}';
                            final String avatar = '${u['avatar_url'] ?? ''}';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatar.startsWith('http') ? NetworkImage(avatar) : null,
                                child: avatar.startsWith('http') ? null : Text(name.isEmpty ? '?' : name[0].toUpperCase()),
                              ),
                              title: Text(display.isNotEmpty ? display : name),
                              subtitle: Text('@$name', textDirection: TextDirection.ltr),
                              trailing: OutlinedButton(
                                onPressed: () async {
                                  final bool? now = await toggleBlockUser(context,
                                      userId: '${u['user_id']}', username: name, currentlyBlocked: true);
                                  if (now == false) await _load();
                                },
                                child: Text(context.tx('رفع مسدودی', 'Unblock')),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
