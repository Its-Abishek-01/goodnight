import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app_update.dart';

/// Checks GitHub Releases for a newer APK, downloads it and hands it to the
/// Android installer (native side in MainActivity.kt).
class Updater {
  static const _channel = MethodChannel('com.wiozen.goodnight/updater');

  static const latestUrl =
      'https://api.github.com/repos/Its-Abishek-01/goodnight/releases/latest';
  static const releasesPage = 'https://github.com/Its-Abishek-01/goodnight/releases/latest';

  /// The installed versionName, e.g. `0.2.1`.
  static Future<String> installedVersion() async =>
      await _channel.invokeMethod<String>('appVersion') ?? '';

  /// The latest published (non-draft, non-prerelease) release, or null.
  static Future<AppRelease?> fetchLatest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(latestUrl));
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      req.headers.set(HttpHeaders.userAgentHeader, 'GoodNight-app');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        await res.drain<void>();
        return null;
      }
      final body = await res.transform(utf8.decoder).join();
      return AppRelease.fromGitHub(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }

  /// Downloads the APK into the cache (`updates/`, shared through the
  /// FileProvider). A finished download of the same size is reused.
  static Future<File> download(
    AppRelease release, {
    required void Function(double progress) onProgress,
  }) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    await dir.create(recursive: true);
    final file = File('${dir.path}/goodnight-${release.tag}.apk');
    if (await file.exists() && release.apkSize > 0 && await file.length() == release.apkSize) {
      onProgress(1);
      return file;
    }
    // Only the newest APK is kept.
    await for (final old in dir.list()) {
      if (old is File) await old.delete();
    }

    final part = File('${file.path}.part');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(release.apkUrl));
      req.headers.set(HttpHeaders.userAgentHeader, 'GoodNight-app');
      final res = await req.close();
      if (res.statusCode != 200) {
        await res.drain<void>();
        throw HttpException('Download failed (${res.statusCode})');
      }
      final total = res.contentLength > 0 ? res.contentLength : release.apkSize;
      final sink = part.openWrite();
      var got = 0;
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) onProgress((got / total).clamp(0, 1).toDouble());
        }
      } finally {
        await sink.close();
      }
      if (release.apkSize > 0 && got != release.apkSize) {
        await part.delete();
        throw const HttpException('Download was incomplete');
      }
      return await part.rename(file.path);
    } finally {
      client.close();
    }
  }

  /// Whether Android lets GoodNight install apps ("Install unknown apps").
  static Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;

  /// Opens the "Install unknown apps" switch for GoodNight.
  static Future<void> openInstallSettings() =>
      _channel.invokeMethod<void>('openInstallSettings');

  /// Shows the Android installer for [apk].
  static Future<void> install(File apk) =>
      _channel.invokeMethod<void>('install', {'path': apk.path});
}
