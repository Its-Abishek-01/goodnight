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
- ✅ Release workflow (tag -> signed APK -> GitHub Release), README, privacy notes

## Next (before the first public release)
- ⏳ Test on two real Android phones (pairing, alarm, blocking, coupons)
- ⏳ Verify Firestore rules against the live project and fix any denied writes
- ⏳ Generate the release keystore and add the 5 GitHub secrets (`docs/RELEASING.md`)
- ⏳ Restrict the Firebase API key to the package and release SHA-1
- ⏳ Push local commits and tag `v0.1.0`

## Later
- ⏳ Make grace and block durations configurable per couple, locked at pairing
- ⏳ Photo-of-object alarm challenge
- ⏳ Deploy and test the optional push Cloud Function
- ⏳ App icon and splash screen
- ⏳ Play Store: closed test (12 testers, 14 days) and Accessibility declaration
- ⏳ Rules tests with the Firebase emulator, and a CI job for analyze and tests

## Known risks
- Website and Shorts detection depends on third-party view ids that can change.
- Some phone brands kill background services; the Setup tab asks for battery exemptions.
- Streak and coupon integrity relies on honest partners (no server check).
