import 'package:flutter/services.dart';

class BlockStats {
  const BlockStats({
    required this.nightKey,
    required this.blocks,
    required this.usageMinutes,
    required this.prevKey,
    required this.prevBlocks,
    required this.prevUsageMinutes,
  });

  final String nightKey;
  final int blocks;
  final int usageMinutes;
  final String prevKey;
  final int prevBlocks;
  final int prevUsageMinutes;

  factory BlockStats.fromMap(Map<Object?, Object?> m) => BlockStats(
        nightKey: m['nightKey'] as String? ?? '',
        blocks: (m['blocks'] as num?)?.toInt() ?? 0,
        usageMinutes: (m['usageMinutes'] as num?)?.toInt() ?? 0,
        prevKey: m['prevKey'] as String? ?? '',
        prevBlocks: (m['prevBlocks'] as num?)?.toInt() ?? 0,
        prevUsageMinutes: (m['prevUsageMinutes'] as num?)?.toInt() ?? 0,
      );
}

/// Bridge to the native accessibility service that does the blocking.
class Blocker {
  static const _channel = MethodChannel('com.wiozen.goodnight/blocker');

  /// Agreed in the pact: 5 minutes of grace, then a 10 minute block.
  static const graceMinutes = 5;
  static const blockMinutes = 10;

  static Future<bool> isServiceEnabled() async =>
      await _channel.invokeMethod<bool>('isServiceEnabled') ?? false;

  static Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod<void>('openAccessibilitySettings');

  /// Opens App info, where Android 13+ hides "Allow restricted settings".
  static Future<void> openAppDetails() =>
      _channel.invokeMethod<void>('openAppDetails');

  static Future<void> saveConfig({
    required bool enabled,
    required int bedtimeMin,
    required int wakeMin,
  }) =>
      _channel.invokeMethod<void>('saveConfig', {
        'enabled': enabled,
        'bedtimeMin': bedtimeMin,
        'wakeMin': wakeMin,
        'graceMin': graceMinutes,
        'blockMin': blockMinutes,
      });

  static Future<BlockStats?> getStats() async {
    final m = await _channel.invokeMethod<Map<Object?, Object?>>('getStats');
    return m == null ? null : BlockStats.fromMap(m);
  }
}
