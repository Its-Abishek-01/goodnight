import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../alarm/alarm_qr_screen.dart';

/// Lists every permission GoodNight needs and lets the user grant them.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  final _items = <_PermItem>[
    _PermItem('Notifications', 'Show the alarm and reminders.', Permission.notification),
    _PermItem('Exact alarms', 'Ring at the exact wake-up minute.', Permission.scheduleExactAlarm),
    _PermItem('Run in background', 'Stops the phone from killing the alarm.', Permission.ignoreBatteryOptimizations),
    _PermItem('Camera', 'Scan the alarm QR code.', Permission.camera),
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

  Future<void> _refresh() async {
    for (final i in _items) {
      _granted[i.permission] = await i.permission.isGranted;
    }
    if (mounted) setState(() {});
  }

  Future<void> _grant(_PermItem i) async {
    final status = await i.permission.request();
    if (status.isPermanentlyDenied) await openAppSettings();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Setup', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        for (final i in _items)
          Card(
            child: ListTile(
              title: Text(i.title),
              subtitle: Text(i.subtitle),
              trailing: _granted[i.permission] == true
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : FilledButton(onPressed: () => _grant(i), child: const Text('Allow')),
            ),
          ),
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
      ],
    );
  }
}

class _PermItem {
  _PermItem(this.title, this.subtitle, this.permission);
  final String title;
  final String subtitle;
  final Permission permission;
}
