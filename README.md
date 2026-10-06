# GoodNight 🌙

A mutual sleep pact for two. Each person proposes their own bedtime, the partner approves it, and it locks.
Night mode limits Instagram (app and Chrome) and YouTube Shorts, the alarm gets harder with every snooze,
and a shared streak earns single-use, no-questions-asked coupons.

Android only. Built with Flutter, with small native Kotlin parts for blocking, and Firebase for sync.

## Install (Android)
1. Open the [latest release](https://github.com/Its-Abishek-01/goodnight/releases/latest) on your phone and download the `.apk`.
2. Open it and allow "Install unknown apps" for your browser when asked. If Play Protect warns about an unrecognised app, choose "Install anyway".
3. On Android 13 or later, GoodNight needs the Accessibility permission for night-mode blocking. If it is greyed out, open Settings > Apps > GoodNight, tap the three-dot menu and choose **Allow restricted settings**, then enable it.

Both of you need the app installed. One creates a pair code and the other joins with it.

### Privacy
The released app syncs through a shared Firebase project. It stores only your name, your pair, bedtimes, check-ins and coupons. It never reads message content or keeps browsing history, and during night mode it only checks which app or website is in front. To keep your data fully yours, build from source with your own Firebase project (below).

## Setup from source (bring your own Firebase)
1. Create a Firebase project and add an Android app with package `com.wiozen.goodnight`.
2. Download `google-services.json` into `android/app/` (see `google-services.json.example`). It is git-ignored.
3. Enable Authentication (Anonymous), Firestore and Cloud Messaging.
4. `flutter pub get && flutter run`

## Status
Pairing and bedtime approval work. Alarm, blocking, streaks and coupons are in progress. See `docs/PLAN.md`.
Maintainers: see `docs/RELEASING.md`.

## License
MIT
