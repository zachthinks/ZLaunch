#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[ "${GITHUB_ACTIONS:-}" = true ]
[ "${RUNNER_ENVIRONMENT:-}" = github-hosted ]
[ "${GITHUB_REPOSITORY:-}" = zachthinks/ZLaunch ]
[ "${GITHUB_REF:-}" = refs/heads/custom/main ]
[[ "${EXPECTED_COMMIT:-}" =~ ^[0-9a-f]{40}$ ]]
[ "$EXPECTED_COMMIT" = "${GITHUB_SHA:-}" ]
[ "$(git rev-parse HEAD)" = "$EXPECTED_COMMIT" ]
[ -z "$(git status --porcelain)" ]
: "${RUNNER_TEMP:?}"
VALIDATION_DIR="$RUNNER_TEMP/zlaunch-validation"
KEYCHAIN="$VALIDATION_DIR/signing.keychain-db"
[ -d "$VALIDATION_DIR" ] && [ -f "$KEYCHAIN" ]
DERIVED="$VALIDATION_DIR/DerivedData"
VERSION="$(node -p 'require("./Custom/release.json").version')"
xcodebuild -project Tinycast.xcodeproj -scheme Tinycast -configuration Release \
  -derivedDataPath "$DERIVED" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" CODE_SIGNING_ALLOWED=YES REGISTER_APP_IN_LAUNCH_SERVICES=NO build
APP="$DERIVED/Build/Products/Release/ZLaunch.app"
node Custom/verify-bundle.mjs "$APP" Release
./Scripts/verify-signature.sh "$APP"
for TARGET in "$APP" "$APP/Contents/Helpers/ClipboardTextHelper" "$APP/Contents/Helpers/ZLaunch Dictation.app"; do
  codesign -v -R '=anchor apple generic and certificate leaf[subject.OU] = "FVY9AS28CU" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' "$TARGET"
done
[ "$(git rev-parse HEAD)" = "$EXPECTED_COMMIT" ]
[ -z "$(git status --porcelain)" ]
ditto -c -k --keepParent --sequesterRsrc "$APP" "$VALIDATION_DIR/validation.zip"
xcrun notarytool submit "$VALIDATION_DIR/validation.zip" \
  --keychain-profile ZLaunch-Validation --keychain "$KEYCHAIN" \
  --wait --timeout 15m --output-format json > "$VALIDATION_DIR/notary-result.json"
node -e '
  const result = require(process.argv[1]);
  if (result.status !== "Accepted" || !/^[0-9a-f-]{36}$/i.test(result.id ?? ""))
    throw new Error("Apple did not return an accepted notarization submission.");
' "$VALIDATION_DIR/notary-result.json"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose "$APP"
git diff --exit-code
[ -z "$(git status --porcelain)" ]
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    printf 'Validated source: `%s`\n\n' "$EXPECTED_COMMIT"
    printf '%s\n' 'Developer ID signatures, Apple notarization, stapling and Gatekeeper passed.' \
      'No release, tag, uploaded artifact, installation or app launch was performed.'
  } >> "$GITHUB_STEP_SUMMARY"
fi
