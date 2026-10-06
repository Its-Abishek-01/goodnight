# Play Console: what to paste where

Everything for the GoodNight listing, in the order Play Console asks for it. Graphics are
in this folder: `icon-512.png`, `feature-graphic.png` and `screenshots/1-tonight.png` to
`5-pairing.png` (1080x1920). All of them come from `icon-source.png`
(`python scripts/make-icons.py`, then
`SCREENSHOTS=1 flutter test test/store_screenshots_test.dart`).

---

## 1. Store listing (Grow users > Store presence > Main store listing)

**App name** (max 30)
```
GoodNight: Sleep Pact for Two
```

**Short description** (max 80)
```
Agree on bedtimes with your partner, stop late-night scrolling, keep a streak.
```

**Full description** (max 4000)
```
GoodNight is a sleep pact for two people. You and your partner agree on each other's bedtimes, keep each other honest, and earn rewards for good nights together.

HOW IT WORKS
• Pair up: one of you creates a 6-character code, the other joins with it. No accounts or passwords.
• Bedtimes need approval: you set your own bedtime and wake time, your partner approves it, and then it locks. Changing it later needs their approval again.
• Check in: tap "Going to sleep" near bedtime and see whether your partner has checked in too.
• Night mode (optional): during your agreed bedtime you get 5 minutes of Instagram or YouTube Shorts, then they pause for 10 minutes. Calls and messaging apps are never touched.
• Smart alarm (optional): every snooze makes it louder and the challenge harder: tap, maths, typing, then scanning a QR code you stuck away from your bed. A second alarm checks you are really up.
• Streak and coupons: a night counts when you are both on time. 7, 14, 30 and 60 nights in a row earn each of you a single-use, no-questions-asked coupon for the other.
• Forgiveness: once a week you can ask to forgive a bad night, if your partner agrees.
• Weekly report: the last 7 nights for both of you.
• Moments (optional): send each other a selfie. Your partner's latest one shows on a home-screen widget, with a "Seen" receipt. Photos are private to the two of you and deleted after a week.

PICK WHAT YOU USE
Turn the alarm, night mode and reminders on or off for yourself. Streak & coupons and Moments are shared, so one of you proposes a change and the other approves it.

PRIVACY
No ads, no analytics, no tracking. Only you and your partner can see your data, and "Delete my data" in the app removes everything. Night mode uses Android's Accessibility service only to see which app is in front during your bedtime hours; it never reads messages, passwords or what you type.

GoodNight is open source: github.com/Its-Abishek-01/goodnight
```

**App icon:** `store/icon-512.png`
**Feature graphic:** `store/feature-graphic.png`
**Phone screenshots:** upload all five from `store/screenshots/`, in order:
`1-tonight`, `2-report`, `3-coupons`, `4-setup`, `5-pairing`.
Leave Video, Tablet, Desktop and Android XR empty.

**Store settings** (Grow users > Store presence > Store settings)
- App category: **Health & Fitness**
- Tags: Sleep, Couples / Relationships (pick the closest offered)
- Contact email: `abishek.mk.01@gmail.com`
- Website: `https://github.com/Its-Abishek-01/goodnight`

---

## 2. App content (Policy > App content)

**Privacy policy URL**
```
https://its-abishek-01.github.io/goodnight/privacy-policy
```

**Ads:** No, my app does not contain ads.

**Sign in details** (was "App access"): choose **Yes**. The form lists "QR codes" and
"actions to be carried out on another device", and GoodNight has both (pairing needs a
second phone; the hardest alarm challenge scans a QR code). Then click **Add instructions**:
- Password: leave empty.
- Any other information (max 500 characters). Without a reviewer code (428 chars):
```
No login: the app signs in anonymously. Pairing needs 2 devices: on one tap "Create a pair code", on the other tap "Join with code" and enter it. Set a bedtime on the Tonight tab; approve it on the other device. The QR code is an optional alarm challenge the app makes itself (Setup > Alarm QR code); without it the alarm uses typing. Night mode: Setup > Night mode blocking > Turn on > I agree, then enable it in Accessibility.
```
  With a code from a test phone left on the waiting screen (replace ABC123):
```
No login: the app signs in anonymously. Pairing needs 2 devices: on one tap "Create a pair code", on the other "Join with code". Or join our waiting test phone with code ABC123. Set a bedtime on the Tonight tab; the other device approves it. QR is an optional alarm challenge the app makes itself (Setup > Alarm QR code); without it the alarm uses typing. Night mode: Setup > Night mode blocking > Turn on > I agree, then enable in Accessibility.
```
- Tick "Sign in details in this declaration provide full access to all the features" (there is no paid content).

**Content rating:** start the questionnaire.
- Category: **All other app types**
- Violence, fear, sexuality, language, controlled substances, gambling: **No** to all
- Does the app let users interact or exchange content? **Yes**
  - Users can share images/photos with each other: **Yes** (only with the one paired partner)
  - Shares user location: **No**
  - Allows purchases of digital goods: **No**
- Is it a web browser or search engine? **No**

**Target audience and content:** age groups **18 and over** only. Appeals to children: **No**.

**News app:** No. **Government app:** No. **Financial features:** My app doesn't provide any financial features.

**Health apps** (if asked, because of the Health & Fitness category): tick **Sleep management**
(or the closest sleep option). It is not a medical device and makes no medical claims.

**Data safety:** see section 3.

**Account deletion** (inside Data safety or its own form)
- Can users create an account? Choose **Yes** (anonymous sign-in counts).
- Delete account URL:
```
https://its-abishek-01.github.io/goodnight/privacy-policy#deleting-your-data
```

