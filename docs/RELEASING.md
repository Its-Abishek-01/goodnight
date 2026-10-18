# Releasing GoodNight

Pushing a version tag builds a signed APK and publishes it as a GitHub Release.
Normal commits do not build anything.

## One-time setup

### 1. Create the release keystore
Keep this file and its passwords safe. If you lose them, existing users cannot
update the app without uninstalling first. Never commit the keystore.

```bash
keytool -genkeypair -v -keystore goodnight-release.jks -alias goodnight \
  -keyalg RSA -keysize 2048 -validity 10000
```

### 2. Add GitHub Secrets
Repo > Settings > Secrets and variables > Actions > New repository secret.

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | the keystore encoded as base64 (command below) |
| `KEYSTORE_PASSWORD` | the keystore password you chose |
| `KEY_ALIAS` | `goodnight` |
| `KEY_PASSWORD` | the key password you chose |
| `GOOGLE_SERVICES_JSON` | the full contents of `android/app/google-services.json` |

Encode the keystore:

```bash
base64 -w0 goodnight-release.jks      # macOS: base64 -i goodnight-release.jks
```

### 3. Restrict the Firebase API key (recommended)
Get the release SHA-1:

```bash
keytool -list -v -keystore goodnight-release.jks -alias goodnight
```

In Google Cloud Console > APIs & Services > Credentials, restrict the Android
API key to package `com.wiozen.goodnight` and that SHA-1. Also add the SHA-1
to the Android app in Firebase project settings.

### 4. Make the repo public
Settings > General > Danger Zone > Change visibility. Releases on a private
repo cannot be downloaded by other people.

## Releasing

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow runs analyze and tests, builds `goodnight-v0.1.0.apk`, and creates
the release with this version's section of `CHANGELOG.md` as its notes, so move the
Unreleased entries under a `## 0.1.0 - <date>` heading (and set `version:` in
`pubspec.yaml` to match) before tagging. The permanent install link is:

`https://github.com/Its-Abishek-01/goodnight/releases/latest`

Version name comes from the tag and the build number from the workflow run
number, so every release is newer than the last.

## In-app updates
The app asks `api.github.com/repos/Its-Abishek-01/goodnight/releases/latest` for the newest
release (drafts and pre-releases are skipped) on launch and on resume, at most every 3 hours.
If its tag is newer than the installed version name, it offers the update with the first
bullets of the notes. Update downloads the `.apk` asset and opens the Android installer;
"Later" hides that release for a day.

- **Pushing a tag ships the update to everyone** within a few hours. To hold one back,
  publish it as a draft or pre-release first and make it a full release when ready.
- **Forced update:** edit the release on GitHub and add `<!-- required -->` anywhere in the
  notes (it is invisible on the page). Older versions then show a full-screen "update now"
  screen with no way past it. Use it only for breaking changes, such as Firestore rules the
  old app cannot work with.
- Updates only install over a build signed with the same key. Debug builds never check.
- Local builds take their version from `pubspec.yaml`; keep it at the latest released
  version so a locally built release APK is offered the next update.

## Manual (local) release build
Same signed APK as the workflow, built on your own computer.

1. Put `google-services.json` in `android/app/` (Firebase console download).
2. Copy `android/key.properties.example` to `android/key.properties` and fill it in.
   `storeFile` is an absolute path, or relative to the `android/` folder
   (`../goodnight-release.jks` if the keystore sits in the repo root; it is git-ignored).
3. Build:
   ```bash
   bash scripts/build-release.sh              # goodnight-local.apk
   bash scripts/build-release.sh 0.1.1 20     # goodnight-0.1.1.apk
   ```
   It runs analyze and tests, builds, and checks the APK is signed with the release key
   (not the debug key). Use a build number higher than the last release's
   (GitHub Actions uses its run number), or Android will refuse to install it as an update.

You can also run Flutter directly. With `android/key.properties` in place, release builds
are signed with your release key:
```bash
flutter build apk --release --build-name=0.1.1 --build-number=20         # installable APK
flutter build apk --debug                                                # debug, uses the debug key
```
Without the flags, the version comes from `pubspec.yaml`. A higher
build number is required for every update.

### Firebase API key and SHA-1
The Firebase API key is restricted to the package and certificate SHA-1 values. Each way of
building signs with a different key, so each SHA-1 must be listed or Firebase calls (sign-in,
Firestore) fail with "API key not valid" / "requests from this Android client application
are blocked":

| Build | SHA-1 to add (Google Cloud Console > APIs & Services > Credentials > the Android key) |
|---|---|
| Release APK you sign yourself | `keytool -list -v -keystore goodnight-release.jks -alias goodnight` |
| Debug builds (differs on every computer) | `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android` |

Add the same SHA-1 values to the Android app in Firebase project settings too.

Without `key.properties`, `flutter build apk --release` silently signs with the debug key.
That APK installs fine but can never update a release install, so avoid it for sharing.

## Backing up your secrets
`bash scripts/make-private-zip.sh` bundles the source plus the keystore,
`key.properties` and `google-services.json` into `../goodnight-FULL-PRIVATE.zip`.
It is not encrypted: keep it in private storage only. To restore on a new machine,
unzip it and `flutter pub get`; everything is already in place.
