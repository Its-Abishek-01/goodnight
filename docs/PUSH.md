# Optional push alerts

GoodNight works fully on the free Firebase Spark plan. Without push, your partner
still sees everything live while the app is open: the "snoozed N times" banner on
the Tonight tab, bedtime proposals, and coupons.

Real background push (a notification when your partner keeps snoozing, proposes a
bedtime, or redeems a coupon) needs a server, which means a Cloud Function and the
Blaze (pay-as-you-go) plan. Light use stays inside the free quota, but Blaze needs a
billing account, so this is opt-in.

## Deploy
```bash
npm install -g firebase-tools
firebase login
firebase use <your-project-id>
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

These functions have not been tested against a live project yet.
