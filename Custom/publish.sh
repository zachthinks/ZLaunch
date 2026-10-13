#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Shared by manual and scheduled publication in this checkout. Never reclaim a
# stale lock automatically: inspect any interrupted publication before retrying.
PUBLISH_LOCK="$(git rev-parse --git-common-dir)/zlaunch-publish.lock"
if ! mkdir "$PUBLISH_LOCK"; then
  echo "Another or interrupted publisher holds $PUBLISH_LOCK; inspect it before retrying." >&2
  exit 1
fi
trap 'rmdir "$PUBLISH_LOCK"' EXIT
[ "$(git branch --show-current)" = custom/main ]
[ -z "$(git status --porcelain)" ]
: "${NOTARY_PROFILE:?Configure a local notarytool Keychain profile before publishing.}"
git fetch origin custom/main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/custom/main)" ]
node Custom/verify-release-state.mjs
export DERIVED="${DERIVED:-$PWD/build/ZLaunchDerivedData}"
if [ "${CHECKS_VERIFIED:-0}" != 1 ]; then ./Custom/check.sh; fi
CONFIGURATION=Release ./Custom/build.sh
APP="$DERIVED/Build/Products/Release/ZLaunch.app"
: "${NOTARY_PROFILE:?Configure a local notarytool Keychain profile before publishing.}"
ditto -c -k --keepParent --sequesterRsrc "$APP" build/notarize.zip
NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
if [ -n "${NOTARY_KEYCHAIN:-}" ]; then NOTARY_ARGS+=(--keychain "$NOTARY_KEYCHAIN"); fi
xcrun notarytool submit build/notarize.zip "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose "$APP"
./Custom/package.sh "$APP"
VERSION="$(node -p 'require("./Custom/release.json").version')"
[ "$(git branch --show-current)" = custom/main ]
[ -z "$(git status --porcelain)" ]
git fetch origin custom/main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/custom/main)" ]
node Custom/verify-config.mjs
node Custom/verify-release-state.mjs
node Custom/release-notes.mjs build/release-notes.md
gh release create "v$VERSION" dist/ZLaunch-"$VERSION".dmg dist/ZLaunch-"$VERSION".zip dist/SHA256SUMS \
 --repo zachthinks/ZLaunch --target "$(git rev-parse HEAD)" --title "ZLaunch $VERSION" --notes-file build/release-notes.md
