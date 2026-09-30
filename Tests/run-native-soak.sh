#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture=$(mktemp -d /tmp/mocpot-native-soak.XXXXXX)
trap 'rm -rf "$fixture"' EXIT
ffmpeg -nostdin -v error -f lavfi -i 'testsrc2=size=1920x1080:rate=60' -f lavfi -i 'sine=frequency=440:sample_rate=48000' -t 35 -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac "$fixture/sample.mp4"
sources=()
for source in Mocpot/Sources/*.swift; do
    [[ "$source" == */PotPlayerMacApp.swift ]] || sources+=("$source")
done
xcrun swiftc -swift-version 5 -I Vendor/MPV/include "${sources[@]}" Tests/NativePlaybackSoak.swift -o "$fixture/checks"
"$fixture/checks" "$fixture/sample.mp4"
