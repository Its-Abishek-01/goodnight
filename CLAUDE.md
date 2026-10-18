# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

GoodNight is an Android-only Flutter app for two people (a couple) who make a mutual sleep pact. Package `com.wiozen.goodnight`, Firebase project `goodnight-27157`. The repo is public and releases ship as APKs on GitHub Releases. See `README.md` for the user-facing feature list and `docs/RELEASING.md` for releasing.

Project docs: `docs/ARCHITECTURE.md` (diagram and data flows), `docs/ROADMAP.md` (done / next / later; keep it updated when finishing work), `CHANGELOG.md` (add an entry under Unreleased for user-visible changes).

## Commands
```bash
flutter pub get
flutter analyze                       # must stay clean; the release workflow runs it
flutter test                          # all Dart tests
flutter test test/streak_test.dart    # one file
flutter test --plain-name "forgiven"  # one test by name
cd android && ./gradlew :app:testDebugUnitTest   # Kotlin tests (BlockEngine)
flutter build apk --debug             # first build is slow (~8 min)
flutter build apk --release           # falls back to the debug key without android/key.properties
```
- On Windows use the Bash tool; a long single bash script with heredocs and apostrophes can fail to parse, so prefer the Write tool for files.
- There is no emulator or device on the dev machine, so UI and the accessibility service have never been run for real. Logic that can be tested is kept in pure Dart/Kotlin for that reason.
- Pinned dependency: `permission_handler` must stay `^12` (v13 needs AGP 9; the project is on AGP 8.11). `alarm` resolves to 4.1.x.

## Secrets and config
- `android/app/google-services.json` is git-ignored (CI writes it from the `GOOGLE_SERVICES_JSON` secret). `google-services.json.example` is the scrubbed template. Release signing reads `android/key.properties` (also ignored).
- `firestore.rules` is not deployed automatically. After any change to it, the user must paste it into the Firebase console. Rules are untested against a live project.
- Releases: pushing a `v*` tag runs `.github/workflows/release.yml` (analyze, test, signed APK, `gh release create`). Nothing builds on normal commits.

## Architecture
Flutter UI with Riverpod, Firebase (anonymous auth, Firestore) as the only backend, and one native Kotlin accessibility service. Features live in `lib/features/<name>/`; `lib/core/` has the app gate, Firebase providers and notifications.

**Routing is a state gate** in `lib/core/app.dart` (`_Gate`): ringing alarm -> `AlarmRingScreen`, else not signed in/loading -> spinner, no pair -> `PairingScreen`, waiting -> `WaitingScreen`, active -> `HomeScreen` (tabs: Tonight, Report, Coupons, Setup). `HomeScreen` is also where all background "sync" providers are activated by `ref.watch`.

**Firestore model** (all under `pairs/{pairId}` unless noted; `firestore.rules` encodes who may write what):
- `users/{uid}`: name, pairId, fcmToken. `pairCodes/{code}`: single-use join code.
- `profiles/{uid}`: that person's photo (blob, under 200 KB), readable by both. `nicknames/{uid}`: the pet name and photo uid gave their partner, readable only by uid (so `deletePair` deletes it by id rather than listing). `peopleProvider` resolves what to show for each member.
- The pair doc itself holds `members`, `names.{uid}`, `colors.{uid}` (a `PartnerColor` name; `Pair.colorOf` defaults to sky for the creator, rose for the partner), `status` and `closing`.
- `schedules/{ownerUid}`: `current` (approved, locked window) + `proposal` (pending, with `by`). Only the person who did NOT propose can approve. A change proposal leaves `current` active until approved.
- `nights/{nightKey}`: `players.{uid}` = checkedInAt, wokeAt, snoozes, blocks, usageMinutes; plus `forgiveBy`/`forgiven`. Each person writes only their own player entry.
- `grants/{startKey_milestone}` (tombstone so a coupon is earned once) and `coupons/{grantId_uid}` (holder, status ready/redeemed).
- `features/{uid}`: that person's own choices (alarm, nightMode, reminders). `features/shared`: `current` + `proposal` for streak and moments, approved like schedules. A missing doc or field means on.

**Night key**: a night is keyed by the date of `now - 12h` (`nightKey()` in `checkin/night_log.dart`), so 23:00 on D and 07:00 on D+1 are both night D. The Kotlin side has the identical `nightKeyOf` in `BlockEngine.kt`; keep the two in sync.

