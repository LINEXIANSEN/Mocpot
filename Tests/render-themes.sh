#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sources=()
for source in Mocpot/Sources/*.swift; do
    if [[ "$source" != */PotPlayerMacApp.swift ]]; then sources+=("$source"); fi
done
snapshot_binary=$(mktemp /tmp/mocpot-theme-snapshot.XXXXXX)
trap 'rm -f "$snapshot_binary"' EXIT
MACOSX_DEPLOYMENT_TARGET=13.0 xcrun swiftc -I Vendor/MPV/include -swift-version 5 "${sources[@]}" Tests/ThemeSnapshots.swift -o "$snapshot_binary"
"$snapshot_binary" "${1:-/tmp/mocpot-theme-snapshots}"
