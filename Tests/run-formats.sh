#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture=$(mktemp -d /tmp/mocpot-format-regression.XXXXXX)
helper_dir="${1:-$PWD/Vendor/FFmpeg/Helpers}"
ffmpeg -nostdin -v error -f lavfi -i testsrc2=size=320x180:rate=24 -f lavfi -i sine=frequency=440 -t 2 -c:v libx264 -preset ultrafast -c:a aac "$fixture/h264-aac.mp4"
cat > "$fixture/subtitle.srt" <<'EOF'
1
00:00:00,100 --> 00:00:01,900
内嵌字幕 · Test subtitle
EOF
ffmpeg -nostdin -v error -i "$fixture/h264-aac.mp4" -i "$fixture/subtitle.srt" -map 0:v -map 0:a -map 0:a -map 1:s -c copy "$fixture/h264-aac.mkv"
ffmpeg -nostdin -v error -i "$fixture/h264-aac.mp4" -c:v mpeg4 -c:a libmp3lame "$fixture/mpeg4-mp3.avi"
ffmpeg -nostdin -v error -i "$fixture/h264-aac.mp4" -c:v libvpx-vp9 -deadline realtime -c:a libopus "$fixture/vp9-opus.webm"
ffmpeg -nostdin -v error -i "$fixture/h264-aac.mp4" -c:v wmv2 -c:a wmav2 "$fixture/wmv-wma.wmv"
ffmpeg -nostdin -v error -i "$fixture/h264-aac.mp4" -c:v flv -c:a libmp3lame "$fixture/flv-mp3.flv"
ffmpeg -nostdin -v error -i "$fixture/h264-aac.mp4" -c:v copy -c:a ac3 "$fixture/h264-ac3.ts"
ffmpeg -nostdin -v error -i "$fixture/h264-aac.mp4" -c:v copy -c:a dca -strict -2 "$fixture/h264-dts.mkv"
ffmpeg -nostdin -v error -i "$fixture/h264-aac.mp4" -c:v hevc_videotoolbox -tag:v hvc1 -c:a copy "$fixture/hevc-aac.mp4"
xcrun swiftc -swift-version 5 Mocpot/Sources/FormatCompatibility.swift Mocpot/Sources/PlayerViewModel.swift Mocpot/Sources/MediaSettings.swift Mocpot/Sources/PictureInPictureController.swift Tests/FormatCompatibilityRegression.swift -o "$fixture/checks"
"$fixture/checks" "$fixture" "$helper_dir"
