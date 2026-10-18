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

## Next
- ⏳ Install v0.2.2 by hand once on both phones (phone 1 needs an uninstall and a new pairing, since it has a debug build); from then on updates arrive in-app
- ⏳ Try love notes and the partner card on the two phones
- ⏳ Check on a real phone that an in-app update is not blocked by Play Protect (it is an update of an installed app, which should be allowed)
- ⏳ Maybe: a lite APK without night mode (no Accessibility service, so browser installs work anywhere) in every GitHub release
- ⏳ Maybe: announcement popups (a message without a new build)
- ⏳ Deploy the Cloud Functions (`docs/PUSH.md`) and check push on two phones
- ⏳ Maybe: block/report

## Later
- ⏳ Make grace and block durations configurable per couple, locked at pairing
- ⏳ Photo-of-object alarm challenge
- ⏳ Rules tests with the Firebase emulator, and a CI job for analyze and tests

## Known risks
- Play Protect blocks installing the GitHub APK from a browser in India (enhanced fraud protection, because of the Accessibility service). Ways around it: `adb install`, turning off Play Protect scanning for the install, or a future lite APK. Later updates come in-app.
- Website and Shorts detection depends on third-party view ids that can change.
- Some phone brands kill background services; the Setup tab asks for battery exemptions.
- Streak and coupon integrity relies on honest partners (no server check).
