#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
binary=$(mktemp /tmp/mocpot-playlist-close.XXXXXX)
trap 'rm -f "$binary"' EXIT
sources=()
for source in Mocpot/Sources/*.swift; do
    [[ "$source" == */PotPlayerMacApp.swift ]] || sources+=("$source")
done
xcrun swiftc -swift-version 5 -I Vendor/MPV/include "${sources[@]}" Tests/PlaylistCloseRegression.swift -o "$binary"
"$binary"