**Features** (`features/settings/`): sync providers read `myFeaturesProvider`, which is null until loaded so nothing acts on the defaults. `HomeScreen` hides the Moments/Coupons tabs and their sync providers when the shared feature is off.

**Streak and coupons** are computed client-side. `streak/streak.dart` is pure: a night is good only if both people checked in within 15 min after bedtime (up to 4h early) and woke with at most 3 snoozes; forgiven nights keep a streak alive without adding to it. A person who checked in with the alarm off (`players.{uid}.alarm == false`, saved at check-in so later toggles cannot rewrite old nights) is judged on bedtime only. `couponSyncProvider` grants coupons at milestones 7/14/30/60 using `startKey_milestone` ids.

**Alarm** (`features/alarm/`): wraps the `alarm` package. Ids 1001 wake, 1002 snooze, 1003 verify (`AlarmScheduler`). `RingNotifier` surfaces the ringing id to the gate. Challenge difficulty is `challengeFor(snoozeCount)` (tap, math, type, QR; QR falls back to type if no QR is set up). Snooze count and the night key persist in SharedPreferences (`AlarmPrefs`). `alarmSyncProvider` reschedules the wake alarm whenever the approved schedule changes.

**Blocking** is native and independent of the Flutter engine:
- `BlockerService.kt` (AccessibilityService, declared in the manifest, config in `res/xml/accessibility_service_config.xml`) tracks the foreground package, reads browser URL bars and detects YouTube Shorts view ids (`Targets.kt`), ticks every 5s, and on a block does `GLOBAL_ACTION_HOME` plus a full-screen accessibility overlay.
- `BlockEngine.kt` is the pure grace/block state machine (shared 5 min grace across Instagram/browser Instagram/Shorts, then 10 min block). It is the unit-tested part (`android/app/src/test`).
- Flutter talks to it over the `com.wiozen.goodnight/blocker` MethodChannel (`MainActivity.kt`, `features/blocking/blocker_channel.dart`). Config (approved bedtime/wake, plus pairId and uid) is pushed by `blockerSyncProvider`.
- `NightReporter.kt` writes tonight's `usageMinutes`/`blocks` (and a server `usageAt`) to the night log live, whenever they grow (`NightReport.shouldReport`, tested), so it works with the app closed. It uses the Firestore REST `commit` endpoint with the native FirebaseAuth ID token, not the Firestore SDK: FlutterFire calls `setFirestoreSettings` on the shared SDK instance at startup, which throws once native code has used it. `syncBlockStats` still uploads on open/resume as a catch-up (without `usageAt`). `nightModeAlert` in `functions/index.js` pushes to the partner only for writes that change `usageAt`. The detection of Chrome/Shorts depends on third-party view ids and may need updating when those apps change.

**In-app updates** (`features/update/`): `updateProvider` (watched by the gate, so it runs from launch) asks the GitHub `releases/latest` API on launch and resume (at most every 3 h, never in debug builds) and offers a release whose tag is newer than the installed versionName. `Updater` downloads the `.apk` asset into `cache/updates/` and hands it to the installer over the `com.wiozen.goodnight/updater` MethodChannel (`MainActivity.kt`, FileProvider `${applicationId}.updates`, `REQUEST_INSTALL_PACKAGES`). `<!-- required -->` in the release notes makes the gate show `UpdateRequiredScreen`. Version compare, snooze and highlight parsing are pure in `app_update.dart` and tested. Release notes come from the version's CHANGELOG section (release.yml). Google Play was dropped; releases ship the APK only.

**Notifications**: local reminders (wrap-up call 30 min before bedtime, bedtime) via `core/notifications.dart`. Partner push: `features/push` saves the FCM token; `functions/index.js` (deployed to `asia-south1`, keep `setGlobalOptions` region) sends the alerts. See `docs/PUSH.md`.

**Going to sleep widget** (`features/sleep_widget/`): `sleepWidgetSyncProvider` (watched by `HomeScreen`) writes both people's lines and the button state through `home_widget`; native side is `SleepWidgetProvider.kt` (layout `res/layout/sleep_widget.xml`). The button opens the app with `goodnight://checkin` (home_widget launch intent) and `HomeScreen` checks in via `checkInFromWidget`. The texts and `checkInOpenAt` (also used by the Tonight button) are pure in `sleep_widget_content.dart` and tested. While the app is closed, `statusAlert` sends a data push on check-in/wake and `goodnightBackgroundHandler` rewrites the partner line. Colours are saved as signed 32-bit ints so Android reads them with `getInt`.

