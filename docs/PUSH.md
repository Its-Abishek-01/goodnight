# Optional push alerts

GoodNight works fully on the free Firebase Spark plan. Without push, your partner
still sees everything live while the app is open: the "snoozed N times" banner on
the Tonight tab, bedtime proposals, and coupons.

Real background push (a notification when your partner keeps snoozing, proposes a
bedtime, or redeems a coupon) needs a server, which means a Cloud Function and the
Blaze (pay-as-you-go) plan. Light use stays inside the free quota, but Blaze needs a
billing account, so this is opt-in.

## Deploy
`firebase.json` and `.firebaserc` (project `goodnight-27157`) are already in the repo.
Using your own Firebase project? Change the id in `.firebaserc` first.

```bash
npm install -g firebase-tools
firebase login --reauth
cd functions && npm install && cd ..
firebase deploy --only functions
```

The app already saves each phone's FCM token to `users/{uid}.fcmToken` and shows
pushes that arrive while it is open. The functions in `functions/index.js` send:

| Trigger | Message to partner |
|---|---|
| Snooze count reaches 2 or 3 and not yet up | "{name} is still asleep" |
| New or changed bedtime proposal | "Bedtime to approve" |
| Coupon redeemed | "{name} used a coupon" |
| New selfie | data-only push that refreshes the home-screen widget and shows a notification |
| Selfie opened | "{name} saw your selfie" (the read receipt) |
| New love note | "💌 {name}" with the note |
| Love note opened | "{name} read your love note" |
| Check-in or wake-up | data-only push that updates the "Going to sleep" widget; on check-in the app shows "{name} is going to sleep" |
| First minute of Instagram/Shorts after bedtime | "{name} is still scrolling" |
| Night mode blocks Instagram/Shorts | "Night mode paused {name}'s scrolling" with tonight's minutes |

The two night-mode alerts fire only on live reports from the phone's night-mode
service (`NightReporter.kt`, which also sets `usageAt`), so the catch-up upload when
the app opens never sends a late alert.

All functions run in `asia-south1`, next to the Firestore database (set with
`setGlobalOptions` in `functions/index.js`). Deploying without it tries to move them
to `us-central1` and delete the old ones.

First deploy of 2nd-gen functions can fail with an Eventarc permission error. Wait a few minutes and run the deploy again.

Deployed on 2026-10-19. Push has not been checked end to end on real phones yet.
