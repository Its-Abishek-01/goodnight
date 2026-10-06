#!/usr/bin/env bash
# Manual signed release build, same result as the GitHub workflow.
#   bash scripts/build-release.sh              -> goodnight-local.apk
#   bash scripts/build-release.sh 0.1.1 20     -> goodnight-0.1.1.apk (name 0.1.1, build number 20)
# Works in Git Bash on Windows, macOS and Linux.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
BUILD="${2:-}"
fail() { echo "ERROR: $*" >&2; exit 1; }

[ -f android/app/google-services.json ] ||
  fail "missing android/app/google-services.json (download it from the Firebase console, project goodnight-27157)"
[ -f android/key.properties ] ||
  fail "missing android/key.properties (copy android/key.properties.example, then fill it in)"

store=$(grep '^storeFile=' android/key.properties | cut -d= -f2- | tr -d '\r')
case "$store" in
  /* | [A-Za-z]:*) keystore="$store" ;;
  *) keystore="android/$store" ;;
esac
[ -f "$keystore" ] || fail "keystore not found at $keystore (check storeFile in android/key.properties)"

flutter pub get
flutter analyze
flutter test

args=(--release)
[ -n "$VERSION" ] && args+=(--build-name="$VERSION")
[ -n "$BUILD" ] && args+=(--build-number="$BUILD")
flutter build apk "${args[@]}"

out="goodnight-${VERSION:-local}.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$out"

# Best effort: confirm the APK is signed with the release key, not the debug key.
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/AppData/Local/Android/sdk}}"
apksigner=$(ls "$sdk"/build-tools/*/apksigner "$sdk"/build-tools/*/apksigner.bat 2>/dev/null | sort | tail -1 || true)
if [ -n "$apksigner" ]; then
  certs=$("$apksigner" verify --print-certs "$out" 2>&1 || true)
  echo "$certs" | grep -m1 -i "certificate DN" || true
  if echo "$certs" | grep -qi "Android Debug"; then
    fail "$out is signed with the DEBUG key. Check android/key.properties."
  fi
else
  echo "(apksigner not found, skipped signature check)"
fi

echo "Built $out"
