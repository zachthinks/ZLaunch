#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
node Custom/verify-config.mjs
node Custom/tests/sync-test.mjs
node Custom/tests/workflow-policy-test.mjs
node Custom/tests/release-state-test.mjs
node Custom/tests/signing-validation-test.mjs
node Custom/tests/release-notes-test.mjs
node Custom/tests/github-release-api-test.mjs
node Custom/tests/hosted-release-test.mjs
node Custom/tests/publication-policy-test.mjs
node Custom/tests/delivery-test.mjs
node Custom/verify-project.mjs
git diff --exit-code -- Tinycast.xcodeproj
./Scripts/run-tests.sh
./Scripts/lint.sh
if rg -l 'import (AppKit|SwiftUI|Cocoa)' Tinycast/Features/*/Model/; then
  echo "Model layer imports UI frameworks" >&2; exit 1
fi
UNSIGNED=1 ./Custom/build.sh
node Custom/verify-bundle.mjs "${DERIVED:-$PWD/build/ZLaunchDerivedData}/Build/Products/Debug/ZLaunch Dev.app" Debug
