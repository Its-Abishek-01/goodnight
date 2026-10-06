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
the release with generated notes. The permanent install link is:

`https://github.com/Its-Abishek-01/goodnight/releases/latest`

Version name comes from the tag and the build number from the workflow run
number, so every release is newer than the last.

## Local release build
Without `android/key.properties`, release builds are signed with the debug key.
To sign locally, create `android/key.properties` (git-ignored):

```
storeFile=../goodnight-release.jks
storePassword=...
keyAlias=goodnight
keyPassword=...
```
