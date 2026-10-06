#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(node -p 'require("./Custom/release.json").version')"
APP="${1:-$PWD/build/ZLaunchDerivedData/Build/Products/Release/ZLaunch.app}"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = com.zachthinks.zlaunch ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" = "$VERSION" ]
node Custom/verify-bundle.mjs "$APP" Release
./Scripts/verify-signature.sh "$APP"
codesign -v -R '=anchor apple generic and certificate leaf[subject.OU] = "FVY9AS28CU" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' "$APP"
for BIN in "$APP/Contents/MacOS/ZLaunch" "$APP/Contents/Helpers/ClipboardTextHelper" "$APP/Contents/Helpers/ZLaunch Dictation.app/Contents/MacOS/ZLaunch Dictation"; do
  [ "$(lipo -archs "$BIN")" = arm64 ]
done
mkdir -p dist
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/ZLaunch.app"
ln -s /Applications "$STAGE/Applications"
PAYLOAD="$STAGE/payload"
mkdir "$PAYLOAD"
mv "$STAGE/ZLaunch.app" "$PAYLOAD/"
mv "$STAGE/Applications" "$PAYLOAD/"
hdiutil create -srcfolder "$PAYLOAD" -format UDZO -volname ZLaunch "$STAGE/ZLaunch-$VERSION.dmg"
ditto -c -k --keepParent --sequesterRsrc "$APP" "$STAGE/ZLaunch-$VERSION.zip"
mv "$STAGE/ZLaunch-$VERSION.dmg" "$STAGE/ZLaunch-$VERSION.zip" dist/
(cd dist && shasum -a 256 "ZLaunch-$VERSION.dmg" "ZLaunch-$VERSION.zip" > SHA256SUMS)
