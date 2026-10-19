# Roadmap and progress

Legend: ✅ done · 🔧 needs real-device testing · ⏳ to do

## Done
- ✅ Flutter project, Firebase wiring, anonymous sign-in
- ✅ Pairing with a single-use 6-character code
- ✅ Own bedtime and wake time, partner approval, locking, change requests
- ✅ Smart alarm: escalating volume and challenges (tap, maths, typing, QR), verify alarm
- ✅ Night-mode blocking engine (5 min grace, 10 min block) with unit tests 🔧
- ✅ Instagram app, browser Instagram and YouTube Shorts detection 🔧
- ✅ Check-in, partner status, snooze nudge, bedtime and wrap-up reminders
- ✅ Shared streak, weekly report, weekly mutual forgiveness
- ✅ Streak coupons: single use, no questions asked, deleted when confirmed
- ✅ Moments: selfies with read receipts and a home-screen widget 🔧
- ✅ Release workflow (tag -> signed APK -> GitHub Release), README, privacy notes
- ✅ Release keystore, GitHub secrets and Firebase API key restriction, Blaze plan, repo public, Firestore rules deployed
- ✅ Feature picker: personal (alarm, night mode, reminders) and shared with approval (streak & coupons, Moments) 🔧
- ✅ v0.1.0 tagged and released on GitHub
- ✅ Play Store groundwork: privacy policy, in-app data deletion, checklist in `docs/PLAY_STORE.md` (Play dropped on 2026-10-18; GitHub only)

## v0.2.1
- ✅ Golden crescent-heart icon everywhere, store graphics and rendered screenshots
- ✅ Redesign: journey to the moon, per-person colours, cute animated bottom bar with a moon button
- ✅ Profiles: own photo and name, private pet name and photo for your partner (Us tab)
- ✅ Whole app follows the time of day (night, dawn, day, dusk sky; long-press the logo to preview)
- ✅ Firestore rules deployed (features, deletion, profiles, nicknames)
- ✅ Play app signing key uploaded (own key, so Play and GitHub builds match)
- ✅ Tested on two real vivo phones over adb

## v0.2.2
- ✅ Love notes: a short message that fills the partner's screen, with a read receipt (the "goodnight hug" idea; shows in-app instantly, push when Functions are deployed) 🔧
- ✅ Live partner card on Tonight and a richer weekly report 🔧
- ✅ In-app updates from GitHub Releases: checks on launch/resume, downloads the APK, opens the installer; `<!-- required -->` in the notes forces it 🔧
- ✅ Clearer night-mode disclosure
- ✅ Google Play dropped; releases ship the APK only
- ✅ Firestore rules deployed (love notes)

## v0.2.3
- ✅ v0.2.2 installed on both phones from GitHub, paired again; night-mode blocking confirmed working
- ✅ Cloud Functions deployed (asia-south1), including love-note and night-mode alerts
- ✅ Night-mode service reports minutes and blocks live to the night log (REST, works with the app closed) 🔧

## v0.2.4
- ✅ Love-letter loading animation everywhere (no spinners)
- ✅ Waiting screen centred, with a QR code; "Scan your partner's code" to join 🔧
- ✅ "Going to sleep" home-screen widget with both of you and a check-in button; `statusAlert` (deployed) keeps it fresh while the app is closed 🔧

## v0.2.5
- ✅ "Alerts about {partner}": each person picks after how many minutes of phone use past the partner's bedtime they get a push (Off/5/10/15/30/60, default 15) 🔧
- ✅ Night mode counts any phone use after bedtime (screen on and unlocked, not the home screen, GoodNight or calls)
- ✅ Partner pushes pop up on screen (high-importance channel)
- ✅ Night mode times agreed with the partner (grace 3/5/10/15, pause 10/15/20/30), approved with the bedtime 🔧
- ✅ Ask for +5/+10/+15 min from the pause screen (max 3 a night); partner answers on Tonight; the service polls and unlocks 🔧
- ✅ Rules and functions deployed (alertAfter, night times, timeRequests)

## Next
- ⏳ Update both phones through the in-app "Update ready" sheet (first real test of the updater, including whether Play Protect allows it)
- ⏳ Try love notes and the partner card on the two phones
- ⏳ Maybe: a lite APK without night mode (no Accessibility service, so browser installs work anywhere) in every GitHub release
- ⏳ Maybe: announcement popups (a message without a new build)
- ⏳ Check push on two phones: love note with the app closed, scrolling after bedtime, a block
- ⏳ Maybe: block/report

## Later
- ⏳ Photo-of-object alarm challenge
- ⏳ Rules tests with the Firebase emulator, and a CI job for analyze and tests

## Known risks
- Play Protect blocks installing the GitHub APK from a browser in India (enhanced fraud protection, because of the Accessibility service). Ways around it: `adb install`, turning off Play Protect scanning for the install, or a future lite APK. Later updates come in-app.
- Website and Shorts detection depends on third-party view ids that can change.
- Some phone brands kill background services; the Setup tab asks for battery exemptions.
- Streak and coupon integrity relies on honest partners (no server check).
