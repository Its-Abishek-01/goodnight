# Build status

1. Foundation: Flutter, Firebase, anonymous sign-in, pairing - done
2. Bedtime proposal, partner approval and locking - done
3. Smart alarm (escalating snooze challenges, verify alarm, alarm QR) - done
4. Instagram app and browser blocking (5 min grace, 10 min block) - done
5. YouTube Shorts blocking - done (same accessibility service)
6. Check-ins, reminders, streak, weekly report, forgiveness - done
7. Coupons (streak only, single use, deleted when confirmed) - done
8. Public release setup: README, docs, release workflow - done

# Not yet verified
- Everything on real devices across phone brands. Unit tests cover the streak, alarm
  scheduling, challenge selection and the block engine logic.
- Firestore security rules against a live project (no emulator test yet).
- The optional Cloud Function for push alerts.

# Ideas for later
- Per-couple configurable grace and block durations, locked at pairing time.
- A photo-of-object alarm challenge.
- Play Store release (closed test with 12 testers for 14 days, plus the Accessibility
  declaration).
