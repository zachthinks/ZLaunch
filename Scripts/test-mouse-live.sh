#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "${ZLAUNCH_LIVE_MOUSE_TEST:-}" != 1 ]; then
    echo "Run only in an isolated, unlocked QA desktop: ZLAUNCH_LIVE_MOUSE_TEST=1 $0" >&2
    exit 2
fi

OUT="${1:-$(mktemp -d "${TMPDIR:-/tmp}/zlaunch-mouse-live.XXXXXX")}"
mkdir -p "$OUT/Mouse QA.app/Contents/MacOS"
OUT="$(cd "$OUT" && pwd)"
xcrun swiftc -O -swift-version 6 \
    Tinycast/Features/WindowManagement/Model/MouseWindow*.swift \
    Tinycast/Features/WindowManagement/Service/MouseWindow*.swift \
    Tests/mouse-window-live-test.swift -o "$OUT/mouse-live"
cp "$OUT/mouse-live" "$OUT/Mouse QA.app/Contents/MacOS/MouseQA"
cat > "$OUT/Mouse QA.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.zachthinks.mouse-qa</string>
<key>CFBundleExecutable</key><string>MouseQA</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
"$OUT/Mouse QA.app/Contents/MacOS/MouseQA" --target > "$OUT/target.log" 2>&1 &
target_pid=$!
trap 'kill "$target_pid" 2>/dev/null || true; wait "$target_pid" 2>/dev/null || true' EXIT
sleep 1
echo "Live mouse validation evidence: $OUT"
/usr/bin/time -l "$OUT/mouse-live" > "$OUT/result.log" 2>&1
cat "$OUT/result.log"
