import 'package:flutter/services.dart';

import '../bedtime/schedule.dart';

class BlockStats {
  const BlockStats({
    required this.nightKey,
    required this.blocks,
    required this.usageMinutes,
    required this.prevKey,
    required this.prevBlocks,
    required this.prevUsageMinutes,
    required this.phoneMinutes,
    required this.prevPhoneMinutes,
  });

  final String nightKey;
  final int blocks;
  final int usageMinutes;
  final String prevKey;
  final int prevBlocks;
  final int prevUsageMinutes;
  final int phoneMinutes;
  final int prevPhoneMinutes;

  factory BlockStats.fromMap(Map<Object?, Object?> m) => BlockStats(
        nightKey: m['nightKey'] as String? ?? '',
        blocks: (m['blocks'] as num?)?.toInt() ?? 0,
        usageMinutes: (m['usageMinutes'] as num?)?.toInt() ?? 0,
        prevKey: m['prevKey'] as String? ?? '',
        prevBlocks: (m['prevBlocks'] as num?)?.toInt() ?? 0,
        prevUsageMinutes: (m['prevUsageMinutes'] as num?)?.toInt() ?? 0,
        phoneMinutes: (m['phoneMinutes'] as num?)?.toInt() ?? 0,
        prevPhoneMinutes: (m['prevPhoneMinutes'] as num?)?.toInt() ?? 0,
      );
}

/// Bridge to the native accessibility service that does the blocking.
class Blocker {
  static const _channel = MethodChannel('com.wiozen.goodnight/blocker');


  static Future<bool> isServiceEnabled() async =>
      await _channel.invokeMethod<bool>('isServiceEnabled') ?? false;

  static Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod<void>('openAccessibilitySettings');

  /// Opens App info, where Android 13+ hides "Allow restricted settings".
  static Future<void> openAppDetails() =>
      _channel.invokeMethod<void>('openAppDetails');

  /// [pairId] and [uid] let the service report usage to the shared night log
  /// while the app is closed.
  /// [graceMin] and [blockMin] are the night-mode times agreed in the pact.
  static Future<void> saveConfig({
    required bool enabled,
    required int bedtimeMin,
    required int wakeMin,
    int graceMin = SleepWindow.defaultGrace,
    int blockMin = SleepWindow.defaultPause,
    String? pairId,
    String? uid,
    String? partnerName,
  }) =>
      _channel.invokeMethod<void>('saveConfig', {
        'pairId': pairId,
        'uid': uid,
        'partnerName': partnerName,
        'enabled': enabled,
        'bedtimeMin': bedtimeMin,
        'wakeMin': wakeMin,
        'graceMin': graceMin,
        'blockMin': blockMin,
      });

  static Future<BlockStats?> getStats() async {
    final m = await _channel.invokeMethod<Map<Object?, Object?>>('getStats');
    return m == null ? null : BlockStats.fromMap(m);
  }
}
