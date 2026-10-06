#!/usr/bin/env bash
# Bundles the committed source PLUS the git-ignored secrets (keystore, key.properties,
# google-services.json) into ../goodnight-FULL-PRIVATE.zip for your personal backup.
# The zip is NOT encrypted. Store it only somewhere private, never on GitHub.
set -euo pipefail
cd "$(dirname "$0")/.."

for f in goodnight-release.jks android/key.properties android/app/google-services.json; do
  [ -f "$f" ] || { echo "ERROR: missing $f" >&2; exit 1; }
done
if grep -q FILL_ME_IN android/key.properties; then
  echo "ERROR: android/key.properties still has FILL_ME_IN. Put your real passwords in it first." >&2
  exit 1
fi

SRC="goodnight-source.tmp.zip"
trap 'rm -f "$SRC"' EXIT
git archive --format=zip --prefix=goodnight/ -o "$SRC" HEAD
SRC="$SRC" python - <<'PY'
import zipfile, os
tmp = os.environ['SRC']
out = os.path.abspath(os.path.join('..', 'goodnight-FULL-PRIVATE.zip'))
with zipfile.ZipFile(tmp) as zin, zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for i in zin.infolist():
        z.writestr(i, zin.read(i.filename))
    for f in ('goodnight-release.jks', 'android/key.properties', 'android/app/google-services.json'):
        z.write(f, 'goodnight/' + f)
print('Wrote', out)
PY