**Loading**: use `CuteLoader` (`core/widgets/cute_loader.dart`, two love letters meeting), never `CircularProgressIndicator`. Determinate progress (the update download) may use a progress bar.

**Pairing by QR**: the waiting screen shows `PairRepository.pairQrData(code)` (`goodnight:pair:CODE`); `ScanCodeScreen` reads it back with `codeFromQr`, which also accepts a bare code.

**Moments (selfies)** (`features/selfie/`): the compressed JPEG lives in the Firestore doc (`selfies/{id}.image` blob, rules cap it at 800 KB), not Firebase Storage. Only the receiver can set `seenAt` (the read receipt). `selfieSyncProvider` writes the partner's latest photo to a file and calls `home_widget`; native side is `SelfieWidgetProvider.kt` (layout `res/layout/selfie_widget.xml`). A data-only FCM push from `selfieAlert` runs `goodnightBackgroundHandler` so the widget updates while the app is closed. Own selfies older than 7 days are deleted client-side.

**Love notes** (`features/lovenote/`): a short text message (`loveNotes/{id}`, rules cap `text` at 200 chars) one partner sends the other. Only the receiver can set `seenAt` (the read receipt), mirroring selfies. `LoveNoteInbox` (a `Notifier`) watches `loveNotesProvider` and latches the newest unseen incoming note into state; the gate in `app.dart` shows `LoveNoteScreen` full-screen for it (after the ringing-alarm and pairing checks), and seeing it marks it seen. `LoveNoteButton` on Tonight opens the composer and shows the last-sent note's receipt. `loveNoteAlert`/`loveNoteSeenAlert` send ordinary (not data-only) FCM pushes, so no background handler is needed. Pure helpers (`loveNoteError`, `latestIncomingUnseen`, `expiredOwnNotes`) are unit-tested in `test/love_note_test.dart`; own notes older than 7 days are deleted client-side.

Grace/block durations are constants in `Blocker` (Dart); they are not yet configurable per couple.

**Data deletion**: `PairRepository.deletePair` marks the pair `closing`, deletes every collection in `pairCollections` in small batches, then the pair, join code and user doc; the rules allow those deletes only while the pair is closing. Add any new pair subcollection to `pairCollections` and give it a `closingByMember` delete rule. The gate shows `_Closing` for a closing pair.

**Bottom bar**: `core/widgets/moon_nav_bar.dart` with Tonight as the raised moon; icons are painted in `core/widgets/cute_icons.dart` (32x32 space, `keyframe` tracks drive the tap animations).

**Look and feel**: the app follows the time of day. `core/theme.dart` has `SkyPhase` (`skyPhaseAt`: night 21-05, dawn 05-08, day 08-17, dusk 17-21), the `SkyColors` theme extension (read with `context.sky`; never hard-code colours, they must work on both the light and dark palettes) and `buildTheme(phase)`. `skyPhaseProvider` (`core/sky_phase.dart`) ticks every minute; long-pressing the app-bar logo cycles a preview. `core/widgets/living_sky.dart` is painted behind every screen by `MaterialApp.builder`, so scaffolds are transparent. The Tonight centrepiece is `checkin/moon_journey.dart`; its position and caption logic (`stageOf`, `journeyT`, `journeyCaption`) is pure and tested.

**Icons and store graphics** all come from `store/icon-source.png`: `python scripts/make-icons.py` writes the launcher/adaptive/monochrome icons, `ic_notification` (used by local notifications, the alarm and FCM), the splash, `assets/logo.png` and the Play icon and feature graphic. Store screenshots are rendered from the real widgets with fake providers: `SCREENSHOTS=1 flutter test test/store_screenshots_test.dart` (skipped in normal runs).

See also `docs/NEW_MACHINE.md` for setting up on a fresh computer, `docs/PLAY_STORE.md` for Google Play (dropped, kept for reference), and `docs/privacy-policy.md` (published on GitHub Pages; keep it in step with what the app stores).
