# GoodNight 🌙

A mutual sleep pact for two. Each person proposes their own bedtime, the partner approves it, and it locks.
Night mode limits Instagram (app and Chrome) and YouTube Shorts, the alarm gets harder with every snooze,
and a shared streak earns single-use, no-questions-asked coupons.

Android only. Built with Flutter, with small native Kotlin parts for blocking, and Firebase for sync.

## Setup (bring your own Firebase)
1. Create a Firebase project and add an Android app with package `com.wiozen.goodnight`.
2. Download `google-services.json` into `android/app/` (see `google-services.json.example`). It is git-ignored.
3. Enable Authentication (Anonymous), Firestore and Cloud Messaging.
4. `flutter pub get && flutter run`

## Status
Foundation only. See `docs/PLAN.md`.

## License
MIT
