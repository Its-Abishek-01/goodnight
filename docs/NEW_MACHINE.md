# Continuing on a new machine

Everything except secrets is in this repo. Read `CLAUDE.md` first; it is written so a
fresh Claude Code session can pick up the project.

## Install
- Git and the GitHub CLI (`gh auth login`)
- Flutter **3.41.6** (stable) with the Android SDK and JDK 17
- Node 22 and the Firebase CLI (`npm i -g firebase-tools`, then `firebase login`)
- Claude Code (optional): open the cloned folder and ask it to continue from `docs/ROADMAP.md`

## Clone and run
```bash
git clone https://github.com/Its-Abishek-01/goodnight.git
cd goodnight
flutter pub get
```
Then restore the one local-only file, which is git-ignored:

- `android/app/google-services.json`: Firebase console > project `goodnight-27157` >
  Project settings > Your apps > `com.wiozen.goodnight` > download. (`android/local.properties`
  is created by Flutter automatically.)

```bash
flutter analyze && flutter test
flutter run            # needs an Android phone or emulator
```

## Things that are NOT in the repo (keep them somewhere safe, off the work machine)
| Item | Where it lives now | If you lose it |
|---|---|---|
| Release keystore `goodnight-release.jks` and its passwords | your own backup | Users cannot update the app; they would have to uninstall and reinstall. Back it up. |
| GitHub Secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, `GOOGLE_SERVICES_JSON` | repo Settings > Secrets | Re-add from the keystore and Firebase console |
| Firebase login | CLI, per machine | `firebase login` |

## Manual release build
See "Manual (local) release build" in `docs/RELEASING.md` (`bash scripts/build-release.sh`).
If you saved `goodnight-FULL-PRIVATE.zip`, unzipping it restores the keystore, `key.properties`
and `google-services.json` in the right places.

## Releasing and deploying
- Release: push a `v*` tag (see `docs/RELEASING.md`). The install link is
  `https://github.com/Its-Abishek-01/goodnight/releases/latest`.
- Firestore rules and functions, from the repo folder (not another project):
  ```bash
  firebase deploy --only "firestore:rules,functions" --project goodnight-27157
  ```

## Where things stand
See `docs/ROADMAP.md`. Short version: all planned features are built; the app has not yet
been tested on real phones. Test pairing, the alarm, night-mode blocking, selfies with the
home-screen widget and coupons on two Android phones, then fix what breaks.
