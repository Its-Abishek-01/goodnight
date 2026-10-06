// Renders real app screens with sample data into Play Store screenshots.
// Skipped in normal test runs. To regenerate store/screenshots/*.png:
//   SCREENSHOTS=1 flutter test test/store_screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/core/firebase_providers.dart';
import 'package:goodnight/core/theme.dart';
import 'package:goodnight/core/widgets/starry_sky.dart';
import 'package:goodnight/features/alarm/alarm_providers.dart';
import 'package:goodnight/features/bedtime/schedule.dart';
import 'package:goodnight/features/bedtime/schedule_providers.dart';
import 'package:goodnight/features/blocking/blocker_providers.dart';
import 'package:goodnight/features/checkin/night_log.dart';
import 'package:goodnight/features/checkin/night_providers.dart';
import 'package:goodnight/features/coupons/coupon.dart';
import 'package:goodnight/features/coupons/coupon_providers.dart';
import 'package:goodnight/features/pairing/home_screen.dart';
import 'package:goodnight/features/pairing/pair.dart';
import 'package:goodnight/features/pairing/pair_providers.dart';
import 'package:goodnight/features/pairing/pairing_screen.dart';
import 'package:goodnight/features/profile/profile.dart';
import 'package:goodnight/features/push/push_providers.dart';
import 'package:goodnight/features/reminders/reminder_providers.dart';
import 'package:goodnight/features/selfie/selfie.dart';
import 'package:goodnight/features/selfie/selfie_providers.dart';
import 'package:goodnight/features/settings/features.dart';
import 'package:goodnight/features/settings/features_providers.dart';

/// Repositories are constructed with a db but never called in these scenes.
class _NoDb implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _me = 'me';
const _partner = 'partner';
const _pair = Pair(
  id: 'pair',
  code: '',
  members: [_me, _partner],
  names: {_me: 'Sam', _partner: 'Alex'},
  status: PairStatus.active,
  colors: {_me: 'sky', _partner: 'rose'},
);

// 1080x1920 portrait, a common Android phone size.
const _dpr = 2.625;
const _size = Size(1080 / _dpr, 1920 / _dpr);

Future<void> _loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final fonts = '$sdk/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String path) async => ByteData.view((await File(path).readAsBytes()).buffer);

  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-regular', 'roboto-medium', 'roboto-bold']) {
    roboto.addFont(read('$fonts/$f.ttf'));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('$fonts/materialicons-regular.otf'))).load();
  const emoji = 'C:/Windows/Fonts/seguiemj.ttf';
  if (File(emoji).existsSync()) {
    await (FontLoader('Emoji')..addFont(read(emoji))).load();
  }
}

/// Bedtime one hour from now, so tonight's check-in button is open.
SleepWindow _window(int offsetMinutes) {
  final now = DateTime.now();
  final bed = ((now.hour * 60 + now.minute + 60 + offsetMinutes) ~/ 15 * 15) % 1440;
  return SleepWindow(bedtime: bed, wake: (bed + 8 * 60) % 1440);
}

DateTime _at(String key, int minuteOfDay, {int dayShift = 0}) {
  final d = DateTime.parse(key);
  // A bedtime before noon belongs to the early hours after night [key].
  final shift = minuteOfDay < 12 * 60 ? 1 : 0;
  return DateTime(d.year, d.month, d.day + shift + dayShift, minuteOfDay ~/ 60, minuteOfDay % 60);
}

List<Night> _nights(Map<String, SleepWindow> w, {bool together = false}) {
  final today = nightKey(DateTime.now());
  PlayerNight good(String key, SleepWindow s, int early, int snoozes) => PlayerNight(
        checkedInAt: _at(key, s.bedtime).subtract(Duration(minutes: early)),
        wokeAt: _at(key, s.wake, dayShift: s.wake < s.bedtime && s.bedtime >= 12 * 60 ? 1 : 0)
            .add(Duration(minutes: 4 * snoozes + 2)),
        snoozes: snoozes,
        blocks: (early + snoozes) % 3,
        usageMinutes: 3 + (early % 4),
      );
  final out = <Night>[
    Night(key: today, players: {
      _partner: PlayerNight(checkedInAt: DateTime.now().subtract(const Duration(minutes: 12))),
      if (together) _me: PlayerNight(checkedInAt: DateTime.now().subtract(const Duration(minutes: 2))),
    }),
  ];
  var key = today;
  for (var i = 0; i < 9; i++) {
    key = _prev(key);
    out.add(Night(key: key, players: {
      _me: good(key, w[_me]!, 5 + i % 3 * 4, i % 3 == 0 ? 1 : 0),
      _partner: good(key, w[_partner]!, 10 + i % 4 * 3, i % 4 == 1 ? 2 : 0),
    }));
  }
  return out;
}

