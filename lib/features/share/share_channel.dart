import 'package:flutter/services.dart';

/// Bridge to the native side of Watch together (`ShareChannel.kt`): the
/// foreground service that keeps sharing alive in other apps, the phone's
/// sound, and reactions floating over other apps.
class ShareNative {
  static const _channel = MethodChannel('com.wiozen.goodnight/share');

  /// Called with "stop" or "mic" when the notification's buttons are tapped.
  static void setActionHandler(void Function(String action) onAction) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'action') onAction(call.arguments as String? ?? '');
    });
  }

  static Future<void> startService(String partner) =>
      _channel.invokeMethod<void>('startService', {'partner': partner});

  static Future<void> stopService() =>
      _channel.invokeMethod<void>('stopService');

  /// Starts mixing the phone's sound into the call. False when this phone
  /// cannot (older than Android 10, or no microphone permission).
  static Future<bool> startSound() async =>
      await _channel.invokeMethod<bool>('startSound') ?? false;

  /// The sharer's voice, on top of the phone's sound.
  static Future<void> setMic(bool on) =>
      _channel.invokeMethod<void>('setMic', {'on': on});

  /// A reaction from the viewer, shown over whatever app the sharer is in.
  static Future<void> reaction(String emoji) =>
      _channel.invokeMethod<void>('reaction', {'emoji': emoji});
}
