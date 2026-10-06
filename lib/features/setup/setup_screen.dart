import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../alarm/alarm_qr_screen.dart';
import '../blocking/blocker_channel.dart';
import '../pairing/pair.dart';
import '../profile/profile_section.dart';
import '../settings/features.dart';
import '../settings/features_providers.dart';
import '../settings/delete_data.dart';
import '../settings/features_section.dart';

/// The feature picker, then every permission the chosen features need.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key, required this.pair, required this.uid});

  final Pair pair;
  final String uid;

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> with WidgetsBindingObserver {
  final _items = <_PermItem>[
    _PermItem('Notifications', 'Show the alarm and reminders.', Permission.notification),
    _PermItem('Exact alarms', 'Ring at the exact wake-up minute.', Permission.scheduleExactAlarm,
        needed: (p, _) => p.alarm),
    _PermItem('Run in background', 'Stops the phone from killing the alarm.', Permission.ignoreBatteryOptimizations,
        needed: (p, _) => p.alarm || p.nightMode),
    _PermItem('Camera', 'Scan the alarm QR code and take selfies.', Permission.camera,
        needed: (p, s) => p.alarm || s.moments),
  ];
  final Map<Permission, bool> _granted = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  bool _serviceOn = false;

  Future<void> _refresh() async {
    for (final i in _items) {
      _granted[i.permission] = await i.permission.isGranted;
    }
    try {
      _serviceOn = await Blocker.isServiceEnabled();
    } catch (_) {
      _serviceOn = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _enableBlocking() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow night mode blocking'),
        content: const Text(
          'GoodNight uses Android\'s Accessibility service to see which app or '
          'website is in front, only during the bedtime hours you and your partner '
          'agreed on. It pauses Instagram and YouTube Shorts after a short grace '
          'time. It never reads messages, passwords or what you type, and it '
          'collects nothing else.\n\n'
          'If the switch is greyed out: tap "App info", open the three-dot menu, '
          'choose "Allow restricted settings", then come back and turn on '
          '"GoodNight night mode" under Accessibility.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () async {
              await Blocker.openAppDetails();
            },
            child: const Text('App info'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I agree'),
          ),
        ],
      ),
    );
    if (go == true) await Blocker.openAccessibilitySettings();
  }

  Future<void> _grant(_PermItem i) async {
    final status = await i.permission.request();
    if (status.isPermanentlyDenied) await openAppSettings();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myFeaturesProvider) ?? PersonalFeatures.all;
    final shared = ref.watch(sharedFeaturesProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Us',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ProfileSection(pair: widget.pair, uid: widget.uid),
        const SizedBox(height: 12),
        FeaturesSection(pair: widget.pair, uid: widget.uid),
        const SizedBox(height: 12),
        Text('Permissions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final i in _items.where((i) => i.needed(mine, shared)))
          Card(
            child: ListTile(
              title: Text(i.title),
              subtitle: Text(i.subtitle),
              trailing: _granted[i.permission] == true
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : FilledButton(onPressed: () => _grant(i), child: const Text('Allow')),
            ),
          ),
        if (mine.nightMode)
          Card(
            child: ListTile(
              title: const Text('Night mode blocking'),
              subtitle: const Text(
                'Pauses Instagram, instagram.com and YouTube Shorts after a short grace time at night.',
              ),
              trailing: _serviceOn
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : FilledButton(
                      onPressed: _enableBlocking,
                      child: const Text('Turn on'),
                    ),
            ),
          ),
        if (mine.alarm)
          Card(
            child: ListTile(
              title: const Text('Alarm QR code'),
              subtitle: const Text('Needed for the hardest wake-up challenge.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const AlarmQrScreen()),
              ),
            ),
          ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
            title: const Text('Delete my data'),
            subtitle: const Text('End the pact and delete everything you both stored.'),
            onTap: () => confirmDeleteData(context, widget.pair),
          ),
        ),
      ],
    );
  }
}

bool _always(PersonalFeatures _, SharedFeatures _) => true;

class _PermItem {
  _PermItem(this.title, this.subtitle, this.permission, {this.needed = _always});
  final String title;
  final String subtitle;
  final Permission permission;

  /// Whether the features in use need this permission.
  final bool Function(PersonalFeatures, SharedFeatures) needed;
}
