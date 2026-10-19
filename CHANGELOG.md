# Changelog

All notable changes to GoodNight. The format follows Keep a Changelog.

## [Unreleased]

## 0.2.8 - 2026-10-20
### Changed
- The watch bubble now shows whenever Instagram or YouTube Shorts is open, not only after bedtime. During the day it shows how long you have been on this sitting and how many reels; at night it still counts down to your pause.
- When tucked away, the bubble is see-through so it stays out of the way.

### Added
- "Preview the bubble" on the Us tab shows it on screen for a few seconds, going through every mood.

### Fixed
- GoodNight's own overlays could be mistaken for the app in front, which could hide the bubble and stop counting Instagram time.

## 0.2.7 - 2026-10-20
### Added
- Account backup: on the Us tab, create a backup code (shown once as text and a QR code). On a new phone or after a reinstall, tap "Restore with a backup code" on the first screen, type it or scan it from the old phone, and your pair, streak and history come back.
- Scan your partner's code also works for backup codes; the scanner is shared.
- Watch bubble: at night, a little face peeks from the right edge of the screen on Instagram and YouTube Shorts. Every so often (and when you tap it) it slides out to show how long you have watched tonight and how many reels, then tucks itself away again. It starts happy, then glances at you, sweats, yawns and finally gets grumpy as your pause gets closer. Drag it up or down to move it. Turn it off on the Us tab under Night mode.

## 0.2.6 - 2026-10-19
### Added
- Choose your wake-up sound on the Us tab: Soft chimes, Music box, Morning birds, Sunrise piano, Classic beep, or one of your phone's own alarm sounds. Tap play to hear each one.
- Let your partner pick it: switch "Wake-up sound" to "{partner} picks", and they choose for you from their Us tab.
- Wake-up messages: record up to 15 seconds for your partner, and they can pick your voice as their alarm. They get a push when it arrives.

### Changed
- A new alarm screen: a smiling sun rises over the hills while the alarm rings, with a big clock, a good-morning greeting, a note when your partner is already up, and the challenge in a card at the bottom.
- The default alarm sound is now Soft chimes.

## 0.2.5 - 2026-10-19
### Added
- Choose when you hear about your partner: on the Us tab, "Alerts about {partner}" lets you pick Off, 5, 10, 15, 30 or 60 minutes. Once they have been on their phone that long after their bedtime (any app, not only Instagram), you get a push. Your partner sees what you picked. The default is 15 minutes, which replaces the old alert on the first minute of Instagram.
- Your partner's Tonight card shows their minutes on the phone after bedtime.
- Night mode times you agree on: on the Us tab, pick how many minutes of Instagram/Shorts you get before a pause (3, 5, 10 or 15) and how long the pause lasts (10, 15, 20 or 30). Like your bedtime, a change waits for your partner's OK.
- Ask for more time: the pause screen has +5, +10 and +15 min buttons that ask your partner (up to 3 times a night). They get a push and answer on their Tonight tab; a yes unlocks Instagram/Shorts for exactly that long, even while GoodNight is closed.

### Fixed
- Partner pushes now pop up on screen with sound, like a chat message, instead of arriving silently in the notification tray.
- Night mode no longer counts time while the screen is off or locked with Instagram or Shorts left open.

## 0.2.4 - 2026-10-19
### Added
- "Going to sleep" home-screen widget: you and your partner tonight (bedtime, asleep since, up since) and a button that checks you in. It updates when your partner checks in or wakes up, even while the app is closed, and you get a "{name} is going to sleep" notification.
- Pair by QR code: the waiting screen shows a QR code, and joining has a "Scan your partner's code" button. Typing the code still works.

### Changed
- A new loading animation everywhere: two little love letters fly together and a heart floats up. No more spinners.
- The waiting-for-your-partner screen is centred and tidier.

## 0.2.3 - 2026-10-19
### Added
- Your partner now finds out when you are on Instagram or Shorts after bedtime, even while GoodNight is closed: a push on the first minute and each time night mode steps in, and the minutes show live on their Tonight card.
- Push alerts for love notes and their read receipts (the Cloud Functions are now deployed).

## 0.2.2 - 2026-10-19
### Added
- Tonight now shows a live "how your partner's night is going" card: whether they are winding down, asleep (and since when), snoozing, or up, plus tonight's Instagram/Shorts minutes and night-mode blocks. You both see the same card about each other.
- Updates from inside the app: GoodNight checks GitHub for a new version when you open it, downloads it and opens the installer. No more downloading APKs by hand.
- Love notes: send your partner a short message that fills their screen the moment it lands, with a read receipt back to you once they have seen it. Quick presets for one-tap sending, and a push alert when the Cloud Functions are deployed.

### Changed
- GitHub releases no longer include an `.aab`: GoodNight is not going on Google Play.
- Clearer night-mode disclosure: it now says which two numbers are saved and shared with your partner.
- The weekly report shows each person's average sleep length, and every finished night lists the actual check-in and wake times, how long they slept, and phone minutes.

## 0.2.1 - 2026-10-06
### Added
- The whole app follows the time of day: a full-screen animated sky with twinkling stars and shooting stars at night, a sunset at dusk, a sunrise at dawn and a smiling sun with drifting clouds by day. Colours, cards and icons switch with it, and the moon button becomes a sun in the morning. Long-press the logo to preview each time of day.
- Profiles: your own photo and name (both of you see them), plus a private pet name and photo for your partner that only you see. Setup is now the Us tab.
- Cute animated bottom bar: Tonight is a golden moon button in the middle, and every icon plays a little animation when tapped.

### Changed
- New "journey to the moon" design: a starry night sky behind every screen, and on Tonight the two of you climb a dotted arc to the moon as you check in. The moon glows when you both arrive.
- Each person picks their own colour when pairing (and can change it in Setup); avatars, bedtimes and the report use it.
- New app icon (golden crescent heart) for the launcher, themed icons, notifications, the splash screen and the pairing screen.

## 0.2.0 - 2026-10-06
### Added
- Pick your features on the Setup tab. Smart alarm, night-mode blocking and reminders are each person's own choice; streak & coupons and Moments are shared, so one of you proposes a change and the other approves it. Without the alarm, only your bedtime counts towards the streak.
- Delete my data: ends the pact and permanently deletes everything stored for the pair (Setup tab, or while waiting for a partner).
- App icon.
- Releases also include an `.aab` for Google Play.

## 0.1.0
### Added
- Pairing with a single-use code and anonymous sign-in.
- Bedtime proposals that the partner must approve, then lock.
- Smart alarm that gets louder and harder with every snooze, plus a verify alarm and QR challenge.
- Night-mode blocking for Instagram (app and browser) and YouTube Shorts: 5 min grace, 10 min block.
- Check-ins, partner status, bedtime and call wrap-up reminders.
- Shared streak, 7-night report and weekly mutual forgiveness.
- Streak-earned, single-use coupons.
- Moments: private selfies between partners with read receipts and an Android home-screen widget.
- Tag-triggered release workflow that publishes a signed APK.
- Optional Cloud Function for background push alerts.
