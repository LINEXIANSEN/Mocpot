#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture_dir=$(mktemp -d /tmp/mocpot-regression.XXXXXX)
trap 'rm -rf "$fixture_dir"' EXIT
ffmpeg -hide_banner -loglevel error -f lavfi -i 'testsrc2=size=960x480:rate=30' -f lavfi -i 'sine=frequency=440:sample_rate=48000' -f lavfi -i 'sine=frequency=880:sample_rate=48000' -map 0:v -map 1:a -map 2:a -c:a aac -t 10 -c:v libx264 -preset ultrafast -pix_fmt yuv420p "$fixture_dir/sample.mp4"
cp "$fixture_dir/sample.mp4" "$fixture_dir/sample-360.mp4"
xcrun swiftc -swift-version 5 Mocpot/Sources/PlayerViewModel.swift Mocpot/Sources/MediaSettings.swift Mocpot/Sources/PictureInPictureController.swift Tests/PlaybackRegression.swift -o "$fixture_dir/PlaybackRegression"
"$fixture_dir/PlaybackRegression" "$fixture_dir"
