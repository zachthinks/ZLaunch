#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED="${DERIVED:-$PWD/build/ZLaunchDerivedData}"
VERSION="$(node -p 'require("./Custom/release.json").version')"
ARGS=(CODE_SIGNING_ALLOWED=YES)
if [ "${UNSIGNED:-0}" = 1 ]; then ARGS=(CODE_SIGNING_ALLOWED=NO REGISTER_APP_IN_LAUNCH_SERVICES=NO); fi
xcodebuild -project Tinycast.xcodeproj -scheme Tinycast -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" "${ARGS[@]}" build
