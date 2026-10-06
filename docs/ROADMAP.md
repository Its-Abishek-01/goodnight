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
- ✅ Play Store groundwork: `.aab` builds, privacy policy, in-app data deletion, checklist in `docs/PLAY_STORE.md` 🔧

## v0.2.1
- ✅ Golden crescent-heart icon everywhere, store graphics and rendered screenshots
- ✅ Redesign: journey to the moon, per-person colours, cute animated bottom bar with a moon button
- ✅ Profiles: own photo and name, private pet name and photo for your partner (Us tab)
- ✅ Whole app follows the time of day (night, dawn, day, dusk sky; long-press the logo to preview)
- ✅ Firestore rules deployed (features, deletion, profiles, nicknames)
- ✅ Play app signing key uploaded (own key, so Play and GitHub builds match)
- ✅ Tested on two real vivo phones over adb

## Next
- ⏳ Upload the v0.2.1 `.aab` to the closed test track
- ⏳ Closed test: 12 testers for 14 days, then apply for production and open testing (`store/play-console-answers.md` has every form answer)
- ⏳ Deploy the Cloud Functions (`docs/PUSH.md`) and check push on two phones
- ⏳ Maybe: block/report, a "send a goodnight hug" button (needs push)

## Later
- ⏳ Make grace and block durations configurable per couple, locked at pairing
- ⏳ Photo-of-object alarm challenge
- ⏳ Rules tests with the Firebase emulator, and a CI job for analyze and tests

## Known risks
- Play Protect blocks installing the GitHub APK from a browser in India (enhanced fraud protection, because of the Accessibility service). Play Store or `adb install` are the ways around it.
- Website and Shorts detection depends on third-party view ids that can change.
- Some phone brands kill background services; the Setup tab asks for battery exemptions.
- Streak and coupon integrity relies on honest partners (no server check).
