import 'dart:io';
import 'dart:typed_data';

import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

/// Pushes the latest selfie from the partner to the Android home-screen
/// widget (`SelfieWidgetProvider` in the native app).
class SelfieHomeWidget {
  static const _androidName = 'SelfieWidgetProvider';

  static Future<void> update({
    required Uint8List bytes,
    required String caption,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/partner_selfie.jpg');
    await file.writeAsBytes(bytes, flush: true);
    await HomeWidget.saveWidgetData<String>('selfie_path', file.path);
    await HomeWidget.saveWidgetData<String>('selfie_caption', caption);
    await HomeWidget.updateWidget(androidName: _androidName);
  }

  /// Empties the widget, for example after the data is deleted.
  static Future<void> clear() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/partner_selfie.jpg');
    if (await file.exists()) await file.delete();
    await HomeWidget.saveWidgetData<String>('selfie_path', null);
    await HomeWidget.saveWidgetData<String>('selfie_caption', null);
    await HomeWidget.updateWidget(androidName: _androidName);
  }
}
