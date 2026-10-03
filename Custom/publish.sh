#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(git branch --show-current)" = custom/main ]
[ -z "$(git status --porcelain)" ]
: "${NOTARY_PROFILE:?Configure a local notarytool Keychain profile before publishing.}"
git fetch origin custom/main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/custom/main)" ]
VERSION="$(node -p 'require("./Custom/release.json").version')"
if gh release view "v$VERSION" --repo zachthinks/ZLaunch >/dev/null 2>&1; then
  echo "Version already published; increase Custom/release.json version." >&2; exit 1
fi
export DERIVED="${DERIVED:-$PWD/build/ZLaunchDerivedData}"
if [ "${CHECKS_VERIFIED:-0}" != 1 ]; then ./Custom/check.sh; fi
CONFIGURATION=Release ./Custom/build.sh
APP="$DERIVED/Build/Products/Release/ZLaunch.app"
: "${NOTARY_PROFILE:?Configure a local notarytool Keychain profile before publishing.}"
ditto -c -k --keepParent --sequesterRsrc "$APP" build/notarize.zip
xcrun notarytool submit build/notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose "$APP"
./Custom/package.sh "$APP"
VERSION="$(node -p 'require("./Custom/release.json").version')"
[ "$(git branch --show-current)" = custom/main ]
[ -z "$(git status --porcelain)" ]
git fetch origin custom/main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/custom/main)" ]
node Custom/verify-config.mjs
node Custom/release-notes.mjs build/release-notes.md
gh release create "v$VERSION" dist/ZLaunch-"$VERSION".dmg dist/ZLaunch-"$VERSION".zip dist/SHA256SUMS \
 --repo zachthinks/ZLaunch --target "$(git rev-parse HEAD)" --title "ZLaunch $VERSION" --notes-file build/release-notes.md
