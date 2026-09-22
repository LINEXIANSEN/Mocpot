#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture=${1:?Pass a folder of fixtures from Tests/run-formats.sh}
export MOCPOT_MPV_LIBRARY="${MOCPOT_MPV_LIBRARY:-$PWD/Vendor/MPV/DirectPlayback/libmpv.2.dylib}"
ffmpeg -v error -y -f lavfi -i 'color=red:size=320x180:rate=30,drawbox=x=160:y=0:w=160:h=90:color=0x00ff00:t=fill,drawbox=x=0:y=90:w=160:h=90:color=blue:t=fill,drawbox=x=160:y=90:w=160:h=90:color=white:t=fill' -t 2 -c:v libx264 -pix_fmt yuv420p "$fixture/orientation.mkv"
ffmpeg -v error -y -stream_loop 59 -i "$fixture/vp9-opus.webm" -c copy "$fixture/long.webm"
sources=()
for file in Mocpot/Sources/*.swift; do
    [[ "$file" == *PotPlayerMacApp.swift ]] || sources+=("$file")
done
xcrun swiftc -swift-version 5 -I Vendor/MPV/include "${sources[@]}" Tests/DirectPlaybackRegression.swift -o "$fixture/direct-checks"
"$fixture/direct-checks" "$fixture"
