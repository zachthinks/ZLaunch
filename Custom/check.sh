#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
node Custom/verify-config.mjs
node Custom/tests/sync-test.mjs
node Custom/tests/workflow-policy-test.mjs
node Custom/verify-project.mjs
git diff --exit-code -- Tinycast.xcodeproj
./Scripts/run-tests.sh
./Scripts/lint.sh
if rg -l 'import (AppKit|SwiftUI|Cocoa)' Tinycast/Features/*/Model/; then
  echo "Model layer imports UI frameworks" >&2; exit 1
fi
UNSIGNED=1 ./Custom/build.sh