---

## 3. Data safety form

**Data collection and security**
- Does your app collect or share any of the required user data types? **Yes**
- Is all user data encrypted in transit? **Yes**
- Do you provide a way for users to request that their data is deleted? **Yes**

**Data types: tick these, and for each answer as shown**

| Section | Tick | Collected | Shared | Processed ephemerally | Required or optional | Purpose |
|---|---|---|---|---|---|---|
| Personal info | **Name** | Yes | No | No | Required | App functionality |
| Personal info | **User IDs** | Yes | No | No | Required | App functionality, Account management |
| Photos and videos | **Photos** | Yes | No | No | Optional | App functionality |
| App activity | **App interactions** | Yes | No | No | Required | App functionality |
| App activity | **Other actions** (minutes on Instagram/Shorts at night, block counts) | Yes | No | No | Optional | App functionality |
| Device or other IDs | **Device or other IDs** (push token) | Yes | No | No | Optional | App functionality |

Leave everything else unticked (location, contacts, messages, financial, health, web
browsing history, audio, files, calendar, crash logs, diagnostics).

Why "Shared: No": sending a selfie or a check-in to your own partner is a user-initiated
transfer, which Play does not count as sharing. Firebase is a service provider, which
also does not count.

---

## 4. Sensitive permission declarations (Policy > App content, or shown when you upload)

### Accessibility API
- Is your app an accessibility tool? **No**
- Description of the feature:
```
GoodNight is a digital-wellbeing app for couples. Its "night mode" helps a person keep the bedtime they agreed with their partner. During that person's approved bedtime hours only, the AccessibilityService reads which app is in the foreground, the URL in the browser's address bar, and whether YouTube is showing a Shorts screen. After a 5-minute grace period on Instagram or YouTube Shorts, it returns the user to the home screen and shows a full-screen overlay for 10 minutes. It does not read message content, passwords or typed text, and it does not store or upload browsing history. Only two numbers leave the device: the count of blocks and the minutes spent on those apps at night, shown in the couple's weekly report. Before the user is sent to Accessibility settings, the app shows a prominent in-app disclosure with an "I agree" button. The feature is optional and can be turned off in the app's Setup tab.
```
- Video (YouTube unlisted link). Record on a phone:
  1. Open GoodNight > Setup > Night mode blocking > **Turn on**: the disclosure dialog shows.
  2. Tap **I agree**, enable "GoodNight night mode" in Accessibility settings.
  3. During bedtime hours, open Instagram, wait out the grace time (you can temporarily
     build with a shorter grace for the video), show the block overlay.

### Exact alarms (`USE_EXACT_ALARM`)
- Core functionality: **Alarm clock**
```
GoodNight's smart alarm wakes the user at the wake time they agreed with their partner, rings again on snooze, and rings a verification alarm minutes later. These must fire at the exact minute.
```

### Full-screen intent (`USE_FULL_SCREEN_INTENT`)
- Use case: **Alarm clock**
```
Shows the ringing wake-up alarm and its dismiss challenge over the lock screen.
```

### Foreground service (type: media playback)
```
While the wake-up alarm rings, a media-playback foreground service plays the alarm sound until the user completes the dismiss challenge. It starts only when a scheduled alarm fires and stops when the alarm is dismissed or snoozed.
```
- Video: an alarm ringing and being dismissed.

### Battery optimisation (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`), if asked
```
Some Android makers kill background work, which stops the wake-up alarm and the night-mode service. The Setup tab asks the user, with an explanation, to exempt GoodNight so the alarm rings reliably.
```

---

## 5. App signing (before your FIRST upload)
When you create your first release, Play shows **App integrity / app signing**. Choose
**Use a different key** / **Export and upload a key from Java keystore**, then follow the
PEPK command it shows with `goodnight-release.jks` (you type the keystore password
yourself). This keeps Play builds and GitHub APKs interchangeable. If Play has already
said "Releases signed by Google Play", stop and tell me before uploading.

---

## 6. Closed test release (Test and release > Testing > Closed testing)
1. Create track (or use "Alpha"), **Countries:** add the countries your testers are in
   (or all).
2. **Testers:** create an email list with 12+ Gmail addresses (or a Google Group).
3. **Create release:** upload `goodnight-v0.2.0.aab` from the GitHub release.
4. Release name: `0.2.0`. Release notes:
```
<en-US>
First test build. Pair with your partner, agree on bedtimes, try the smart alarm and night mode, and tell us what breaks.
</en-US>
```
5. Review and roll out. Send testers the **opt-in link** (shown on the Testers tab).

## 7. Message to send your testers
```
Hi! I made GoodNight, a sleep-pact app for couples, and need testers for 14 days.
1. Open this link on your Android phone and tap "Become a tester": <OPT-IN LINK>
2. Install GoodNight from the Play Store link on that page.
3. Pair with your partner (or with me) and use it for 2 weeks.
Please don't leave the test early: Google needs 12 people to stay in for 14 days in a row.
```

## 8. After 14 days
Dashboard > **Apply for production**. Answer honestly: how many testers, what they used,
what you changed. After approval: Production > Create release (same .aab or newer), roll out.

## 9. Screenshots
`store/screenshots/` has five 1080x1920 screenshots of the real screens, rendered with
sample data (a couple called Sam and Alex on a 9-night streak). Four or more at 1080px
make the app eligible for promotion. Real-phone screenshots of the alarm or Moments can
be added later (power + volume-down).
