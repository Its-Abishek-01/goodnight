# Publishing on Google Play

The plan: closed test first (required), then production and open testing, so anyone can
install from the Play Store without the Play Protect block that stops the GitHub APK.

## 0. Before you start
- [x] Contact email in `docs/privacy-policy.md`.
- [ ] Publish the privacy policy. Easiest: GitHub repo **Settings > Pages > Deploy from a
      branch > `main` / `/docs`**. The URL is then
      `https://its-abishek-01.github.io/goodnight/privacy-policy`.
- [x] Deploy the current `firestore.rules` (`firebase deploy --only firestore:rules --project goodnight-27157`).
- [x] App icon and feature graphic: `store/` (regenerate with `python scripts/make-icons.py`).
- [ ] At least 2 phone screenshots.

All the texts to paste into Play Console are in `store/play-console-answers.md`.

## 1. Developer account
- Create one at <https://play.google.com/console> (one-time USD 25, ID verification).
- **Personal account** (created after Nov 2023): you must run a closed test with
  **at least 12 testers opted in for 14 days in a row** before you can apply for
  production. Open testing stays locked until production access is granted.
- **Organization account** skips that rule but needs a D-U-N-S number.

## 2. Signing: decide this before the first upload
Play re-signs apps with an "app signing key". If Google generates a new one, Play installs
and GitHub APKs have different signatures, so people cannot switch between them without
uninstalling (and losing their local alarm/QR settings).

**Recommended:** when creating the app, under **App integrity > App signing**, choose to
use your own key and upload `goodnight-release.jks` with Google's PEPK tool (the console
shows the exact command). Then the Play build and the GitHub APK are interchangeable.
Your upload key is the same keystore. This choice cannot be undone later.

## 3. Build the bundle
Push a tag as usual (`docs/RELEASING.md`). The release now has a `.aab` next to the
`.apk`; upload the `.aab` to Play. Locally: `bash scripts/build-release.sh 0.1.1 21`.
Every upload needs a higher build number than the last one.

## 4. App content (Play Console > Policy > App content)
- **Privacy policy:** the URL from step 0.
- **App access:** "All functionality is available without special access". Add a note:
  "Pairing needs two devices: create a code on one, join on the other. Night mode needs
  the Accessibility service enabled from the Setup tab."
- **Ads:** no ads.
- **Content rating:** questionnaire. Users can share photos with one other person.
- **Target audience:** 18 and over (keeps the app out of the Families policy).
- **Data safety:** see the table below.
- **Account deletion:** in-app (Setup > Delete my data) plus the web URL: the privacy
  policy's "Deleting your data" section.

### Data safety answers
Data is encrypted in transit (Firebase uses TLS). Users can request deletion (in-app).
Nothing is shared with third parties (sending a selfie to your partner is user-initiated,
which Play does not count as sharing). No data is used for ads or analytics.

| Play category | Type | Collected | Purpose | Optional? |
|---|---|---|---|---|
| Personal info | Name | Yes | App functionality | Required |
| Personal info | User IDs (anonymous Firebase ID) | Yes | App functionality | Required |
| Photos and videos | Photos | Yes | App functionality | Optional (Moments) |
| App activity | App interactions (check-ins, snoozes, block counts, minutes on Instagram/Shorts at night) | Yes | App functionality | Partly optional |
| Device or other IDs | Push token | Yes | App functionality | Optional (push) |

## 5. Permission declarations
Play asks about each of these. Have a short screen recording ready (unlisted YouTube link).

| Permission | Why GoodNight needs it | Risk |
|---|---|---|
| Accessibility service (`BlockerService`) | Core feature: digital wellbeing, blocks Instagram and Shorts during the agreed bedtime. Not an accessibility tool. The Setup tab shows the disclosure and an "I agree" button before sending the user to Settings. The video must show that dialog, then enabling, then a block. | **Highest.** Similar blockers are approved, but reviews are strict. |
| `USE_EXACT_ALARM` (from the alarm plugin) | The app is a wake-up alarm clock. | Medium. If rejected, remove it with `tools:node="remove"`; the app already requests `SCHEDULE_EXACT_ALARM` on the Setup tab. |
| `USE_FULL_SCREEN_INTENT` | Shows the ringing alarm over the lock screen. Declare as "alarm". | Low |
| Foreground service, `mediaPlayback` | Plays the alarm sound while ringing. Video: alarm ringing. | Low to medium |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Some phones kill the alarm and blocker otherwise. | Medium. If rejected, change the Setup item to open battery settings instead of the direct prompt. |

`READ_EXTERNAL_STORAGE` from the alarm plugin is removed in the manifest (only a bundled
sound is played).

## 6. Closed test (personal accounts)
- Create a **closed testing** track, add testers by email or a Google Group, upload the
  `.aab`, and send them the opt-in link. Each tester must opt in and install from Play.
- Keep **12+ testers opted in for 14 continuous days**. If the count drops below 12, the
  clock restarts. Six couples is enough.
- Then **Dashboard > Apply for production**. Google asks about the test (what testers
  did, what you fixed).

## 7. After production access
- **Open testing:** anyone can join from the store listing; good for a public beta.
- **Production:** full public release.
- Keep shipping the `.apk` on GitHub for people outside Play (they install with
  `adb install` where Play Protect blocks browser installs).
