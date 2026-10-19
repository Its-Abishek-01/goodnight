---
title: GoodNight privacy policy
---

# GoodNight privacy policy

_Last updated: 18 October 2026_

GoodNight is a sleep pact app for two people. This policy explains what the app stores,
why, and how to delete it. GoodNight is open source; you can read exactly what it does at
<https://github.com/Its-Abishek-01/goodnight>.

## Who runs it
GoodNight is published by an independent developer. Contact: **abishek.mk.01@gmail.com**.

## What is stored, and why
The app has no accounts or passwords. It signs in anonymously with Firebase
Authentication, which gives your phone a random user ID. Everything below is stored in
Google Firebase (Cloud Firestore) and can be read only by you and the one partner you
paired with.

| Data | Why |
|---|---|
| Random user ID | To link your phone to your pair |
| The name you type in | So your partner sees who you are |
| Your bedtime and wake time, and any proposed changes | The pact: your partner approves them |
| Which features you turned on | So both phones follow the same choices |
| Check-in and wake-up times, snooze counts | The shared streak and weekly report |
| Number of night-mode blocks, minutes spent on Instagram or YouTube Shorts at night, and minutes the phone was in use at all after bedtime (not which apps) | The weekly report, and an alert to your partner after the number of minutes they chose |
| Coupons earned and used | Streak rewards |
| Selfies you choose to send (Moments) | Shown to your partner only |
| Love notes you send | Shown to your partner only, with a read receipt |
| Requests for extra night-mode minutes and your partner's answer | So your partner can say yes or no; deleted after two days |
| A push notification token | To alert your partner's phone (only if push alerts are set up) |

GoodNight does not use advertising, analytics or tracking, and does not sell or share
your data with anyone. Google provides the hosting (Firebase), the push notifications
(Firebase Cloud Messaging) and the QR code scanner (ML Kit, which runs on your phone).

## Accessibility service (night mode)
If you turn on night-mode blocking, GoodNight uses Android's Accessibility service.
During your agreed bedtime hours only, it checks which app is in front, the address in
your browser's address bar and whether YouTube is showing Shorts, so it can pause
Instagram and YouTube Shorts after a short grace time. This happens on your phone. It
never reads your messages, passwords or what you type, it does not record your browsing
history, and nothing is uploaded except the counts in the table above. They are sent as they change during the night, so your partner sees them live.
You are asked to agree before it is turned on, and you can turn it off at any time.

## Updates
When you open the app, it asks GitHub (github.com, which hosts the app's releases)
whether a newer version exists, and downloads it from there if you tap Update. GitHub sees
your phone's IP address, as with any web request; nothing about you or your pair is sent.

## Camera, notifications and alarms
- **Camera:** to scan the alarm QR code (processed on your phone) and to take selfies you
  decide to send.
- **Notifications and alarms:** for the wake-up alarm and bedtime reminders. These are
  scheduled on your phone.

## How long data is kept
- Selfies are deleted automatically after 7 days.
- Everything else is kept while your pair exists, and deleted when either of you
  deletes it.

## Deleting your data
In the app, open **Setup** and tap **Delete my data** (or **Cancel and delete my data**
while waiting for your partner). This permanently deletes your pair and everything stored
for it (bedtimes, nights, streak, coupons, selfies), your name and your anonymous user ID,
and clears the alarms and reminders on your phone. Your partner's app returns to the
pairing screen.

If you no longer have the app, email **abishek.mk.01@gmail.com** with your name and your
partner's name, and the data will be deleted within 30 days.

## Children
GoodNight is meant for adults and is not directed at children under 13.

## Changes
Changes to this policy are published at this address, and the date at the top is
updated.
