import 'package:flutter/material.dart';

import '../models.dart';
import '../services/backend.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gates.dart';
import 'channel_screen.dart';
import 'create_channel_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

/// Profile: name (editable), settings, account, My Channels (created + joined).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Channel>? created;
  List<Channel>? joined;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Backend.myCreatedChannels(), Backend.joinedChannels()]);
      if (!mounted) return;
      final createdIds = r[0].map((c) => c.id).toSet();
      setState(() {
        created = r[0];
        joined = r[1].where((c) => !createdIds.contains(c.id)).toList();
      });
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: app.status?.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(controller: ctrl, autofocus: true, maxLength: 40, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await app.updateName(name);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _createChannel() async {
    if (!await ensureLoggedIn(context, reason: 'Log in to create a channel')) return;
    if (!mounted) return;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const CreateChannelScreen()));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.status;
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 150,
                flexibleSpace: FlexibleSpaceBar(
                  background: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 56, 8, 12),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor: const Color(0xFFD84343),
                            child: Text(
                              (s?.displayName ?? 'U').characters.first.toUpperCase(),
                              style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            s?.displayName ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.edit_square, color: Colors.white), tooltip: 'Edit name', onPressed: _editName),
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          tooltip: 'Settings',
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _account(s)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
                  child: Row(children: [
                    const Expanded(child: Text('My Channels', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
                    TextButton(onPressed: _createChannel, child: const Text('Add Channel', style: TextStyle(fontSize: 16))),
                  ]),
                ),
              ),
              if (created == null)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())))
              else if (created!.isEmpty && joined!.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(message: 'No Record Found', icon: Icons.live_tv_outlined)),
                )
              else
                SliverList.list(children: [
                  for (final c in created!) _channelTile(c, mine: true),
                  for (final c in joined!) _channelTile(c),
                ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _account(UserStatus? s) {
    if (s == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (s.isGuest) ...[
            const Text('You\'re using the app as a guest.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('Log in / Create account'),
            ),
          ] else ...[
            Row(children: [
              const Icon(Icons.email_outlined, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(app.email ?? '', style: const TextStyle(fontSize: 16))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(s.isPremium ? Icons.workspace_premium : Icons.person_outline, color: s.isPremium ? AppColors.gold : AppColors.muted),
              const SizedBox(width: 8),
              Text(s.isPremium ? '${s.planName} active' : 'Free account', style: const TextStyle(fontSize: 16)),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _channelTile(Channel c, {bool mine = false}) {
    Widget? badge;
    if (mine) {
      badge = switch (c.reviewStatus) {
        'pending' => const Chip(label: Text('Waiting for approval'), backgroundColor: Color(0xFFFFF3CD)),
        'rejected' => const Chip(label: Text('Not approved'), backgroundColor: Color(0xFFF8D7DA)),
        _ => const Chip(label: Text('Your channel'), backgroundColor: Color(0xFFE8F5E9)),
      };
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: ChannelAvatar(url: c.iconUrl, name: c.name, size: 52),
      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      subtitle: Text('${c.membersCount} members'),
      trailing: badge,
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChannelScreen(channelId: c.id)));
        _load();
      },
    );
  }
}
