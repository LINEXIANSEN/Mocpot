#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
binary=$(mktemp /tmp/mocpot-readonly-probe.XXXXXX)
trap 'rm -f "$binary"' EXIT
sources=()
for source in Mocpot/Sources/*.swift; do
    [[ "$source" == */PotPlayerMacApp.swift ]] || sources+=("$source")
done
xcrun swiftc -swift-version 5 -I Vendor/MPV/include "${sources[@]}" Tests/ReadOnlyPlaybackProbe.swift -o "$binary"
MOCPOT_MPV_LIBRARY="$PWD/Vendor/MPV/DirectPlayback/libmpv.2.dylib" "$binary" "${1:?Provide one local movie path}"
