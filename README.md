# GoodNight 🌙

A mutual sleep pact for two people. You agree on each other's bedtimes, night mode
pauses Instagram and YouTube Shorts after a short grace time, the morning alarm gets
louder and harder with every snooze, and a shared streak earns single-use,
no-questions-asked coupons for each other.

Android only. Built with Flutter, with a small native Kotlin accessibility service for
blocking, and Firebase for syncing the two phones.

## How it works
- **Pair up.** One of you creates a 6-character code, the other joins with it.
- **Bedtimes need approval.** You set your own bedtime and wake time. Your partner
  approves it (or suggests another), and then it locks. Changing it later needs their
  approval again, so neither of you can quietly loosen the rules.
- **Night mode.** During your approved bedtime hours you get 5 minutes of grace on
  Instagram (app or instagram.com in a browser) and YouTube Shorts combined. Then they
  are blocked for 10 minutes, and the grace starts fresh after that. Calls and
  WhatsApp are never touched.
- **Smart alarm.** Rings at your wake time. Each snooze is louder and the challenge is
  harder: tap, then maths, then typing a sentence, then scanning a QR code you stuck
  somewhere away from your bed. After you turn it off, a second alarm checks that you
  are really up.
- **Check-ins and reminders.** Tap "Going to sleep" near bedtime. You get a "wrap up
  the call" nudge 30 minutes before bedtime and a gentle reminder at bedtime. You can
  see whether your partner has checked in or is snoozing.
- **Streak and coupons.** A night counts when both of you check in on time and get
  up with at most 3 snoozes. 7, 14, 30 and 60 nights in a row earn each of you a
  coupon to use on the other. They cannot say no, and it is deleted once they confirm.
  Once a week you can ask to forgive a bad night, if your partner agrees.
- **Weekly report.** Last 7 nights for both of you.

## Install (Android)
1. Open the [latest release](https://github.com/Its-Abishek-01/goodnight/releases/latest) on your phone and download the `.apk`.
2. Open it and allow "Install unknown apps" for your browser when asked. If Play Protect warns about an unrecognised app, choose "Install anyway".
3. Open GoodNight and go to **Setup**. Allow notifications, exact alarms, running in the background and the camera.
4. Turn on **Night mode blocking**. On Android 13 or later, if the Accessibility switch is greyed out, open Settings > Apps > GoodNight, tap the three-dot menu, choose **Allow restricted settings**, then enable "GoodNight night mode" under Accessibility.
5. On phones from Xiaomi, Oppo, Vivo, Samsung and similar makers, also set GoodNight to "No restrictions" for battery, or the system may kill the alarm and blocker.

Both of you need the app. One creates a pair code and the other joins with it.

## Privacy
The released app syncs through a shared Firebase project. It stores only your name,
your pair, bedtimes, check-ins, snooze and block counts, and coupons. The Accessibility
service checks which app or website address is in front, only during your approved night
hours, to pause Instagram and Shorts. It never reads messages, passwords or what you
type, and it does not record browsing history. To keep all data under your own control,
build from source with your own Firebase project.

## Honest limitations
- **Detection is best effort.** Instagram, Chrome and YouTube change their screens in
  updates, which can break website and Shorts detection until it is updated here.
- **It only works if you both want it.** Either person can still uninstall the app or
  turn the permission off. That is why setup is mutual.
- **Push alerts are optional.** Without the Cloud Function you only see your partner's
  snoozes while the app is open. See [docs/PUSH.md](docs/PUSH.md).
- **Coupon and streak rules are enforced by the two apps and Firestore rules**, not by
  a server, so they rely on honest partners.
- Developed and unit tested, but real-device behaviour (especially blocking on
  different phone brands) still needs wider testing. Please open an issue.

## Setup from source (bring your own Firebase)
1. Create a Firebase project and add an Android app with package `com.wiozen.goodnight`.
2. Download `google-services.json` into `android/app/` (see `google-services.json.example`). It is git-ignored.
3. In the Firebase console enable **Authentication > Anonymous**, create a **Firestore** database, and paste [firestore.rules](firestore.rules) into its Rules tab.
4. `flutter pub get && flutter run`

Run the checks:
```bash
flutter analyze && flutter test
cd android && ./gradlew :app:testDebugUnitTest
```

## Project docs
[Architecture](docs/ARCHITECTURE.md) · [Roadmap and progress](docs/ROADMAP.md) · [Changelog](CHANGELOG.md) · [Push alerts](docs/PUSH.md)

## Releasing
See [docs/RELEASING.md](docs/RELEASING.md). Pushing a `v*` tag builds a signed APK and
publishes a GitHub Release.

## License
MIT
