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
record_notarization_result() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    node - "$VALIDATION_DIR" <<'NODE' || echo "::warning::Could not record the notarization receipt."
const { appendFileSync, readFileSync } = require("node:fs");
const readResult = name => {
  try { return JSON.parse(readFileSync(process.argv[2] + "/" + name, "utf8")) ?? {}; }
  catch { return {}; }
};
const submitted = readResult("notary-submission.json");
const id = submitted.id;
if (typeof id === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
  const result = readResult("notary-result.json");
  const allowed = ["Accepted", "Invalid", "Rejected", "In Progress"];
  const status = result.id === id && allowed.includes(result.status) ? result.status : "Unavailable";
  appendFileSync(process.env.GITHUB_STEP_SUMMARY,
    "Apple submission ID: " + id + "\nApple status: " + status + "\n");
}
NODE
  fi
}
trap record_notarization_result EXIT
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
  --no-wait --output-format json > "$VALIDATION_DIR/notary-submission.json"
SUBMISSION_ID="$(node -e '
  const { readFileSync } = require("node:fs");
  let result;
  try { result = JSON.parse(readFileSync(process.argv[1], "utf8")); }
  catch { throw new Error("Apple submission response was not valid JSON."); }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(result.id ?? ""))
    throw new Error("Apple did not return a valid submission ID.");
  process.stdout.write(result.id);
' "$VALIDATION_DIR/notary-submission.json")"
xcrun notarytool wait "$SUBMISSION_ID" \
  --keychain-profile ZLaunch-Validation --keychain "$KEYCHAIN" \
  --timeout 15m --output-format json > "$VALIDATION_DIR/notary-result.json"
node -e '
  const { readFileSync } = require("node:fs");
  let result;
  try { result = JSON.parse(readFileSync(process.argv[1], "utf8")); }
  catch { throw new Error("Apple status response was not valid JSON."); }
  if (result.status !== "Accepted" || result.id !== process.argv[2])
    throw new Error("Apple did not return an accepted notarization submission.");
' "$VALIDATION_DIR/notary-result.json" "$SUBMISSION_ID"
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