String _prev(String key) {
  final d = DateTime.parse(key);
  return formatNightKey(DateTime(d.year, d.month, d.day - 1));
}

Widget _app(Widget home, {bool together = false}) {
  final windows = {_me: _window(0), _partner: _window(-30)};
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(_NoDb()),
      uidProvider.overrideWith((ref) async => _me),
      pairProvider.overrideWith((ref) => Stream.value(_pair)),
      schedulesProvider.overrideWith((ref) => Stream.value({
            for (final e in windows.entries) e.key: Schedule(owner: e.key, current: e.value),
          })),
      nightsProvider.overrideWith((ref) => Stream.value(_nights(windows, together: together))),
      couponsProvider.overrideWith((ref) => Stream.value(const [
            Coupon(id: 'c1', holder: _me, milestone: 7, status: CouponStatus.ready),
            Coupon(
              id: 'c2',
              holder: _partner,
              milestone: 7,
              status: CouponStatus.redeemed,
              title: "Pick tonight's movie 🎬",
            ),
          ])),
      selfiesProvider.overrideWith((ref) => Stream.value(const <Selfie>[])),
      profilePhotosProvider.overrideWith((ref) => Stream.value(const {})),
      nicknameProvider.overrideWith((ref) => Stream.value(Nickname.none)),
      personalFeaturesProvider.overrideWith((ref) => Stream.value(const {_me: PersonalFeatures.all})),
      sharedSettingsProvider.overrideWith((ref) => Stream.value(SharedSettings.initial)),
      alarmSyncProvider.overrideWith((ref) {}),
      blockerSyncProvider.overrideWith((ref) {}),
      reminderSyncProvider.overrideWith((ref) {}),
      pushSyncProvider.overrideWith((ref) {}),
      couponSyncProvider.overrideWith((ref) {}),
      selfieSyncProvider.overrideWith((ref) {}),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      // Same theme and sky as GoodNightApp, with the fonts loaded above.
      theme: _withFonts(buildTheme()),
      builder: (context, child) => StarrySky(child: child!),
      home: home,
    ),
  );
}

ThemeData _withFonts(ThemeData t) => t.copyWith(
      textTheme: t.textTheme.apply(fontFamily: 'Roboto', fontFamilyFallback: const ['Emoji']),
      primaryTextTheme:
          t.primaryTextTheme.apply(fontFamily: 'Roboto', fontFamilyFallback: const ['Emoji']),
    );

final _boundary = GlobalKey();

Future<void> _shoot(WidgetTester tester, String name) async {
  // Asset images decode asynchronously; load them before the capture.
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  // Let the moon journey animations finish.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(() async {
    final render = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: _dpr);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('store/screenshots/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _show(WidgetTester tester, Widget home, {bool together = false}) async {
  tester.view.physicalSize = _size * _dpr;
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(key: _boundary, child: _app(home, together: together)));
}

void main() {
  final enabled = Platform.environment['SCREENSHOTS'] == '1';

  setUpAll(() async {
    if (!enabled) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async => 1, // granted
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.wiozen.goodnight/blocker'),
      (call) async => call.method == 'isServiceEnabled' ? true : null,
    );
  });

  testWidgets('1 tonight', skip: !enabled, (tester) async {
    await _show(tester, const HomeScreen(pair: _pair, uid: _me));
    await _shoot(tester, '1-tonight');
  });

  testWidgets('1b together', skip: !enabled, (tester) async {
    await _show(tester, const HomeScreen(pair: _pair, uid: _me), together: true);
    await _shoot(tester, '1b-together');
  });

  testWidgets('2 report', skip: !enabled, (tester) async {
    await _show(tester, const HomeScreen(pair: _pair, uid: _me));
    await tester.pump();
    await tester.tap(find.text('Our week'));
    await _shoot(tester, '2-report');
  });

  testWidgets('3 coupons', skip: !enabled, (tester) async {
    await _show(tester, const HomeScreen(pair: _pair, uid: _me));
    await tester.pump();
    await tester.tap(find.text('Coupons'));
    await _shoot(tester, '3-coupons');
  });

  testWidgets('4 setup', skip: !enabled, (tester) async {
    await _show(tester, const HomeScreen(pair: _pair, uid: _me));
    await tester.pump();
    await tester.tap(find.text('Us'));
    await _shoot(tester, '4-setup');
  });

  testWidgets('5 pairing', skip: !enabled, (tester) async {
    await _show(tester, const PairingScreen());
    await _shoot(tester, '5-pairing');
  });
}
