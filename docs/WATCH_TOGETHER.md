# Watch together (screen sharing) — shelved plan

Status: **paused on 2026-10-20**. Half built on the local branch
`feature/watch-together` (commit `60d7aa1`, not pushed). Nothing of it is on
`main` or in a release.

## The idea
One partner shares their phone screen, with its sound, so the other can watch
along (a movie, a video, anything on screen). Either can start it:
- **Share my screen** (an invite): the partner gets a push and a full-screen
  "Abi wants to share their screen 🍿 — Watch / Not now".
- **Ask to see** (a request): the sharer gets "Abi wants to see your screen —
  Share my screen / Not now".

The sharer always confirms with Android's own screen-capture dialog.

Decisions made with the user:
- **Viewer style:** "movie night" (full screen, rotates, tap reactions that
  float up on both phones) **plus a mic button** to talk while watching.
- **Sound:** share the phone's sound too (Android 10+).
- **Network:** a relay so it works on mobile data: Cloudflare TURN (big free
  monthly allowance), credentials made by a Cloud Function.

## Done on the branch
- `lib/features/share/share.dart`: model (`asked` → `offered` → `live` →
  `ended`/`declined`), `incomingPrompt`, `expiredShares`, `iceServersFrom`,
  `boostOpus`, `elapsedLabel` (pure, not yet unit-tested).
- `share_repository.dart`: `pairs/{pairId}/shares/{id}` doubles as WebRTC
  signalling (offer/answer, `sharerIce`/`viewerIce` arrays).
- `share_providers.dart`: `ShareController` (flutter_webrtc call for both
  roles, ICE queueing, serialized snapshot handling, data channel for
  reactions, mic toggle, 2-min invite timeout, notification actions),
  `ShareInbox` (prompts for the gate), `shareSyncProvider` (deletes day-old docs).
- `share_screens.dart`: `WatchTogetherCard`, `SharePromptScreen`,
  `ShareSessionScreen` (sharer view and full-screen viewer), `FloatingReactions`.
- Native: `ScreenShareService.kt` (foreground service, type
  mediaProjection|microphone, Mute/Stop notification), `ShareSound.kt` (records
  the phone's sound with AudioPlaybackCapture and mixes it into WebRTC's mic
  audio via flutter_webrtc's `capturePostProcessing`; "mute" silences only the
  voice), `ShareChannel.kt` (`com.wiozen.goodnight/share`),
  `BlockerService.showReaction` (emoji floating over other apps).
- `flutter_webrtc ^1.6.2` and `cloud_functions ^6.5.0` added;
  `compileOnly("io.github.webrtc-sdk:android:150.7871.01")` in
  `android/app/build.gradle.kts` (must match the plugin's version).
- Manifest: FOREGROUND_SERVICE(+_MEDIA_PROJECTION, _MICROPHONE) and the service.

## Still to do
1. Rebase the branch on `main` (it was cut before the bubble fixes moved on).
2. Wire it in: `app.dart` gate (session screen while active, then prompts,
   after the love note check), `WatchTogetherCard` on Tonight,
   `ref.watch(shareSyncProvider)` in `HomeScreen`.
3. `firestore.rules`: `shares/{id}` (members read; create with
   `by == auth.uid`, sharer≠viewer, both members; sharer may change only
   `offer`/`sharerIce`, viewer only `answer`/`viewerIce`; status values;
   `closingByMember` delete) and add `shares` to `PairRepository.pairCollections`.
4. Cloud Functions: `shareAlert` (push on `asked` to the sharer, on an
   invite `offered` to the viewer) and `shareIceServers` (onCall; reads
   `config/turn` {keyId, apiToken} with the admin SDK, calls Cloudflare's
   `generate-ice-servers`, falls back to STUN).
5. The user: Cloudflare account → Realtime/TURN key → create Firestore doc
   `config/turn` with `keyId` and `apiToken` (clients cannot read `config`).
6. Tests for the pure helpers in `share.dart`; CLAUDE.md, CHANGELOG, README,
   privacy policy (screen and sound go peer to peer or through the relay,
   nothing is stored).
7. Try it on the two phones: wifi and mobile data, YouTube sound, mic,
   reactions over other apps, rotation, stop from the notification.

## Risks to check first
- **Sound mixing is unverified.** It assumes `process()` gets full-band float
  samples in the 16-bit range, one channel, 10 ms per call. If it sounds wrong,
  look there first; the screen itself does not depend on it.
- It finds the MediaProjection through flutter_webrtc's private fields
  (reflection). The plugin's ProGuard rules keep the names, but a plugin update
  can rename them; the sound then quietly falls back to voice only.
- Netflix, Prime and Hotstar block capture: black picture, no sound.
- The APK grows by roughly 20–40 MB (WebRTC native libraries).
- Android 14 order matters: `Helper.requestCapturePermission()`, then start the
  foreground service, then `getDisplayMedia`.
