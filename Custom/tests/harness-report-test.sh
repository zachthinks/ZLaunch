#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir "$fixture/bin" "$fixture/tmp"
cat > "$fixture/bin/swiftc" <<'COMPILER'
#!/bin/bash
while [ "$1" != -o ]; do shift; done
shift
cat > "$1" <<'HARNESS'
#!/bin/bash
echo 'synthetic harness crash diagnostic' >&2
kill -TRAP $$
HARNESS
chmod +x "$1"
COMPILER
chmod +x "$fixture/bin/swiftc"
if PATH="$fixture/bin:$PATH" TMPDIR="$fixture/tmp" ./Scripts/run-tests.sh SecureItemsTests > "$fixture/output" 2>&1; then
    echo 'A crashed harness must fail the suite.' >&2
    exit 1
fi
if ! grep -q '1 of 1 harness(es) failed' "$fixture/output" \
    || ! grep -q 'synthetic harness crash diagnostic' "$fixture/output" \
    || grep -q 'harness dispatch failed' "$fixture/output"; then
    cat "$fixture/output" >&2
    exit 1
fi
echo 'Harness crash reporting preserves one result and its diagnostic.'
