# Architecture

```
 Phone A                                   Phone B
 ┌───────────────────────────┐             ┌───────────────────────────┐
 │ Flutter UI (Riverpod)     │             │ Flutter UI (Riverpod)     │
 │  pairing · bedtime · alarm│             │  same app                 │
 │  check-in · report · coupons            │                           │
 │        │ MethodChannel    │             │                           │
 │ Kotlin AccessibilityService             │                           │
 │  (BlockEngine: grace/block)│             │                           │
 └────────────┬──────────────┘             └─────────────┬─────────────┘
              │          Firebase (Spark plan)           │
              └──────►  Auth (anonymous) + Firestore ◄───┘
                        FCM + Cloud Functions (optional, Blaze)
```

## Layers
| Layer | Where | Role |
|---|---|---|
| UI and state | `lib/features/*`, Riverpod providers | Screens, streams from Firestore, sync providers |
| App gate | `lib/core/app.dart` | Chooses ring / pairing / waiting / home screen |
| Backend | Firestore + `firestore.rules` | Shared state and the rules of the pact |
| Alarm | `lib/features/alarm`, `alarm` package | Exact wake alarm, escalation, QR challenge |
| Blocking | `android/.../BlockerService.kt`, `BlockEngine.kt` | Detects Instagram, browser Instagram, Shorts and enforces the block |
| Push (optional) | `functions/index.js` | Background alerts to the partner |

## Data flow examples
- **Bedtime approval:** A writes `schedules/A.proposal` -> B sees it live -> B approves, which moves it to `current` -> A's `alarmSyncProvider`, `blockerSyncProvider` and `reminderSyncProvider` all react to the new `current` window.
- **Night block:** service ticks every 5s -> `BlockEngine.tick` decides Allow or Block -> block counts stored natively -> uploaded to `nights/{key}.players.{uid}` when the app opens.
- **Coupon:** streak reaches a milestone -> `grants/{startKey_m}` plus two `coupons/*` created in one transaction -> holder redeems -> partner confirms and the coupon is deleted.

## Key decisions
- **Two people only, mutual by design.** Bedtimes lock after the partner approves, and changes need approval again.
- **Free to run.** Spark plan only; push is opt-in because it needs Blaze.
- **Logic kept pure and tested.** Streak rules (Dart) and the block engine (Kotlin) have no Android or Firebase dependencies.
- **Accessibility service, not a VPN or device admin.** Least invasive way to detect the foreground app and browser URL, with a plain-language consent screen.
- **Public project, bring-your-own Firebase** for people who build from source; released APKs share the maintainer's project.

See `CLAUDE.md` for developer commands and gotchas.
